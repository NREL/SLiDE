using CSV
using DataFrames
using DelimitedFiles
using YAML
using Query
using Base

"""
    _join_to_operate(df::Array{DataFrame,1})
    _join_to_operate(df::Vararg{DataFrame})
"""
function _join_to_operate(df::Array{DataFrame,1})
    df = copy(df)
    N = length(df)
    
    inp = vcat.(find_oftype.(df, AbstractFloat), find_oftype.(df, Bool))
    out = Symbol.(:x, 1:N)
    cols = setdiff.(propertynames.(df), inp)

    if any(length.(inp) .!= 1)
        error("Can only operate on DataFrames with one AbstractFloat column.")
    else
        inp = collect(Iterators.flatten(inp))
    end

    df_ans = edit_with(df[1], Rename(inp[1], out[1]))
    for ii in 2:N
        cols[ii] = intersect(propertynames(df_ans), cols[ii])
        df_ans = if length(cols[ii]) == 0
            crossjoin(df_ans, edit_with(df[ii], Rename(inp[ii], out[ii])))
        else
            outerjoin(df_ans, edit_with(df[ii], Rename(inp[ii], out[ii])), on = cols[ii])
        end
    end

    df_ans = edit_with(df_ans, Replace.(out, missing, 0))
    return df_ans
end

_join_to_operate(df::Vararg{DataFrame}) = _join_to_operate(ensurearray(df))

"""
    Base.:/(df1::DataFrame, df2::DataFrame)
Extends / to operate on 2 DataFrames, each with one column of AbstractFloat type.
The operation will join the DataFrames on their descriptive columns to ensure the operation
is performed for related values. Values that are "missing" after joining are set to 0.
"""
function Base.:/(df1::DataFrame, df2::DataFrame)
    out = Symbol.(:x, 1:2)

    df_ans = _join_to_operate(copy.([df1, df2]))
    df_ans[!,:value] .= df_ans[:, out[1]] ./ df_ans[:, out[2]]

    return df_ans[:, [setdiff(propertynames(df_ans), [:value; out]); :value]]
end

# function Base.:/(df::Vararg{DataFrame})
#     N = length(df)
#     out = Symbol.(:x, 1:N)

#     N > 2 && error("Can only divide one DataFrame by another.")

#     df = _join_to_operate(copy.(ensurearray(df)))
#     df[!,:value] .= df[:, out[1]] ./ df[:, out[2]]
#     # df[isnan.(df[:,:value]),:value] .= 0

#     return df[:, [setdiff(propertynames(df), [:value; out]); :value]]
# end

"""
    Base.:+(df::Vararg{DataFrame})
Extends + to operate on 2+ DataFrames, each with one column of AbstractFloat type.
The operation will join the DataFrames on their descriptive columns to ensure the operation
is performed for related values. Values that are "missing" after joining are set to 0.
"""
function Base.:+(df::Vararg{DataFrame})
    N = length(df)
    out = Symbol.(:x, 1:N)

    df_ans = _join_to_operate(copy.(ensurearray(df)))

    df_ans[!,:value] .= df_ans[:, out[1]];
    [df_ans[!,:value] += df_ans[:, out[ii]] for ii in 2:N]

    return df_ans[:, [setdiff(propertynames(df_ans), [:value; out]); :value]]
end

"""
    Base.:-(df::Vararg{DataFrame})
Extends - to operate on 2+ DataFrames, each with one column of AbstractFloat type.
The operation will join the DataFrames on their descriptive columns to ensure the operation
is performed for related values. Values that are "missing" after joining are set to 0.
"""
function Base.:-(df::Vararg{DataFrame})
    N = length(df)
    out = Symbol.(:x, 1:N)

    df = _join_to_operate(copy.(ensurearray(df)))

    df[!,:value] .= df[:, out[1]];
    [df[!,:value] -= df[:, out[ii]] for ii in 2:N]

    return df[:, [setdiff(propertynames(df), [:value; out]); :value]]
end

"""
    Base.:*(df::Vararg{DataFrame})
Extends * to operate on 2+ DataFrames, each with one column of AbstractFloat type.
The operation will join the DataFrames on their descriptive columns to ensure the operation
is performed for related values. Values that are "missing" after joining are set to 0.
"""
function Base.:*(df::Vararg{DataFrame})
    N = length(df)
    out = Symbol.(:x, 1:N)

    df = _join_to_operate(copy.(ensurearray(df)))

    df[!,:value] .= df[:, out[1]];
    [df[!,:value] .*= df[:, out[ii]] for ii in 2:N]

    return df[:, [setdiff(propertynames(df), [:value; out]); :value]]
end

"""
    combine_over(df::DataFrame, col::Array{Symbol,1}; operation::Function = sum)
    combine_over(df::DataFrame, col::Symbol; operation::Function = sum)
This function applies [`combine`](https://juliadata.github.io/DataFrames.jl/stable/lib/functions/#DataFrames.combine)
to the input DataFrame `df` over the input column(s) `col`.

# Arguments:
- `df::DataFrame`: DataFrame on which to operate.
- `col::Symbol` or `col::Array{Symbol,1}`: column(s) over which to operate.

# Keyword Arguments:
- `operation::Function = sum`: Operation to perform over the DataFrame columns. By default,
    the function will return a summation. Other standard summary functions include: `sum`,
    `prod`, `minimum`, `maximum`, `mean`, `var`, `std`, `first`, `last` and `length`.

# Returns:
- `df::DataFrame` WITHOUT the specified column(s) argument. The resulting DataFrame will be
    'shorter' than the input DataFrame.
"""
function combine_over(df::DataFrame, col::Array{Symbol,1}; fun::Function = sum)
    cols_ans = setdiff(propertynames(df), col)

    # val_cols = find_oftype(df, AbstractFloat)
    val_cols = [find_oftype(df, AbstractFloat); find_oftype(df, Bool)]
    by_cols = setdiff(propertynames(df), [col; val_cols])
    df_ans = combine(groupby(df, by_cols), val_cols .=> fun .=> val_cols)
    [df_ans[!,col] .= convert_type.(Float64, df_ans[:,col]) for col in val_cols
        if eltype(df_ans[:,col]) == Int]
    return df_ans[:,cols_ans]
end

function combine_over(df::DataFrame, col::Symbol; fun::Function = sum)
    return combine_over(df, ensurearray(col); fun = fun)
end

"""
    transform_over(df::DataFrame, col::Array{Symbol,1}; operation::Function = sum)
    transform_over(df::DataFrame, col::Symbol; operation::Function = sum)
This function applies [`transform`](https://juliadata.github.io/DataFrames.jl/stable/lib/functions/#DataFrames.transform)
to the input DataFrame `df` over the input column(s) `col`.

# Arguments:
- `df::DataFrame`: DataFrame on which to operate.
- `col::Symbol` or `col::Array{Symbol,1}`: column(s) over which to operate.

# Keyword Arguments:
- `operation::Function = sum`: Operation to perform over the DataFrame columns. By default,
    the function will return a summation. Other standard summary functions include: `sum`,
    `prod`, `minimum`, `maximum`, `mean`, `var`, `std`, `first`, `last` and `length`.

# Returns:
- `df::DataFrame` WITH the specified column(s) argument. The resulting DataFrame will be
    the same length as the input DataFrame.
"""
function transform_over(df::DataFrame, col::Array{Symbol,1}; fun::Function = sum)
    cols_ans = propertynames(df)

    val_cols = [find_oftype(df, AbstractFloat); find_oftype(df, Bool)]
    by_cols = setdiff(propertynames(df), [col; val_cols])
    df_ans = transform(groupby(df, by_cols), val_cols .=> fun .=> val_cols)
    [df_ans[!,col] .= convert_type.(Float64, df_ans[:,col]) for col in val_cols
        if eltype(df_ans[:,col]) == Int]
    return df_ans[:,cols_ans]
end

function transform_over(df::DataFrame, col::Symbol; fun::Function = sum)
    return transform_over(df, ensurearray(col); fun = fun)
end

"""
    sum_over(df::DataFrame, col::Array{Symbol,1}; kwargs...)
    sum_over(df::DataFrame, col::Symbol; kwargs...)
This function sums a DataFrame over the specified column(s) and returns either
a list of values or the full DataFrame.

# Arguments:
- `df::DataFrame` to sum.
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