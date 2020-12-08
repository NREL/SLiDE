"""
    build_data(; kwargs...)
This function will execute the SLiDE buildstream and generate the parameters necessary to
run the model. If the dataset has already been generated and saved, the function will read
and return those values.

Otherwise, it will read BEA supply/use data from the `/SLIDE_DIR/data/input/` directory.

Then, execute the four steps of the SLiDE buildstream by executing the following functions:
1. [`SLiDE.partition`](@ref)
2. [`SLiDE.calibrate`](@ref)
3. [`SLiDE.share`](@ref)
4. [`SLiDE.disagg`](@ref)

This information will be saved in the following structure:

    /SLIDE_DATA/data/dataset/
    ├── parameters/
    └── sets/

# Arguments
- `dataset::String`: Dataset identifier

# Keywords
- `save_build::Bool = false`: That decides whether to save the information at each build
    step. Setting `save_build = true` will add the directory `/SLIDE_DATA/data/dataset/build`
    to contain a subdirectory for each of the four build steps.
- `overwrite::Bool = false`: If data exists, do not read it. Build the data from scratch.

# Returns
- `d::Dict{Symbol,DataFrame}` of model parameters
- `set::Dict{Any,Array}` of Arrays describing parameter indices (years, regions, goods, sectors, etc.)
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
    sub_path(dataset::String, subset::String; kwargs...)

# Arguments
- `dataset::String`: Dataset identifier
- `subset::String`: Internally-passed parameter indicating the type of information to save
    (set, parameter, or build step)

# Returns
- `path::String`: Standardized location indicating where to save intermediate files.
    Here, `/path/to/dataset` is returned by [`SLiDE.data_path`](@ref)
    - If saving build steps: `/path/to/dataset/build/<build_step>`. For the For the four build
        steps, these are: partition, calibrate, share, and build.
    - Model input parameters: `/path/to/dataset/parameters`
    - Parameter indices: `/path/to/dataset/sets`
"""
function sub_path(dataset::String, subset::String)
    path = data_path(dataset)
    (subset in BUILD_STEPS) && (path = joinpath(path, "build"))
    return joinpath(path, subset)
end


"""
    data_path(dataset::String)

# Arguments
- `dataset::String`: Dataset identifier

# Returns
- `dir::String = /path/to/dataset`
    - `SLIDE_DIR` is the path to the location of the SLiDE.jl package on the user's machine.
    - The default dataset identifier is `state_model`. This dataset includes all
        U.S. states and summary-level sectors and goods.
"""
function data_path(dataset::String)
    joinpath(SLIDE_DIR, "data", dataset)
end


"""
    read_from(path::String)
This function reads information as specified by the path argument.

# Arguments
- `path::String` to a directory containing files to read *or* to a yaml file with
    information on what to read and how.

# Returns
- `d::Dict` of file contents.
"""
function read_from(path::String; ext = ".csv", run_bash::Bool = false)
    d = if any(occursin.([".yml",".yaml"], path))
        _read_from_yaml(path; run_bash = run_bash)
    elseif isdir(path)
        _read_from_dir(path; ext = ext, run_bash = run_bash)
    else
        @error("Cannot read from $path. Function input must point to an existing directory or yaml file.")
    end
    return d
end


"""
    _read_from_dir(dir::String; kwargs...)
This function reads all of the files from the input directory and returns the contents of
those of the specified extension.

# Arguments
- `dir::String`: Relative path to directory to read

# Keywords
- `ext::String = ".csv"`: File extension to read and return
- `run_bash::Bool = false`: If there's a shell script in `dir`, run it to generate/update
    directory contents before reading the files.

# Returns
- `d::Dict{Symbol,Any}` of file contents where the key references the source file name.
"""
function _read_from_dir(dir::String; ext::String = ".csv", run_bash::Bool = false)
    files = readdir(dir)

    # If the path contains both a .gdx file and a bash shell script, assume that the script
    # is there to execute "gdxdump" on the shell files.
    run_bash && (files = _run_bash(dir, files))

    @info("Reading $ext files from $dir.")
    files = Dict(_inp_key(f, ext) => f for f in files if occursin(ext, f))
    d = Dict(k => read_file(joinpath(dir,f)) for (k,f) in files)

    # If the file is empty, If there's only one column containing values, rename it to value.
    # This is consistent with SLiDE naming convention.
    _delete_empty!(d)
    return d
end


"""
    _delete_empty!(d::Dict)
This function removes dictionary entries with empty values.
"""
function _delete_empty!(d::Dict)
    for k in keys(d)
        if isempty(d[k])
            @warn("Removing empty entry with key $k from the dictionary.")
            delete!(d, k)
        end
    end
    return d
end

_delete_empty!(d::Any) = d


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
        
        files = ensurearray(values(find_oftype(y, File)))
        inp = "Input" in keys(y) ? y["Input"] : files
        d = _read_from_yaml(y["Path"], inp)
        d = _edit_from_yaml(d, y, inp)
    else
        inp = ensurearray(values(find_oftype(y, CGE)))
        d = _read_from_yaml(inp)
    end
    return d
end

function _read_from_yaml(path::String, files::Dict)
    path = joinpath(SLIDE_DIR, path)
    d = Dict(_inp_key(k) => read_file(joinpath(path, f)) for (k,f) in files)
    return _delete_empty!(d)
end

function _read_from_yaml(path::String, files::Array{T,1}) where {T <: File}
    path = joinpath(SLIDE_DIR, path)
    d = Dict(_inp_key(f) => read_file(path, f) for f in files)
    return _delete_empty!(d)
end

_read_from_yaml(path::Array{String,1}, file::Any) = _read_from_yaml(joinpath(path...), file)
_read_from_yaml(lst::Array{Parameter,1}) = _delete_empty!(Dict(_inp_key(x) => x for x in lst))


"""
    _inp_key(x::Any)
This function is a standardized method for generating dictionary keys for
[`SLiDE.read_from`](@ref) based on the type of information that is being read.
"""
function _inp_key(paths::Array{String,1})
    dir = splitdir.(paths)

    while length(unique(getindex.(dir,2))) > 1
        dir = splitdir.(getindex.(dir,1))
    end

    return convert_type(Symbol, dir[1][end])
end

_inp_key(x::SetInput) = length(split(x.descriptor)) > 1 ? Tuple(split(x.descriptor)) : x.descriptor
_inp_key(x::T) where {T <: File} = Symbol(x.descriptor)
_inp_key(x::Parameter) = Symbol(x.parameter)
_inp_key(x::String) = Symbol(x)
_inp_key(x::String, ext::String) = Symbol(splitpath(x)[end][1:end-length(ext)])



"""
"""
_edit_from_yaml(d::Dict, editor::Dict, files::Array) = d
_edit_from_yaml(d::Dict{Symbol,DataFrame}, editor::Dict, files::Dict) = d

function _edit_from_yaml(d::Dict{Symbol,DataFrame}, editor::Dict, files::Array{T,1}) where {T <: File}
    # [d[k] = edit_with(d[k], editor) for k in keys(d)]
    [d[_inp_key(f)] = edit_with(d[_inp_key(f)], editor, f) for f in files]
    return d
end

function _edit_from_yaml(d::Dict{Symbol,DataFrame}, editor::Dict, files::Array{DataInput,1})
    [d[_inp_key(f)] = select(edit_with(d[_inp_key(f)], editor, f), f.col) for f in files]
    return d
end


"""
    write_build(dataset::String, subset::String, d::Dict; kwargs...)
This function filters the contents of the input dictionary `d` to include only relevant
files using [`SLiDE.filter_build!`](@ref) and writes set lists and parameter DataFrames to
csv files in the directory named by [`SLiDE.sub_path`](@ref) and named for their associated
dictionary key.

# Arguments
- `dataset::String`: Dataset identifier
- `subset::String`: Internally-passed parameter indicating the type of information to save
    (set, parameter, or build step)
- `d::Dict` of information to write

# Returns
- `d::Dict`: filtered dictionary
"""
function write_build!(
    dataset::String,
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
    read_build(dataset::String, subset::String; kwargs...)
This function reads data from the specified `subset` if this information has previously been
generated and saved.

# Arguments
- `dataset::String`: Dataset identifier
- `subset::String`: Internally-passed parameter indicating the type of information to save
    (set, parameter, or build step)

# Keywords
- `overwrite::Bool = true`: If the user would like to re-generate the `subset` of data in 
    specified `dataset`, delete the directory. The information must now be re-calculated
    to repopulate the subset directory.

# Returns
- `d::Dict{Symbol,DataFrame}` if reading parameters or `d::Dict{Any,Array}` if reading sets
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
        d = read_from(path)
        subset == SET_DIR && (d = Dict{Any,Array{T,1} where T}(k => df[:,1] for (k,df) in d))
        return d
    end
end


"""
    filter_build!(subset::String, d::Dict; kwargs...)
This function filters `d` to contain only keys relevant to the specified `subset`.
This avoids cluttering a saved directory with superfluous parameters that may have been
calculated at intermediate steps.

If filtering DataFrames, this reorders the DataFrame indices. This is important when
importing parameters into JuMP models when calibrating or modeling.

# Arguments
- `subset::String`: Internally-passed parameter indicating the type of information to save
    (set, parameter, or build step)
- `d::Dict` of DataFrames containing data for the specified data subset

# Returns
- `d::Dict` filtered to include only relevant parameters.
"""
function filter_build!(subset::String, d::Dict{T,DataFrame}) where T <: Any
    param = build_parameters(subset)
    
    if param !== nothing
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
    build_parameters(subset::String)

# Arguments
- `subset::String`: Internally-passed parameter indicating the type of information to save
    (set, parameter, or build step)

# Returns
- `d::Dict{Symbol,`[`SLiDE.Parameter`](@ref)`}` of Parameters relevant to the specified data
    subset. The dictionary key is consistent the value's field `parameter`.
"""
function build_parameters(subset::String)

    df = read_file(joinpath(SLIDE_DIR,"src","build","parameters","parameter_define.csv"))

    lst_param = read_from(joinpath(SLIDE_DIR,"src","readfiles","parameterlist.yml"))
    lst_param = (Symbol(subset) in keys(lst_param)) ? lst_param[Symbol(subset)] : DataFrame()

    type_param = read_file(joinpath(SLIDE_DIR,"src","build","parameters","parameter_scope.csv"))
    type_param = type_param[type_param[:,:subset] .== subset,:]

    df = indexjoin(lst_param, type_param, df)
    dropmissing!(df, intersect(propertynames(df),[:subset,:index]))
    
    return !isempty(df) ? load_from(Dict{Parameter}, df) : nothing
end


"""
    _run_bash(dir::String, files)
    _run_bash(path::String)
This function runs a shell script if one is found.

# Arguments
- `path::String`: Relative path to a specific shell script to run or to a directory that
    might contain a shell script.
- `file::String` or `files::Array{String,1}`: A list of files in the specified directory.

# Returns
- `files::Array{String,1}`: An updated list of files in the specified directory after
    running the shell script if a list of files is given as an argument.
"""
function _run_bash(path::String, files::Array{String,1})
    scripts = files[occursin.(".sh", files)]
    isempty(scripts) && return
    
    # Save the current directory so we can return to it later. Enter the directory
    # containing the bash file(s), run it/them, and return to the original directory.
    # We default to iterating over a loop of an array of files, even if that array contains
    # only one file, to minimize changing directories.
    curr_dir = pwd()
    cd(path)
    for s in scripts
        @info("Running bash script $s in $path.")
        run(`bash $s`)
    end
    cd(curr_dir)
    files = readdir(path)
    return readdir(path)
end

function _run_bash(path::String)
    if isdir(path)
        _run_bash(path, readdir(path))
    elseif isfile(path) && (path[end-2:end] == ".sh")
        dir = joinpath(splitpath(path)[1:end-1]...)
        file = splitpath(path)[end]
        _run_bash(dir, file)
    end
end

_run_bash(path::String, file::String) = _run_bash(path, ensurearray(file))