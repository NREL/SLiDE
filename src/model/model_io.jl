function SLiDE.findindex(df::DataFrame, ::Type{T}) where T<:Any
    idx = findindex(df)
    return convert_type(T, df[:,idx])
end


function add_index!(set::Dict, x::Pair{Symbol,DataFrame}; fun::Function=identity)
    key, df = x[1], x[2]
    push!(set, key => findindex(fun(df), Array{Tuple}))
    return set[key]
end


function _model_set!(d::Dict, set::Dict; with_year::Bool=false)
    add_index!(set, :A => d[:a0]+d[:rx0]; fun=dropzero)
    add_index!(set, :Y => combine_over(d[:ys0],:g); fun=dropzero)
    add_index!(set, :X => d[:s0]; fun=dropzero)
    add_index!(set, :PA => d[:a0]; fun=dropzero)
    add_index!(set, :PD => d[:xd0]; fun=dropzero)
    add_index!(set, :PK => d[:kd0]; fun=dropzero)
    add_index!(set, :PY => d[:s0]; fun=dropzero)

    with_year && add_index!(set, :PKT => combine_over(d[:kd0], :yr))
    return set
end


"""
    model_input(d::Dict, set::Dict, year, ::Type{T})

# Arguments
- `d::Dict{Symbol,DataFrame}` of DataFrames containing the model data.
- `set::Dict` of Arrays describing region, sector, final demand, etc.
- `year::Int`: year for which to perform calibration

# Returns
- `d::Dict{Symbol,Dict}` of model data with all zeros filled
- `set::Dict` of model indices, with added arrays of tuples indicating which (region,sector)
    or (region,good) combinations are relevant to the zero-profit and market-clearing
    conditions.
"""
function _model_input(d, set, year::AbstractArray)
    if length(year)==1
        d, set = _model_input(d, set, first(year))
    else
        d_extrap = Dict(k => filter_with(df, (yr=year,); extrapolate=true) for (k, df) in d)
        set = _model_set!(d_extrap, set; with_year=true)

        d = Dict(k => filter_with(df, (yr=year,); drop=true) for (k,df) in d)
    end
    
    return d, set
end


function _model_input(d, set, year::Integer)
    d = Dict(k => filter_with(df, (yr=year,); drop=true) for (k,df) in d)
    set = _model_set!(d, set)
    return d, set
end

_model_input(args...; kwargs...) = SLiDE._calibration_input(_model_input, args...; kwargs...)