"""
    build_data(; kwargs...)

# Keywords
- `save_build = true`:
    - `save_build = true` (default) or `save_build::String = "path/to/version"`: save_build data in each build
        step in the path returned by [`SLiDE.build_path`](@ref).
    - `save_build = false`: the files at each step will not be saved.
- `overwrite = false`: If data exists, do not read it. Build the data from scratch.

# Returns
- `d::Dict` of DataFrames containing the model data.
- `set::Dict` of Arrays describing region, sector, final demand, etc.
"""
function build_data(
    dataset::String = DEFAULT_DATASET;
    save_build::Bool = DEFAULT_SAVE_BUILD,
    overwrite::Bool = DEFAULT_OVERWRITE
    )

    d = read_build(dataset, PARAM_DIR; overwrite = overwrite)
    set = read_build(dataset, SET_DIR; overwrite = overwrite)

    if |(isempty(d), isempty(set), overwrite)
        if isempty(set)
            set = read_from(joinpath("src","readfiles","setlist.yml"))
            write_build(dataset, SET_DIR, set)
        end

        io = read_from(joinpath("src","readfiles","build","partitioninp.yml"))

        io = partition(dataset, io, set; save_build = save_build, overwrite = overwrite)
        cal = calibrate(dataset, io, set; save_build = save_build, overwrite = overwrite)
        
        (shr, set) = share(dataset, Dict(:va0 => cal[:va0]), set;
            save_build = save_build, overwrite = overwrite)

        (d, set) = disagg(dataset, merge(cal, shr), set;
            save_build = save_build, overwrite = overwrite)

        write_build!(dataset, PARAM_DIR, d)
        # write_build!(dataset, SET_DIR, set)
    end
    return (d, set)
end


"""
    build_path(subset::String; kwargs...)

# Arguments
- `subset::String`: Internally-passed parameter indicating the build step. For the four
    build steps, these are: partition, calibrate, share, and build.

# Keyword Arguments
- `save_build`: Will this data be saved? If so, where?
    - `save_build = true` (default): save data in each build step ([`SLiDE.partition!`](@ref),
        [`SLiDE.calibrate`](@ref), [`SLiDE.share!`](@ref), [`SLiDE.disagg!`](@ref))
        to a directory in `SLiDE/data/default/build/`.
    - `save_build = path/to/version`: Build data will be saved in `SLiDE/data/path/to/version/build/`.

# Returns
- `path::String`: standardized location indicating where to save intermediate files.
"""
function sub_path(dataset::String, subset::String)
    path = data_path(dataset)
    (subset in BUILD_STEPS) && (path = joinpath(path, "build"))
    return joinpath(path, subset)
end


function data_path(dataset::String)
    joinpath(SLIDE_DIR, "data", dataset)
end


"""
    read_from(path::String)
"""
function read_from(path::String; ext = ".csv", run_bash::Bool = false)
    # Should update to make read_from(::Type, path), so the output is not a mystery.
    d = if any(occursin.([".yml",".yaml"], path))
        _read_from_yaml(path; run_bash = run_bash)
    elseif isdir(path)
        _read_from_dir(path; ext = ext, run_bash = run_bash)
    else
        @error("Cannot read from $path. Please enter an existing directory or yaml file name.")
    end
    return d
end


"""
"""
function _read_from_dir(dir::String; ext = ".csv", run_bash::Bool = false)
    files = readdir(dir)

    # If the path contains both a .gdx file and a bash shell script, assume that the script
    # is there to execute "gdxdump" on the shell files.
    run_bash && _run_bash(dir, files)
    # (any(occursin.(".sh", files)) && any(occursin.(".gdx", files))) && _run_bash(dir, files)

    @info("Reading $ext files from $dir.")
    files = Dict(_inp_key(f, ext) => f for f in files if occursin(ext, f))
    d = Dict(k => read_file(joinpath(dir,f)) for (k,f) in files)

    # If the file is empty, If there's only one column containing values, rename it to value.
    # This is consistent with SLiDE naming convention.
    _delete_empty!(d)
    [d[k] = edit_with(df, Rename.(findvalue(df), :value)) for (k,df) in d
        if length(findvalue(df)) == 1]
    return d
end


"""
"""
function _delete_empty!(d::Dict)
    for k in keys(d)
        if isempty(d[k])
            @warn("Removing empty entry with key $k from the dictionary.")
            delete!(d, k)
        end
    end
end
_delete_empty!(d::Any) = nothing


"""
    _read_from_yaml(path::String)
"""
function _read_from_yaml(path::String; run_bash::Bool = false)
    y = read_file(path)

    # If the yaml file includes the key "Path", this indicates that the yaml file 
    if "Path" in keys(y)

        # Look for shell scripts in this path, and run them if they are there.
        # If none are found, nothing will happen.
        run_bash && _run_bash(joinpath(SLIDE_DIR, ensurearray(y["Path"])...))
        
        inp = "Input" in keys(y) ? y["Input"] : collect(values(find_oftype(y, File)))[1]
        d = _read_from_yaml(y["Path"], inp)
        
        # 
        _delete_empty!(d)
        [d[k] = edit_with(d[k], y) for k in keys(d) if typeof(d[k]) == DataFrame]
    else
        inp = ensurearray(collect(values(find_oftype(y, CGE)))[1])
        d = _read_from_yaml(inp)
    end
    return d
end

function _read_from_yaml(path::Array{String,1}, file::Dict)
    path = joinpath(SLIDE_DIR, path...)
    return Dict(_inp_key(k) => read_file(joinpath(path, f)) for (k,f) in file)
end

function _read_from_yaml(path::Array{String,1}, file::Array{T,1}) where {T <: File}
    path = joinpath(SLIDE_DIR, path...)
    return Dict(_inp_key(f) => read_file(path, f) for f in file)
end

_read_from_yaml(path::String, file::Any) = _read_from_yaml(ensurearray(path), file)
_read_from_yaml(lst::Array{Parameter,1}) = Dict(_inp_key(x) => x for x in lst)


"""
"""
_inp_key(x::SetInput) = length(split(x.descriptor)) > 1 ? Tuple(split(x.descriptor)) : x.descriptor
_inp_key(x::T) where {T <: File} = Symbol(x.descriptor)
_inp_key(x::Parameter) = Symbol(x.parameter)
_inp_key(x::String) = Symbol(x)
_inp_key(x::String, ext::String) = Symbol(splitpath(x)[end][1:end-length(ext)])


"""
    write_build(subset::String, d::Dict; kwargs...)
This function writes intermediary build files if desired by the user.
"""
function write_build!(dataset::String,
    subset::String,
    d::Dict;
    save_build::Bool = DEFAULT_SAVE_BUILD
    )
    
    [sort!(dropzero!(d[k])) for k in keys(d) if typeof(d[k]) == DataFrame]
    d_write = filter_build!(subset, d)
    
    if isempty(d_write)
        @warn("Skipping writing empty Dictionary")
    elseif (subset in BUILD_STEPS && save_build) || !(subset in BUILD_STEPS)
        path = sub_path(dataset, subset)
        
        !isdir(path) && mkpath(path)
        @info("Saving $subset in $path")
        
        for k in keys(d_write)
            println("  Writing $k")
            CSV.write(joinpath(path, "$k.csv"), d_write[k])
        end
    end
    return d
end

function write_build(
    dataset::String,
    subset::String,
    d::Dict;
    save_build::Bool = DEFAULT_SAVE_BUILD
    )
    write_build!(dataset, subset, copy(d); save_build = save_build)
end


"""
    read_build(subset::String; kwargs...)
This function reads intermediary build files if they have previously been saved by the user.

# Returns
- `d::Dict` of DataFrames
"""
function read_build(dataset::String, subset::String; overwrite::Bool = DEFAULT_OVERWRITE)

    path = sub_path(dataset, subset)

    if overwrite == true && isdir(path)
        @info("Deleting $path to overwrite data.")
        rm(path; recursive = true)
        return Dict()
    end

    if !isdir(path)
        @info("$path not found.")
        return Dict()
    else
        return read_from(path)
    end
end


function filter_build!(subset::String, d::Dict{T,DataFrame}) where T <: Any
    df = read_file(joinpath(SLIDE_DIR,"src","build","parameters","parameter_define.csv"))

    lst_param = read_from(joinpath(SLIDE_DIR,"src","readfiles","parameterlist.yml"))
    lst_param = (Symbol(subset) in keys(lst_param)) ? lst_param[Symbol(subset)] : DataFrame()

    type_param = read_file(joinpath(SLIDE_DIR,"src","build","parameters","parameter_scope.csv"))
    type_param = type_param[type_param[:,:subset] .== subset,:]

    df = indexjoin(lst_param, type_param, df)
    dropmissing!(df, intersect(propertynames(df),[:subset,:index]))
    
    if !isempty(df)
        param = load_from(Dict{Parameter}, df);

        save_keys = intersect(keys(d), keys(param))
        delete_keys = setdiff(keys(d), save_keys)

        [delete!(d, k) for k in delete_keys]
        [select!(d[k], param[k]) for k in save_keys]
    end
    return d
end


function filter_build!(subset::String, d::Dict)
    if subset == SET_DIR
        lst_index = Symbol.(read_file(joinpath(SLIDE_DIR,"src","build","parameters"),
            SetInput("list_index.csv", :index)))

        save_keys = intersect(keys(d), intersect(lst_index))
        delete_keys = setdiff(keys(d), save_keys)

        [delete!(d, k) for k in delete_keys]
        return Dict(k => DataFrame([d[k]], [k]) for k in save_keys)
    else
        return d
    end
end


"""
"""
function _run_bash(dir::String, files::Array{String,1})
    scripts = files[occursin.(".sh", files)]
    isempty(scripts) && return
    
    # Save the current directory so we can return to it later. Enter the directory
    # containing the bash file(s), run it/them, and return to the original directory.
    # We default to iterating over a loop of an array of files, even if that array contains
    # only one file, to minimize changing directories.
    curr_dir = pwd()
    cd(dir)
    for s in scripts
        @info("Running bash script $s in $dir.")
        run(`bash $s`)
    end
    cd(curr_dir)
end

function _run_bash(path::String)
    if isdir(path)
        _run_bash(path, readdir(path))
    elseif isfile(path) && (path[end-2:end] == ".sh")
        dir = joinpath(splitpath(path)[1:end-1]...)
        file = splitpath(path)[end]
        _run_bash(dir, file)
    # else
    #     @warn("$path is not a valid bash file nor is it a directory that contains one.")
    end
end

_run_bash(dir::String, file::String) = _run_bash(dir, ensurearray(file))