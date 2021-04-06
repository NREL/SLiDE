"""
    build(; kwargs...)
This function will execute the SLiDE buildstream and generate the parameters necessary to
run the model. If the dataset has already been generated and saved, the function will read
and return those values.

Otherwise, it will read BEA supply/use data from the `/SLIDE_DIR/data/input/` directory.

Then, execute the four steps of the SLiDE buildstream by executing the following functions:
1. [`SLiDE.partition_national`](@ref)
2. [`SLiDE.calibrate_national`](@ref)
3. [`SLiDE.share_region`](@ref)
4. [`SLiDE.disaggregate_region`](@ref)

This information will be saved in the following structure:

    /SLIDE_DATA/data/dataset/
    ├── parameters/
    └── sets/

# Arguments
- `dataset::String`: dataset identifier

# Keywords
- `save_build::Bool = false`: That decides whether to save the information at each build
    step. Setting `save_build = true` will add the directory `/SLIDE_DATA/data/dataset/build`
    to contain a subdirectory for each of the four build steps.
- `overwrite::Bool = false`: If data exists, do not read it. Build the data from scratch.

# Returns
- `d::Dict{Symbol,DataFrame}` of model parameters
- `set::Dict{Any,Array}` of Arrays describing parameter indices (years, regions, goods, sectors, etc.)
"""
function build(dataset::Dataset)
    d = read_build(dataset)
    set = read_set(dataset)
    
    if dataset.step=="input"
        d, set = partition_national(dataset, d, set)
        d = calibrate_national(dataset, d, set)
        d, set = share_region(dataset, d, set)
        d, set = disaggregate_region(dataset, d, set)

        write_build!(set!(dataset; step=SLiDE.SET_DIR), set)
    end

    return d, set
end


"""
    datapath()
"""
function datapath(dataset::Dataset)
    path = joinpath(datapath(),dataset.name,dataset.build)
    path = if dataset.step in [SLiDE.PARAM_DIR, SLiDE.SET_DIR]
        joinpath(path, dataset.step)
    else
        joinpath(path, SLiDE._development(dataset.step))
    end
    return path
end

datapath() = joinpath(SLIDE_DIR,"data")


"""
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
"""
function write_build(path, k, df::DataFrame)
    println("  Writing $k")
    CSV.write(joinpath(path,"$k.csv"), df)
end

function write_build(path, k, v::AbstractArray)
    println("  Writing $k")
    CSV.write(joinpath(path,"$k.csv"), DataFrame(k=>v))
end

write_build(path, k, v) = nothing


"""
    read_set()
"""
function read_set(dataset::Dataset)
    set = read_set(dataset, "io")
    dataset.eem && merge!(set, read_set(dataset, "eem"))
    return set
end

function read_set(build::String; sector=:summary)
    println("READING FROM READFILES")
    READ_DIR = joinpath(SLIDE_DIR,"src","build","readfiles")
    set = read_from(joinpath(READ_DIR,"setlist_$build.yml"))

    (build=="io" && !haskey(set, :sector)) && SLiDE.set_sector!(set, set[sector])

    return Dict{Any,Any}(set)
end

function SLiDE.read_set(dataset::Dataset, build::String)
    path = SLiDE.datapath(SLiDE.set!(copy(dataset); build=build, step=SLiDE.SET_DIR))
    if isdir(path)
        set = read_from(path)
        set = Dict(k => df[:,1] for (k,df) in set)
    else
        set = SLiDE.read_set(build; sector=dataset.sector)
    end

    build=="io" && SLiDE.set_sector!(set, set[:sector])
    return Dict{Any,Any}(set)
end


"""
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


function read_map()
    path = joinpath(SLIDE_DIR,"src","build","readfiles")
    return read_from(joinpath(path, "maplist.yml"))
end


"""
"""
function read_input!(dataset::Dataset)
    d = Dict()
    
    if dataset.build=="io"
        path = joinpath(SLIDE_DIR,"src","build","readfiles","input")
        dataset.step==PARAM_DIR && set!(dataset; step="partition")
        dataset.step=="partition" && (path = joinpath(path, "$(dataset.sector).yml"))
        dataset.step=="share" && (path = joinpath(path, "share.yml"))

        if isfile(path)
            merge!(d, read_from(path))
            [d[k] = edit_with(df, Deselect([:units],"==")) for (k,df) in d]

            dataset.step=="partition" && push!(d, :sector=>dataset.sector)
            dataset.step = "input"
        end
    elseif dataset.build=="eem"
        if dataset.step=="partition"
            d = read_from(joinpath(SLIDE_DIR,"data","input","eia"))
        end
    end
    return d
end


"""
    filter_build!(dataset::String, d::Dict)
This function filters `d` to contain only keys relevant to the specified `dataset`.
This avoids cluttering a saved directory with superfluous parameters that may have been
calculated at intermediate steps.

If filtering DataFrames, this reorders the DataFrame indices. This is important when
importing parameters into JuMP models when calibrating or modeling.
"""
function filter_build!(dataset::Dataset, d::Dict)
    lst = SLiDE.describe_parameters(dataset)
    return SLiDE._filter_with!(d, lst)
end


"""
"""
function _filter_with!(d::Dict, lst::Dict{Symbol,Parameter})
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
    describe_parameters(step::String)

# Arguments
- `step::String`: Internally-passed parameter indicating the type of information to save
    (set, parameter, or build step)

# Returns
- `d::Dict{Symbol,`[`Parameter`](@ref)`}` of Parameters relevant to the specified data
    step. The dictionary key is consistent the value's field `parameter`.
"""
function describe_parameters(step::String)
    step = convert_type(Symbol, step)
    lst = read_from(joinpath(READ_DIR,"parameterlist.yml"))

    !haskey(lst, step) && (return nothing)

    df = read_file(joinpath(READ_DIR,"parameters","define.csv"))
    df = innerjoin(DataFrame(parameter=lst[step]), df, on=:parameter)

    d = if isempty(df); convert_type.(Symbol, lst[step])
    else;               load_from(Dict{Parameter}, df)
    end
    
    return d
end

describe_parameters(dataset::Dataset) = describe_parameters(dataset.step)


"""
"""
function describe_parameters!(set::Dict, step::Symbol)
    if !haskey(set, step)
        set[step] = SLiDE.describe_parameters("$step")
    end
    return set[step]
end


"""
"""
function list_parameters!(set::Dict, step::Symbol)
    step_list = append(step,:list)
    if !haskey(set, step_list)
        set[step_list] = if step==:taxes
            [:ta0,:ty0,:tm0]
        else
            collect(keys(describe_parameters!(set, step)))
        end
    end
    return set[step_list]
end


"""
"""
function set_sector!(set::Dict, x::AbstractArray)
    [set[k] = x for k in [:s,:g,:sector]]
    return set
end