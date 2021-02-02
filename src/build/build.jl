"""
    build(; kwargs...)
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
function build(
    dataset::String=DEFAULT_DATASET;
    # version::String="1.0.1",
    save_build::Bool=DEFAULT_SAVE_BUILD,
    overwrite::Bool=DEFAULT_OVERWRITE,
    map_fdcat::Bool=false,
)

    d = read_build(dataset, PARAM_DIR; overwrite=overwrite)
    set = read_build(dataset, SET_DIR; overwrite=overwrite)

    if |(isempty(d), isempty(set), overwrite)
        if isempty(set)
            set = read_from(joinpath("src", "build", "readfiles", "setlist.yml"))
            _set_sector!(set, set[:summary])
            # [set[k] = set[:summary] for k in [:g,:s]]
            write_build(dataset, SET_DIR, set)
        end
        
        io = merge(read_from(joinpath("src", "build", "readfiles", "input", "summary.yml")),
            Dict(:sector => :summary))

        io = partition(dataset, io, set; save_build=save_build, overwrite=overwrite)
        
        cal = calibrate(dataset, io, set; save_build=save_build, overwrite=overwrite)
        
        (shr, set) = share(dataset, Dict(:va0 => cal[:va0]), set;
            save_build=save_build, overwrite=overwrite)

        (d, set) = disagg(dataset, merge(cal, shr), set;
            save_build=save_build, overwrite=overwrite)

        write_build!(dataset, PARAM_DIR, d)
        filter_build!(SET_DIR, set)
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
    save_build::Bool=DEFAULT_SAVE_BUILD
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
            
            if typeof(d_write[k]) == DataFrame
                CSV.write(joinpath(path, "$k.csv"), d_write[k])
            elseif typeof(d_write[k]) <: AbstractArray
                CSV.write(joinpath(path, "$k.csv"), DataFrame(k=d_write[k]))
            end
            # typeof(d_write[k]) == DataFrame && CSV.write(joinpath(path, "$k.csv"), d_write[k])
        end
    end
    return d
end


function write_build(
    dataset::String,
    subset::String,
    d::Dict;
    save_build::Bool=DEFAULT_SAVE_BUILD
)
    write_build!(dataset, subset, copy(d); save_build=save_build)
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
function read_build(dataset::String, subset::String; overwrite::Bool=DEFAULT_OVERWRITE)
    path = sub_path(dataset, subset)
    if overwrite == true && isdir(path)
        @info("Deleting $path to overwrite data.")
        rm(path; recursive=true)
        return Dict()
    end

    if !isdir(path)
        @info("$path not found.")
        return Dict()
    else
        d = read_from(path)
        subset == SET_DIR && (d = Dict{Any,Array{T,1} where T}(k => df[:,1] for (k, df) in d))
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
function filter_build!(subset::String, d::Dict)
    lst = build_parameters(subset)
    return _filter_with!(d, lst)
end


"""
"""
function _filter_with!(d::Dict, lst::Dict{Symbol,Parameter})
    keep = Dict(k => haskey(lst, k) for k in keys(d))
    [keep[k] ? select!(d[k], lst[k]) : delete!(d, k) for k in keys(d)]
    return d
end


function _filter_with!(d::Dict, lst::AbstractArray)
    [delete!(d, k) for k in keys(d) if !(k in lst)]
    return d
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
    subset = convert_type(Symbol, subset)
    lst = read_from(joinpath(SLIDE_DIR, "src", "build", "readfiles", "parameterlist.yml"))

    !haskey(lst, subset) && (return nothing)

    df = read_file(joinpath(SLIDE_DIR, "src", "build", "parameters", "define.csv"))
    df = innerjoin(DataFrame(parameter=lst[subset]), df, on=:parameter)

    d = if isempty(df); convert_type.(Symbol, lst[subset])
    else;               load_from(Dict{Parameter}, df)
    end
    
    return d
end