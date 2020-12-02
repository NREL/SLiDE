# This file declares functions used for loading and manipulating data and sets within the
# model file. It should be included at the beginning after loading other packages

# !!!! Where might ensurefinite go within src directory?
"This function replaces `NaN` or `Inf` values with `0.0`."
ensurefinite(x::Float64) = (isnan(x) || x==Inf) ? 0.0 : x


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


# !!!! Collapse _model_input into a single function
"""
    _model_input(year::Int, d::Dict{Symbol,DataFrame}, set::Dict, idx::Dict)

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
function _model_input(year::Int, d::Dict{Symbol,DataFrame}, set::Dict, idx::Dict = Dict())
    @info("Preparing model data for $year.")

    d = Dict(k => filter_with(df, (yr = year,); drop = true) for (k,df) in d)

    isempty(idx) && (idx = Dict(k => findindex(df) for (k,df) in d))
    (set, idx) = _model_set!(d, set, idx)

    d = Dict(k => convert_type(Dict, fill_zero(set, df)) for (k,df) in d)
    return (d, set, idx)
end

function _model_input(year::Array{Int,1}, d::Dict{Symbol,DataFrame}, set::Dict, idx::Dict = Dict())
        @info("Preparing model data for $year.")

        d2 = Dict(k => filter_with(df, (yr = year,); extrapolate = true, drop = false) for (k,df) in d)

        isempty(idx) && (idx = Dict(k => findindex(df) for (k,df) in d2))
        (set, idx) = _model_set!(d2, set, idx)

        d1 = Dict(k => filter_with(df, (yr = year,); drop = true) for (k,df) in d)
        d1 = Dict(k => convert_type(Dict, fill_zero(set, df)) for (k,df) in d1)
        return (d1, set, idx)
end

function _model_input(year::UnitRange{Int64}, d::Dict{Symbol,DataFrame}, set::Dict, idx::Dict = Dict())
        return _model_input(ensurearray(year), d, set, idx)
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
    return (set, idx)
end


"""
    yrsbool(years::Array{Int,1})
This function to sort model years, produce first year, last year, booleans, and interval

# Arguments
- `years::Array{Int,1}` array of years to model

# Returns
- `years::Array{Int,1}` sorted array of years to model
- `yrlast::Int` last year in years array
- `yrfirst::Int` first year in years array
- `islast::Dict` of booleans [1] indicating last year
- `isfirst::Dict` of booleans [1] indicating first year
- `yrdiff::Dict` of differences between years

# Usage
years = [2017, 2016, 2019, 2018]
(years, yrl, yrf, islast, isfirst, yrdiff) = yrsbool(years)
"""
function yrsbool(years::Array{Int,1})
    years = sort(years)
    yrlast = years[length(years)]
    yrfirst = years[1]
    islast = Dict(years[k] => (years[k] == yrlast ? 1 : 0) for k in keys(years))
    isfirst = Dict(years[k] => (years[k] == yrfirst ? 1 : 0) for k in keys(years))
    yrdiff = Dict(years[k+1] => years[k+1]-years[k] for k in 1:(length(years)-1))
    return (years, yrlast, yrfirst, islast, isfirst, yrdiff)
end

"If given a unit range such as years = 2016:2019 instead of array"
function yrsbool(years::UnitRange{Int64})
    return yrsbool(ensurearray(years))
end
