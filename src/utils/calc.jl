"""
    Base.:/(df1::DataFrame, df2::DataFrame)
Extends / to operate on 2 DataFrames, each with one column of AbstractFloat type.
The operation will join the DataFrames on their descriptive columns to ensure the operation
is performed for related values. Values that are "missing" after joining are set to 0.
"""
function Base.:/(df1::DataFrame, df2::DataFrame)
    out = Symbol.(:x, 1:2)

    df = indexjoin(copy.([df1,df2]); valnames = out)

    df[!,:value] .= df[:, out[1]] ./ df[:, out[2]]

    return df[:, setdiff(propertynames(df),out)]
end


"""
    Base.:+(df::Vararg{DataFrame})
Extends + to operate on 2+ DataFrames, each with one column of AbstractFloat type.
The operation will join the DataFrames on their descriptive columns to ensure the operation
is performed for related values. Values that are "missing" after joining are set to 0.
"""
function Base.:+(df::Vararg{DataFrame})
    N = length(df)
    out = Symbol.(:x, 1:N)

    if length(findvalue.(df)) > N
        @error("Can only add DataFrames with one value column EACH.")
    end

    df = indexjoin(ensurearray(df); valnames = out)

    df[!,:value] .= df[:, out[1]];
    [df[!,:value] += df[:, out[ii]] for ii in 2:N]

    return df[:, setdiff(propertynames(df),out)]
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

    if length(findvalue.(df)) > N
        @error("Can only subtract DataFrames with one value column EACH.")
    end

    df = indexjoin(ensurearray(df); valnames = out)

    df[!,:value] .= df[:, out[1]];
    [df[!,:value] -= df[:, out[ii]] for ii in 2:N]

    return df[:, setdiff(propertynames(df),out)]
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

    if length(findvalue.(df)) > N
        @error("Can only multiply DataFrames with one value column EACH.")
    end

    df = indexjoin(ensurearray(df); valnames = out)

    df[!,:value] .= df[:, out[1]];
    [df[!,:value] .*= df[:, out[ii]] for ii in 2:N]

    return df[:, setdiff(propertynames(df),out)]
end


"""
    combine_over(df::DataFrame, col::Array{Symbol,1}; operation::Function = sum)
    combine_over(df::DataFrame, col::Symbol; operation::Function = sum)
This function applies [`combine`](https://juliadata.github.io/DataFrames.jl/stable/lib/functions/#DataFrames.combine)
to the input DataFrame `df` over the input column(s) `col`.

# Arguments
- `df::DataFrame`: DataFrame on which to operate.
- `col::Symbol` or `col::Array{Symbol,1}`: column(s) over which to operate.

# Keyword Arguments
- `operation::Function = sum`: Operation to perform over the DataFrame columns. By default,
    the function will return a summation. Other standard summary functions include: `sum`,
    `prod`, `minimum`, `maximum`, `mean`, `var`, `std`, `first`, `last` and `length`.

# Returns
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

# Arguments
- `df::DataFrame`: DataFrame on which to operate.
- `col::Symbol` or `col::Array{Symbol,1}`: column(s) over which to operate.

# Keyword Arguments
- `operation::Function = sum`: Operation to perform over the DataFrame columns. By default,
    the function will return a summation. Other standard summary functions include: `sum`,
    `prod`, `minimum`, `maximum`, `mean`, `var`, `std`, `first`, `last` and `length`.

# Returns
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