"""
    build_data(; kwargs...)

# Keywords
- `save = true`:
- `save = true` (default) or `save::String = "path/to/version"`: Save data in each build
step in the path returned by [`SLiDE.build_path`](@ref).
- `save = false`: the files at each step will not be saved.
- `overwrite = false`: If data exists, do not read it. Build the data from scratch.

# Returns
- `d::Dict` of DataFrames containing the model data.
- `set::Dict` of Arrays describing region, sector, final demand, etc.
"""
function build_data(; save = true, overwrite = false)
    # (!!!!) Add option to save final, but not intermediates.
    set = read_from(joinpath("src","readfiles","setlist.yml"))

    disagg = read_build("disagg"; save = save, overwrite = overwrite);
    !isempty(disagg) && (return (disagg, set))
    
    io = read_from(joinpath("src","readfiles","build","partitioninp.yml"))

    io = partition!(io, set; save = save, overwrite = overwrite)
    cal = calibrate(copy(io), set; save = save, overwrite = overwrite)

    shr = Dict(:va0 => cal[:va0])
    shr = share!(shr, set; save = save, overwrite = overwrite)

    disagg = merge(copy(shr),copy(cal),Dict(
        :r => fill_with((r = set[:r],), 1.0),
        (:yr,:r,:g) => fill_with((yr = set[:yr], r = set[:r], g = set[:g]), 1.0)))

    disagg = disagg!(disagg, set; save = save, overwrite = overwrite)
    return (disagg, set)
end


"""
    build_path(build_step::String; kwargs...)

# Arguments
- `build_step::String`: Internally-passed parameter indicating the build step. For the four
    build steps, these are: partition, calibrate, share, and build.

# Keyword Arguments
- `save`: Will this data be saved? If so, where?
    - `save = true` (default): Save data in each build step ([`SLiDE.partition!`](@ref),
        [`SLiDE.calibrate`](@ref), [`SLiDE.share!`](@ref), [`SLiDE.disagg!`](@ref))
        to a directory in `SLiDE/data/default/build/`.
    - `save = path/to/version`: Build data will be saved in `SLiDE/data/path/to/version/build/`.

# Returns
- `path::String`: standardized location indicating where to save intermediate files.
"""
function build_path(build_step::String; save = true)
    save == false && (return false)
    path = save == true ? "default" : save
    path = joinpath(SLIDE_DIR, "data", path, "build", build_step)
    return path
end


"""
    read_from(path::String)
"""
function read_from(path::String)
    # Will update to make read_from(::Type, path), so the output is not a mystery.
    y = read_file(path)
    if "Path" in keys(y)
        path = y["Path"]
        inp = "Input" in keys(y) ? y["Input"] : collect(values(find_oftype(y, File)))[1]

        d = _read_from(path, inp)
        [d[k] = edit_with(d[k], y) for k in keys(d) if typeof(d[k]) == DataFrame]
    else
        inp = ensurearray(collect(values(find_oftype(y, CGE)))[1])
        d = _read_from(inp)
    end
    return d
end

"""
"""
function _read_from(path::Array{String,1}, file::Dict)
    path = joinpath(SLIDE_DIR, path...)
    return Dict(_inp_key(k) => read_file(joinpath(path, f)) for (k,f) in file)
end

function _read_from(path::Array{String,1}, file::Array{T,1}) where {T <: File}
    path = joinpath(SLIDE_DIR, path...)
    return Dict(_inp_key(f) => read_file(path, f) for f in file)
end

_read_from(path::String, file::Any) = _read_from(ensurearray(path), file)
_read_from(lst::Array{Parameter,1}) = Dict(_inp_key(x) => x for x in lst)


"""

"""
_inp_key(x::SetInput) = length(split(x.descriptor)) > 1 ? Tuple(split(x.descriptor)) : x.descriptor
_inp_key(x::T) where {T <: File} = Symbol(x.descriptor)
_inp_key(x::Parameter) = Symbol(x.parameter)
_inp_key(x::String) = Symbol(x)


"""
    write_build(build_step::String, d::Dict; kwargs...)
This function writes intermediary build files if desired by the user.
"""
function write_build!(build_step::String, d::Dict; save = false)
    # For the defined build steps, only save parameters specified as necessary.
    param = read_from(joinpath(SLIDE_DIR,"src","readfiles","parameterlist.yml"))
    if Symbol(build_step) in keys(param)
        param_save = Symbol.(param[Symbol(build_step)])
        param_delete = setdiff(keys(d), param_save)
        [delete!(d, k) for k in param_delete]
        # d = Dict(k => d[k] for k in param_save)
    end

    if save !== false
        save_path = build_path(build_step; save = save)

        !isdir(save_path) && mkpath(save_path)
        @info("Saving $build_step in $save_path")
        
        for k in keys(d)
            println("  Saving $k")
            CSV.write(joinpath(save_path, "$k.csv"), sort!(dropzero!(d[k])))
        end
    end
end


"""
    read_build(build_step::String; kwargs...)
This function reads intermediary build files if they have previously been saved by the user.

# Returns
- `d::Dict` of DataFrames
"""
function read_build(build_step::String; save = true, overwrite::Bool = false)

    if overwrite == true || save == false
        overwrite == true && @info("Skipping read. Overwriting $build_step to rebuild data.")
        save == false     && @info("No data save path specified.")
        d = Dict()
    else
        save_path = build_path(build_step; save = save)
        if !isdir(save_path)
            @info("$save_path not found.")
            d = Dict()
        else
            @info("Reading $build_step data from $save_path")
            files = readdir(save_path)
            d = Dict(Symbol(file[1:end-4]) => read_file(joinpath(save_path,file)) for file in files)
        end
    end
    return d
end