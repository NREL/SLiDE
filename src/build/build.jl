"""
    build(dataset::Dataset)
This function executes the SLiDE buildstream and generates the parameters necessary to run
the model. If the dataset has already been generated and saved, the function will
read and return those values. Otherwise, it will generate these parameters by executing:
1. [`SLiDE.build_io`](@ref)
1. [`SLiDE.build_eem`](@ref) -- if `dataset.eem=true`
"""
function build(dataset::Dataset)
    dataset.overwrite && overwrite(dataset)
    d, set = build_io(dataset)
    d, set = build_eem(dataset, d, set)
    return d, set
end


function build(name::String=DEFAULT_DATASET;
    overwrite=DEFAULT_OVERWRITE,
    save_build=DEFAULT_SAVE_BUILD,
)
    return build(Dataset(name; overwrite=overwrite, save_build=save_build))
end


"""
    build_io(dataset::Dataset)
If the dataset has already been generated and saved, the function will read
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
    
    d = read_build(dataset)
    set = read_set(dataset)
    
    if dataset.step=="input"
        d, set = partition_bea(dataset, d, set)
        d = calibrate_national(dataset, d, set)
        d, set = share_region(dataset, d, set)
        d, set = disaggregate_region(dataset, d, set)

        d = write_build!(set!(dataset; step=PARAM_DIR), d)
        write_build!(set!(dataset; step=SET_DIR), set)
    end

    return Dict{Any,Any}(d), Dict{Any,Any}(set)
end


"""
    build_eem(dataset::Dataset)
**If `dataset.eem=true`**, continue the SLiDE buildstream for the Energy-Environment Module.
If the dataset has already been generated and saved, the function will read and return
those values.

Otherwise, it will execute the build routine via the following functions:
1. [`SLiDE.scale_sector`](@ref)
2. [`SLiDE.partition_seds`](@ref)
3. [`SLiDE.disaggregate_energy!`](@ref)
4. [`SLiDE.partition_co2!`](@ref)
5. [`SLiDE.calibrate_regional`](@ref)

# Arguments
- `dataset::Dataset` identifier

# Returns
- `d::Dict` of model parameters
- `set::Dict` of Arrays describing parameter indices (years, regions, goods, sectors, etc.)
"""
function build_eem(dataset::Dataset, d::Dict, set::Dict)
    if dataset.eem==true
        set!(dataset; build="eem", step=PARAM_DIR)

        merge!(d, read_build(dataset))
        merge!(set, read_set(dataset))
        
        if dataset.step=="input"
            d, set = scale_sector!(dataset, d, set)
            d, set, maps = partition_seds(dataset, d, set)
            d, set, maps = disaggregate_energy!(dataset, d, set, maps)
            d = partition_co2!(dataset, d, set, maps)
            d = calibrate_regional(dataset, d, set)
            
            d = write_build!(set!(dataset; step=PARAM_DIR), d)
            write_build!(set!(dataset; step=SET_DIR), set)
        end
    end

    return Dict{Any,Any}(d), Dict{Any,Any}(set)
end


"""
    overwrite(dataset::Dataset)
This function executes `dataset.overwrite=true`.
If a directory exists at `dataset.name/dataset.build`, and
- Output data HAS been generated, append the date this directory was created and move it.
- Output data HAS NOT yet been generated, remove the directory and start over.
"""
function overwrite(dataset::Dataset)
    path = datapath(dataset; directory_level=:name)

    if isdir(path) && dataset.overwrite
        # Do we have the OUTPUT we want? If not, let's start over (this is most useful
        # during development). If we do already have output, append the date the
        # directory was first created and rename.
        path_out = datapath(dataset.eem ? set!(copy(dataset); build="eem") : dataset)

        if isdir(path_out)
            path_new = append(path, Dates.unix2datetime(ctime(path)))
            println("overwrite=true. Renaming:\n    $path\n -> $path_new")
            mv(path, path_new)
        else
            println("overwrite=true. Since output was not yet generated, removing:\n  $path")
            rm(path; recursive=true)
        end
    end

    # !!!! If save_buil=true, look for missing build steps and print a warning.
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
        path = joinpath(DATA_DIR, dataset.name)

    elseif directory_level==:build
        path = joinpath(DATA_DIR, dataset.name, dataset.build)

    elseif directory_level==:step
        path = joinpath(DATA_DIR, dataset.name, dataset.build)
        path = if dataset.step in [PARAM_DIR, SET_DIR]
            joinpath(path, dataset.step)
        else
            joinpath(path, _development(dataset.step))
        end
    else
        error("directory_level must be :name, :build, :step")
    end
    return path
end


"""
    write_build!(dataset::Dataset, d::Dict)
This function filters the contents of the input dictionary `d` to include only relevant
files using [`SLiDE.filter_with!`](@ref) and writes set lists and parameter DataFrames to
csv files in the directory named by [`SLiDE.datapath`](@ref) and named for their associated
dictionary key.

# Arguments
- `dataset::Dataset` identifier
- `d::Dict` of information to write

# Returns
- `d::Dict`: filtered dictionary
"""
function write_build!(dataset::Dataset, d::Dict)
    d_write = filter_with!(d, dataset)

    if !isempty(d_write)
        if dataset.step in [PARAM_DIR,SET_DIR] || dataset.save_build
            path = datapath(dataset)
            !isdir(path) && mkpath(path)
            
            println("Writing to $path")
            [write_build(path, k, v) for (k,v) in d_write]
        end
    end

    # sets s, g would have been filtered out when writing, but we want to make sure they are
    # defined for subsequent steps.
    if dataset.step==SET_DIR
        set_sector!(d, d[:sector])
        set_sector!(d_write, d[:sector])
    end

    return d_write
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
    print_status(k, df)
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

        # Define sectors.
        if build=="io" && !haskey(set, :sector)
            if haskey(set, sector_level)
                set_sector!(set, set[sector_level])
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
    path = datapath(set!(copy(dataset); step=SET_DIR))
    set = if isdir(path)
        Dict{Any,Any}(k => df[:,1] for (k,df) in read_from(path))
    else
        read_set(dataset.build; sector_level=dataset.sector_level)
    end
    dataset.build=="io" && set_sector!(set, set[:sector])
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
`dataset.step="input"` to indicate further action is required.

# Arguments
- `dataset::Dataset` identifier

# Returns
- `d::Dict` of input data. If `dataset.step` does not require input data, return Dict().
"""
function read_input!(dataset::Dataset)
    d = Dict()
    
    if dataset.build=="io"
        dataset.step==PARAM_DIR && set!(dataset; step="bea")
        
        file = dataset.step=="bea" ? "$(dataset.sector_level).yml" : "$(dataset.step).yml"
        path = joinpath(SLIDE_DIR,"src","build","readfiles","input",file)

        if isfile(path)
            merge!(d, read_from(path))
            [d[k] = edit_with(df, Deselect([:units],"==")) for (k,df) in d]
        end

    elseif dataset.build=="eem"
        if dataset.step=="seds"
            merge!(d, read_from(joinpath(SLIDE_DIR,"data","input","eia")))
        end
    end

    dataset.step = "input"
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
    lst = list(dataset)
    df = read_file(joinpath(READ_DIR,"parameters","define.csv"))
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
        tmp = read_from(joinpath(READ_DIR, "parameterlist_$(dataset.build).yml"))
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
    return set_sector!(set, unique(map_identity(x, set[:sector])[:,to]))
end

function _set_sector!(set, x::Mapping, to::AbstractArray)
    return set_sector!(set, unique(x.data[:, first(to)]))
end