"""
    impute_mean(df::DataFrame, col::Symbol)
This function fills missing values in `df` with the average over the index given in `col`
using the standard mean. For a parameter ``z`` imputed over an index ``x``, the average
``\\bar{z}`` would be calculated:
```math
\\bar{z} = \\dfrac{\\sum_x z}{N}
```

If a weight ``w`` is given, the weighted average would be calculated:
```math
\\bar{z} = \\dfrac{\\sum_x z \\cdot w}{\\sum_x w}
```

This process of filling missing values is called "mean imputation".

# Arguments
- `df::DataFrame` with missing values
- `col::Symbol` over which to average.

# Keyword Arguments
- `weight::DataFrame=DataFrame()` to use  when weighting.
- `condition::DataFrame=DataFrame()` on which indices to keep in the output `df_avg`.
    If no condition is given, all `NaN` values in the input `df` will be replaced.

Returns
- `df_avg::DataFrame` of mean.
- `df::DataFrame` of unchanged values
"""
function impute_mean(df, col; weight=DataFrame(), condition=DataFrame(), add=DataFrame())
    # !!!! see...
    # https://github.com/invenia/Impute.jl
    # https://link.springer.com/content/pdf/bbm%3A978-0-85729-829-4%2F1.pdf
    # 
    if isempty(condition)
        condition, df = split_with(df, (value=NaN,))
        condition = condition[:, findindex(condition)]
        kind = :inner
    else
        idx = intersect(findindex(df), propertynames(condition))
        condition = antijoin(condition, df, on=idx)
        kind = :outer
    end

    # Calculate average.
    if isempty(condition)
        dfavg = DataFrame()
    else
        dfavg = if isempty(weight)
            combine_over(df, col; fun=Statistics.mean)
        else
            combine_over(df * weight, col) / combine_over(weight, col)
        end
        
        dfavg = indexjoin(condition, dfavg; kind=kind)
    end

    # Add missing column(s) to df as necessary.
    add = add[:,setdiff(findindex(condition), findindex(df))]
    !isempty(add) && (df = crossjoin(df, add))

    return vcat(dfavg, df; cols=:intersect)
end


"""
"""
function split_condition(df::DataFrame, value=NaN)
    condition, df = split_with(df, (value=value,))
    condition = condition[:, findindex(condition)]
    return condition, df, :inner
end

function split_condition(df::DataFrame, condition::DataFrame, args...)
    if isempty(condition)
        return split_condition(df, args...)
    else
        idx = intersect(findindex(df), propertynames(condition))
        condition = antijoin(condition, df, on=idx)
        return select(condition,idx), df, :outer
    end
end