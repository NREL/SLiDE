# https://link.springer.com/content/pdf/bbm%3A978-0-85729-829-4%2F1.pdf

function impute_mean(df, col; weight=DataFrame(), condition=DataFrame())
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
    if isempty(weight)
        dfavg = combine_over(df, col; fun=Statistics.mean)
    else
        dfavg = combine_over(df * weight, col) / combine_over(weight, col)
    end
    
    return indexjoin(condition, dfavg; kind=kind), df
end