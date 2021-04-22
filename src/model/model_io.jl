"""
    model_input(d::Dict, set::Dict, year, ::Type{T})
This function prepares the SLiDE dataset and set lists for modeling.

# Arguments
- `d::Dict{Symbol,DataFrame}` of DataFrames containing the model data.
- `set::Dict` of Arrays describing region, sector, final demand, etc.
- `year::Int` or `yr::AbstractArray`: year(s) for which to perform calibration

# Returns
- `d::Dict{Symbol,Dict}` of model data with all zeros filled
- `set::Dict` of model indices, updated by [`SLiDE._model_set`](@ref)
"""
function _model_input(d, set, year::AbstractArray)
    if length(year)==1
        d, set = _model_input(d, set, first(year))
    else
        d_extrap = Dict(k => filter_with(df, (yr=year,); extrapolate=true) for (k, df) in d)
        set = _model_set!(d_extrap, set; with_year=true)
        set[:yr] = year

        d = Dict(k => filter_with(df, (yr=year,); drop=true) for (k,df) in d)
    end
    
    return d, set
end

function _model_input(d, set, year::Integer)
    d = Dict(k => filter_with(df, (yr=year,); drop=true) for (k,df) in d)
    set = _model_set!(d, set)
    set[:yr] = ensurearray(year)
    return d, set
end

function _model_input(d, set, year, ::Type{T}) where T <: Union{DataFrame,Dict}
    d, set = _model_input(d, set, year)
    T==Dict && (d = Dict(k => convert_type(Dict, fill_zero(df; with=set)) for (k,df) in d))
    return d, set
end


"""
    _model_set!(d::Dict{Symbol,DataFrame}, set::Dict, idx::Dict)
This function returns subsets intended to limit the size of the model by including only
non-zero values when mapping zero-profit and market-clearing conditions.

# Arguments
- `d::Dict{Symbol,DataFrame}` of DataFrames containing the model data.
- `set::Dict` of Arrays describing region, sector, final demand, etc.

# Returns
- `d::Dict{Symbol,Dict}` of model data with all zeros filled
- `set::Dict` of model indices, with added arrays of tuples indicating which (region,sector)
    or (region,good) combinations are relevant to the zero-profit and market-clearing
    conditions.
"""
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