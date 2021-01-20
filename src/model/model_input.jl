"""
    model_input(year::Int, d::Dict{Symbol,DataFrame}, set::Dict, idx::Dict)

# Arguments
- `year::Int`: year for which to perform calibration
- `d::Dict{Symbol,DataFrame}` of DataFrames containing the model data.
- `set::Dict` of Arrays describing region, sector, final demand, etc.
- `idx::Dict` of parameter indices

# Returns
- `d::Dict{Symbol,Dict}` of model data with all zeros filled
- `set::Dict` of model indices, with added arrays of tuples indicating which (region,sector)
    or (region,good) combinations are relevant to the zero-profit and market-clearing
    conditions.
- `idx::Dict` of parameter indices.
"""
function model_input(year::Any, d::Dict{Symbol,DataFrame}, set::Dict, idx::Dict=Dict())
    return model_input(ensurearray(year), d, set, idx)
end


function model_input(year::Array{Int,1}, d::Dict{Symbol,DataFrame}, set::Dict, idx::Dict=Dict())
    @info("Preparing model data for $year.")
    if length(year) > 1
        d2 = Dict(k => filter_with(df, (yr = year,); extrapolate=true) for (k, df) in d)

        isempty(idx) && (idx = Dict(k => findindex(df) for (k, df) in d2))
        (set, idx) = _model_set!(d2, set, idx)

        d1 = Dict(k => filter_with(df, (yr = year,); drop=true) for (k, df) in d)
        d1 = Dict(k => convert_type(Dict, fill_zero(set, df)) for (k, df) in d1)
        return (d1, set, idx)
    else
        d = Dict(k => filter_with(df, (yr = year,); drop=true) for (k, df) in d)

        isempty(idx) && (idx = Dict(k => findindex(df) for (k, df) in d))
        (set, idx) = _model_set!(d, set, idx)

        d = Dict(k => convert_type(Dict, fill_zero(set, df)) for (k, df) in d)
        return (d, set, idx)
    end
end


"""
    _model_set!(d::Dict{Symbol,DataFrame}, set::Dict, idx::Dict)
This function returns subsets intended to limit the size of the model by including only
non-zero values when mapping zero-profit and market-clearing conditions.

# Arguments
- `d::Dict{Symbol,DataFrame}` of DataFrames containing the model data.
- `set::Dict` of Arrays describing region, sector, final demand, etc.
- `idx::Dict` of parameter indices

# Returns
- `d::Dict{Symbol,Dict}` of model data with all zeros filled
- `set::Dict` of model indices, with added arrays of tuples indicating which (region,sector)
    or (region,good) combinations are relevant to the zero-profit and market-clearing
    conditions.
- `idx::Dict` of indices, updated to include those used to define the newly-added sets.
"""
function _model_set!(d::Dict{Symbol,DataFrame}, set::Dict, idx::Dict)
    (set[:A], idx[:A]) = nonzero_subset(d[:a0] + d[:rx0])
    (set[:Y], idx[:Y]) = nonzero_subset(combine_over(d[:ys0], :g))
    (set[:X], idx[:X]) = nonzero_subset(d[:s0])
    (set[:PA], idx[:PA]) = nonzero_subset(d[:a0])
    (set[:PD], idx[:PD]) = nonzero_subset(d[:xd0])
    (set[:PK], idx[:PK]) = nonzero_subset(d[:kd0])
    (set[:PY], idx[:PY]) = nonzero_subset(d[:s0])

    if :yr in idx[:kd0]
        set[:PKT] = convert_type(Array{Tuple}, unique(d[:kd0][:,setdiff(idx[:kd0], [:yr])]))
    end

    return (set, idx)
end


"""
    nonzero_subset(df::DataFrame)

# Returns
- `x::Array{Tuple,1}` of all parameter indices corresponding with non-zero values
- `idx::Array{Symbol,1}` of parameter indices in `df`
"""
function nonzero_subset(df::DataFrame)
    idx = findindex(df)
    val = convert_type(Array{Tuple}, dropzero(df)[:,idx])
    return (val, idx)
end