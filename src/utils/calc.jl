using CSV
using DataFrames
using DelimitedFiles
using YAML
using Query
using Base

function _join_to_operate(df::Array{DataFrame,1})
    N = length(df)

    inp = vcat.(find_oftype.(df, AbstractFloat), find_oftype.(df, Bool))
    out = Symbol.(:x, 1:N)
    cols = intersect(setdiff.(propertynames.(df), inp)...)

    if any(length.(inp) .!= 1)
        error("Can only operate on DataFrames with one AbstractFloat column.")
    else
        inp = collect(Iterators.flatten(inp))
    end

    df_ans = edit_with(df[1], Rename(inp[1], out[1]));
    if length(cols) == 0
        [df_ans = crossjoin(df_ans, edit_with(df[ii], Rename(inp[ii], out[ii]))) for ii in 2:N]
    else
        [df_ans = outerjoin(df_ans, edit_with(df[ii], Rename(inp[ii], out[ii])),
            on = cols) for ii in 2:N]
    end
    
    df_ans = edit_with(df_ans, Replace.(out, missing, 0))
    return df_ans
end

function Base.:/(df::Vararg{DataFrame})
    N = length(df)
    out = Symbol.(:x, 1:N)

    N > 2 && error("Can only divide one DataFrame by another.")

    df = _join_to_operate(copy.(ensurearray(df)))
    df[!,:value] .= df[:, out[1]] ./ df[:, out[2]]
    df[isnan.(df[:,:value]),:value] .= 0

    return df[:, [setdiff(propertynames(df), [:value; out]); :value]]
end

function Base.:+(df::Vararg{DataFrame})
    N = length(df)
    out = Symbol.(:x, 1:N)

    df = _join_to_operate(copy.(ensurearray(df)))

    df[!,:value] .= df[:, out[1]];
    [df[!,:value] += df[:, out[ii]] for ii in 2:N]

    return df[:, [setdiff(propertynames(df), [:value; out]); :value]]
end

function Base.:-(df::Vararg{DataFrame})
    N = length(df)
    out = Symbol.(:x, 1:N)

    df = _join_to_operate(copy.(ensurearray(df)))

    df[!,:value] .= df[:, out[1]];
    [df[!,:value] -= df[:, out[ii]] for ii in 2:N]

    return df[:, [setdiff(propertynames(df), [:value; out]); :value]]
end

function Base.:*(df::Vararg{DataFrame})
    N = length(df)
    out = Symbol.(:x, 1:N)

    df = _join_to_operate(copy.(ensurearray(df)))

    df[!,:value] .= df[:, out[1]];
    [df[!,:value] .*= df[:, out[ii]] for ii in 2:N]

    return df[:, [setdiff(propertynames(df), [:value; out]); :value]]
end

Base.:*(x::Int, df::DataFrame) =  DataFrame(temp = convert_type(Float64, x)) * df
Base.:+(x::Int, df::DataFrame) =  DataFrame(temp = convert_type(Float64, x)) + df
Base.:-(x::Int, df::DataFrame) =  DataFrame(temp = convert_type(Float64, x)) - df
Base.:/(x::Int, df::DataFrame) =  DataFrame(temp = convert_type(Float64, x)) / df

Base.:*(df::DataFrame, x::Int) = x * df
Base.:+(df::DataFrame, x::Int) = x + df
Base.:-(df::DataFrame, x::Int) = x - df
Base.:/(df::DataFrame, x::Int) = df / DataFrame(temp = convert_type(Float64, x))

"""
    sum_over(df::DataFrame, col::Array{Symbol,1}; kwargs...)
    sum_over(df::DataFrame, col::Symbol; kwargs...)
This function sums a DataFrame over the specified column(s) and returns either
a list of values or the full DataFrame.

# Arguments:
- `df::DataFrame`: DataFrame to sum.
- `col::Symbol` or `col::Array{Symbol,1}`: columns over which to sum.

# Keyword Arguments:
- `values_only::Bool = true`: Should the function return a list of values or an altered DataFrame?
    - Set to `true` (default) if populating an existing DataFrame including all of the
        columns in the input DataFrame (in the same order) with the exception of that/those
        in `col`.
    - Set to `false` if modifying or copying the input DataFrame.

# Returns:
- `lst::Array{Float64,1}` of summed values in the order determined by the descriptor columns
    if `values_only = true` (default)
- `df::DataFrame`: Modified input DataFrame if `values_only = false`
"""
function sum_over(df::DataFrame, col::Array{Symbol,1}; values_only = true, keepkeys = false)

    inp_keys = df[:,find_oftype(df, Not(AbstractFloat))]
    val_cols = find_oftype(df, AbstractFloat)
    by_cols = setdiff(propertynames(df), [col; val_cols])

    gd = groupby(df, by_cols);
    df = combine(gd, val_cols .=> sum)

    # df = by(df, by_cols, Pair.(val_cols, sum))
    df = edit_with(df, Rename.(setdiff(propertynames(df), by_cols), val_cols))

    keepkeys && (df = leftjoin(inp_keys, df, on = by_cols))
    return values_only ? df[:,val_cols[1]] : df
end

function sum_over(df::DataFrame, col::Symbol; values_only = true, keepkeys = false)
    return sum_over(df, [col]; values_only = values_only, keepkeys = keepkeys)
end

function combine_over(df::DataFrame, col::Array{Symbol,1}; operation::Symbol = :sum)
    inp_keys = df[:,find_oftype(df, Not(AbstractFloat))]
    val_cols = find_oftype(df, AbstractFloat)
    by_cols = setdiff(propertynames(df), [col; val_cols])

    ans = if operation == :sum
        combine(groupby(df, by_cols), val_cols .=> sum .=> val_cols)
    end

    return ans
end

function combine_over(df::DataFrame, col::Symbol; operation::Symbol = :sum)
    return combine_over(df, [col]; operation = operation)
end

function transform_over(df::DataFrame, col::Array{Symbol,1}; operation::Symbol = :sum)
    inp_keys = df[:,find_oftype(df, Not(AbstractFloat))]
    val_cols = find_oftype(df, AbstractFloat)
    by_cols = setdiff(propertynames(df), [col; val_cols])

    ans = if operation == :sum
        transform(groupby(df, by_cols), val_cols .=> sum .=> val_cols)
    end

    return ans
end

function transform_over(df::DataFrame, col::Symbol; operation::Symbol = :sum)
    return transform_over(df, [col]; operation = operation)
end