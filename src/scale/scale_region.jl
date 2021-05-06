"""
"""
function scale_region!(dataset::Dataset, d::Dict, set::Dict)
    return scale_region!(d, set, dataset.region_level)
end


function scale_region!(d::Dict, set::Dict, region_level::Symbol; path=SCALE_REGION)
    if region_level!==:state
        # dfmap = read_file(path)[:,[append(region_level,:code),:state]]
        dfmap = read_file(path)[:,[region_level,:state]]
        scale_region!(d, set, dfmap)
    end
    return d, set
end


function scale_region!(d::Dict, set::Dict, dfmap::DataFrame)
    mapping = set_scheme!(Mapping(dfmap), DataFrame(r=set[:r],))
    set[:r] = string.(unique(dfmap[:, mapping.to]))
    return scale_region!(d, set, mapping)
end


function scale_region!(d, set, mapping::Mapping)
    inputs = collect(keys(d))
    scale_region!(d, set, mapping, inputs)
    return filter_with!(d, inputs)
end


function scale_region!(d::Dict, set::Dict, scale, var::Symbol; kwargs...)
    scale = compound_region!(d, set, scale, var; kwargs...)
    d[var] = scale_with(d[var], scale; key=var)
    return d[var]
end


function scale_region!(d::Dict, set::Dict, scale, var::AbstractArray; kwargs...)
    [scale_region!(d, set, scale, v; kwargs...) for v in var]
    return d
end


"""
"""
function compound_region!(d::Dict, set::Dict, scale::T, var::Symbol) where T <: Scale
    df = d[var]
    on = find_region(df)
    key = _inp_key(:region,on)
    
    if !haskey(d,key)
        scale = copy(scale)
        
        set_on!(scale, on)
        push!(d, key => compound_for!(scale, set[:r], df))
    end

    return d[key]
end


"""
"""
function find_region(idx::AbstractArray)
    idx = intersect(idx, [:r,:orig,:dest])

    return if length(idx)==0
        missing
    elseif length(idx)==1
        idx[1]
    else
        idx
    end
end

find_region(df::DataFrame) = find_region(propertynames(df))