function build(dataset::Dataset)
    if dataset.overwrite
        @warn("overwriting data not yet supported. Setting overwrite=false.
            Delete the directory data/$(dataset.name) to replace data.")
        set!(build; overwrite=false)
    end
    d, set = build_io(dataset)
    d, set = build_eem(dataset, d, set)
    set_sector!(set, set[:sector])
    return d, set
end


function build(name::String=SLiDE.DEFAULT_DATASET;
    overwrite=SLiDE.DEFAULT_OVERWRITE,
    save_build=SLiDE.DEFAULT_SAVE_BUILD,
)
    return build(Dataset(name; overwrite=overwrite, save_build=save_build))
end


"""
    build_io(dataset::Dataset)
This function will execute the SLiDE buildstream and generate the parameters necessary to
run the model. If the dataset has already been generated and saved, the function will read
and return those values.

Otherwise, it will read input data from the `/SLIDE_DIR/data/input/` directory and
execute the four steps of the SLiDE buildstream via the following functions:
1. [`SLiDE.partition_bea`](@ref)
2. [`SLiDE.calibrate_national`](@ref)
3. [`SLiDE.share_region`](@ref)
4. [`SLiDE.disaggregate_region`](@ref)

# Arguments
- `dataset::Dataset` identifier

# Returns
- `d::Dict` of model parameters
- `set::Dict` of Arrays describing parameter indices (years, regions, goods, sectors, etc.)
"""
function build_io(dataset::Dataset)
    set!(dataset; build="io", step=PARAM_DIR)
    overwrite(dataset)

    # !!!! PRINT DATASET INFO TO FILE IN DATA/NAME DIRECTORY
    d = SLiDE.read_build(dataset)
    set = SLiDE.read_set(dataset)
    
    if dataset.step=="input"
        d, set = partition_bea(dataset, d, set)
        d = calibrate_national(dataset, d, set)
        d, set = share_region(dataset, d, set)
        d, set = disaggregate_region(dataset, d, set)

        write_build!(set!(dataset; step=SLiDE.PARAM_DIR), d)
        write_build!(set!(dataset; step=SLiDE.SET_DIR), set)
    end

    return d, set
end


"""
"""
function build_eem(dataset::Dataset, d::Dict, set::Dict)
    if dataset.eem==true
        set!(dataset; build="eem", step=PARAM_DIR)

        merge!(d, SLiDE.read_build(dataset))
        merge!(set, SLiDE.read_set(dataset))
        
        if dataset.step=="input"
            d, set = scale_sector!(dataset, d, set)
            d, set, maps = partition_seds(dataset, d, set)
            d, set, maps = disaggregate_energy!(dataset, d, set, maps)
            d = calibrate_regional(dataset, d, set)

            write_build!(set!(dataset; step=SLiDE.PARAM_DIR), d)
            write_build!(set!(dataset; step=SLiDE.SET_DIR), set)
        end
    end

    return d, set
end


"""
    overwrite(dataset::Dataset)
This function executes `dataset.overwrite=true`: if an output directory exists at
`dataset.name/dataset.build`, delete this directory. If `dataset.overwrite=false`, but
`dataset.save_build=true` AND not all build stream steps have been saved, print a warning.
"""
function overwrite(dataset::Dataset)
    path = datapath(dataset; directory_level=:build)
    
    if isdir(path)
        # If overwrite=TRUE, delete the entire name/build directory.
        if dataset.overwrite
            @info("overwrite=true: Deleting $path.")
            rm(path)
        # If overwrite=FALSE, but save_build=TRUE, check if all build steps have been saved.
        # If not, print a warning.
        elseif dataset.save_build
            num_development = sum(getindex.(readdir(path),1).=='_')
            if isfile(joinpath(path, )) &&
                    dataset.build=="io" && num_development < 3
                @warn("Build stream steps missing for $(dataset.name)/$(dataset.build). Set overwrite=true to execute save_build=true.")
            end
        end
    end
    return nothing
end


"""
    datapath(dataset::Dataset)
This function returns the path to the directory location specified by
`dataset.name/dataset.build/dataset.step`. Building a dataset called `dataset.name` with
`dataset.save_build=true` will produce files in the following structure.
    /SLIDE_DATA/data/dataset.name/
    ├── eem/
    |   ├── parameters/
    |   └── sets/
    ├── io/
    |   ├── parameters/
    └───└── sets/

# Arguments
- `dataset::String`: Dataset identifier

# Returns
- `dir::String = /path/to/dataset`
    - `SLIDE_DIR` is the path to the location of the SLiDE.jl package on the user's machine.
    - The default dataset identifier is `state_model`. This dataset includes all
        U.S. states and summary-level sectors and goods.
"""
function datapath(dataset::Dataset; directory_level=:step)
    if directory_level==:name
        path = joinpath(SLiDE.DATA_DIR, dataset.name)

    elseif directory_level==:build
        path = joinpath(SLiDE.DATA_DIR, dataset.name, dataset.build)

    elseif directory_level==:step
        path = joinpath(SLiDE.DATA_DIR, dataset.name, dataset.build)
        path = if dataset.step in [SLiDE.PARAM_DIR, SLiDE.SET_DIR]
            joinpath(path, dataset.step)
        else
            joinpath(path, SLiDE._development(dataset.step))
        end
    else
        error("directory_level must be :name, :build, :step")
    end
    return path
end


"""
    write_build!(dataset::Dataset, d::Dict)
This function filters the contents of the input dictionary `d` to include only relevant
files using [`SLiDE.filter_build!`](@ref) and writes set lists and parameter DataFrames to
csv files in the directory named by [`SLiDE.datapath`](@ref) and named for their associated
dictionary key.

# Arguments
- `dataset::Dataset` identifier
- `d::Dict` of information to write

# Returns
- `d::Dict`: filtered dictionary
"""
function write_build!(dataset::Dataset, d::Dict)
    d_write = SLiDE.filter_build!(dataset, d)

    if !isempty(d_write)
        if (dataset.step in SLiDE.BUILD_STEPS && dataset.save_build) ||
                !(dataset.step in SLiDE.BUILD_STEPS)
            path = datapath(dataset)
            !isdir(path) && mkpath(path)

            [write_build(path, k, v) for (k,v) in d_write]
        end
    end
    return d
end


"""
    write_build(path::String, k::Symbol, df::DataFrame)
    write_build(path::String, k::Symbol, lst::AbstractArray)
This is a helper function for [`SLiDE.write_build!`](@ref).

# Arguments
- `path::String = /path/to/dataset`
- `k`: filename
- `df::DataFrame` or `lst::AbstractArray` of data to write
"""
function write_build(path, k, df::DataFrame)
    println("  Writing $k")
    CSV.write(joinpath(path,"$k.csv"), df)
    return nothing
end

function write_build(path, k, lst::AbstractArray)
    println("  Writing $k")
    CSV.write(joinpath(path,"$k.csv"), DataFrame(k=>lst))
    return nothing
end

write_build(path, k, v) = nothing


"""
    read_set()
"""
function read_set(build::String; sector_level::Symbol=:summary)
    # If specifying io or eem, use default setlist yaml.
    if build in ["eem","io"]
        path = joinpath(READ_DIR,"setlist_$build.yml")
        @info("Reading sets from $path.")
        set = read_from(path)

        # Define sectors from 
        if build=="io" && !haskey(set, :sector)
            if haskey(set, sector_level)
                SLiDE.set_sector!(set, set[sector_level])
            # else
            #     !!!! ERROR, SECTOR LEVEL NOT FOUND
            end
        end
    
    # If pointing to a path,
    elseif isfile(build)
        path = build
        
        if getindex(splitext(path),2) .== ".csv"
            set = read_file(path)[:,1]
        else
            set = read_from(path)
            [set[k] = df[:,1] for (k,df) in set if typeof(df)<:DataFrame]
        end
    # else
    #     !!!! ERROR, MUST BE IO, EEM, OR POINT TO PATH
    end
    return set
end


function read_set(dataset::Dataset)
    path = SLiDE.datapath(SLiDE.set!(copy(dataset); step=SLiDE.SET_DIR))
    set = if isdir(path)
        Dict{Any,Any}(k => df[:,1] for (k,df) in read_from(path))
    else
        SLiDE.read_set(dataset.build; sector_level=dataset.sector_level)
    end
    return set
end


"""
    read_build(dataset::Dataset)
This function reads data from or for the specified `dataset` if this information has
previously been generated and saved, read the saved data. If this information has NOT yet
been generated, read *input* data using [`SLiDE.read_input!`](@ref).

# Arguments
- `dataset::Dataset` identifier
- `subset::String`: Internally-passed parameter indicating the type of information to save
    (set, parameter, or build step)

# Returns
- `d::Dict{Symbol,DataFrame}` if reading parameters or `d::Dict{Any,Array}` if reading sets
"""
function read_build(dataset::Dataset)
    path = datapath(dataset)
    d = Dict()
    if isdir(path)
        merge!(d, read_from(path))
    else
        merge!(d, read_input!(dataset))
    end
    return d
end


"""
    read_map()

# Returns
- `d::Dict` of EEM mapping datasets.
"""
function read_map()
    path = joinpath(SLIDE_DIR,"src","build","readfiles")
    return read_from(joinpath(path, "maplist.yml"))
end


"""
    read_input!(dataset::Dataset)
Read input data for the specified `dataset.build/dataset.step` and set
`dataset.step = "input"` to indicate further action is required.

# Arguments
- `dataset::Dataset` identifier

# Returns
- `d::Dict` of input data.
"""
function read_input!(dataset::Dataset)
    d = Dict()
    
    if dataset.build=="io"
        path = joinpath(SLIDE_DIR,"src","build","readfiles","input")
        dataset.step==SLiDE.PARAM_DIR && set!(dataset; step="partition")
        dataset.step=="partition" && (path = joinpath(path, "$(dataset.sector_level).yml"))
        dataset.step=="share" && (path = joinpath(path, "share.yml"))

        if isfile(path)
            merge!(d, read_from(path))
            [d[k] = edit_with(df, Deselect([:units],"==")) for (k,df) in d]

            dataset.step=="partition" && push!(d, :sector=>dataset.sector_level)
            dataset.step = "input"
        end
    elseif dataset.build=="eem"
        if dataset.step=="partition"
            d = read_from(joinpath(SLIDE_DIR,"data","input","eia"))
        end
    end
    dataset.step = "input"
    return d
end


"""
    filter_build!(dataset::String, d::Dict)
This function filters `d` to contain only keys relevant to the specified `dataset`.
This avoids cluttering a saved directory with superfluous parameters that may have been
calculated at intermediate steps.

If filtering DataFrames, this reorders the DataFrame indices. This is important when
importing parameters into JuMP models when calibrating or modeling.

# Arguments
- `dataset::Dataset` identifier
- `d::Dict` of data to write

# Returns
- `d::Dict` of filtered data
"""
function filter_build!(dataset::Dataset, d::Dict)
    lst = SLiDE.describe(dataset)
    return SLiDE._filter_with!(d, lst)
end


"""
    _filter_with!(d::Dict, lst::Dict)
    _filter_with!(d::Dict, lst::AbstractArray)
This is a helper function for [`SLiDE.filter_build!`](@ref).

# Arguments
- `d::Dict` of data to filter
- `lst::Dict` of parameters or `lst::AbstractArray` of sets to include.

# Returns
- `d::Dict` of filtered data
"""
function _filter_with!(d::Dict, lst::Dict)
    keep = Dict(k => haskey(lst, k) for k in keys(d))
    [keep[k] ? select!(d[k], lst[k]) : delete!(d, k) for k in keys(d)]
    [sort!(dropzero!(d[k])) for k in keys(d)]
    return d
end

function _filter_with!(d::Dict, lst::AbstractArray)
    [delete!(d, k) for k in keys(d) if !(k in lst)]
    return d
end


"""
    describe!(set::Dict, dataset::Dataset)
    describe(dataset::Dataset)

# Arguments
- `dataset::Dataset` or `step::String/Symbol` specifying the parameters to describe

# Returns
- `d::Dict{Symbol,`[`Parameter`](@ref)`}` of Parameters relevant to the specified data
    step. The dictionary key is consistent the value's field `parameter`.
"""
function describe(dataset::Dataset)
    lst = SLiDE.list(dataset)
    df = read_file(joinpath(SLiDE.READ_DIR,"parameters","define.csv"))
    df = innerjoin(DataFrame(parameter=string.(lst)), df, on=:parameter)
    return isempty(df) ? lst : load_from(Dict{Parameter}, df)
end

function describe!(set::Dict, dataset::Dataset)
    key = Symbol.((dataset.build, dataset.step, :describe))
    !haskey(set, key) && push!(set, key=>describe(dataset))
    return set[key]
end


"""
    list!(set::Dict, dataset::Dataset)
This function adds a list of the parameters described by [`SLiDE.describe`](@ref)
to `set`, identified by the key `:step_list`.

# Arguments
- `set::Dict` to update
- `dataset::Dataset` or `step::Symbol`

# Returns
- `lst::AbstractArray` of parameters added to `set`
"""
function list(dataset::Dataset)
    if dataset.step=="taxes"
        return list("taxes")
    else
        step = Symbol(dataset.step)
        tmp = read_from(joinpath(SLiDE.READ_DIR, "parameterlist_$(dataset.build).yml"))
        return haskey(tmp, step) ? Symbol.(tmp[step][:,1]) : []
    end
end

list(x::String) = x=="taxes" ? [:ta0,:tm0,:ty0] : []


function list!(set::Dict, dataset::Dataset)
    key = Symbol.((dataset.build, dataset.step, :list))
    !haskey(set, key) && push!(set, key=>list(dataset))
    return set[key]
end


"""
"""
function set_sector!(set::Dict, x::AbstractArray)
    [set[k] = string.(x) for k in [:s,:g,:sector]]
    return set
end

set_sector!(set, x::Weighting) = set_sector!(set, convert_type(Mapping,x))
set_sector!(set, x::Mapping) = _set_sector!(set, x, x.to)

function _set_sector!(set, x::Mapping, to::Symbol)
    return set_sector!(set, unique(SLiDE.map_identity(x, set[:sector])[:,to]))
end

function _set_sector!(set, x::Mapping, to::AbstractArray)
    return set_sector!(set, unique(x.data[:, first(to)]))
end