"""
    compare_summary(df_lst::Array{DataFrame,1}, inds::Array{Symbol,1}; kwargs...)

# Arguments
- df_lst::Array{DataFrame,1}: List of DataFrames to compare.
    These must all share the same column names.
- `inds::Array{Symbol,1}`: List of indicators that describe each DataFrame and track which
    values/keys are present in each DataFrame. There must be an equal number of input
    DataFrames and indicators.

# Keyword Argument
- `tol::Float64 = 1E-6`: Tolerance used when determining whether values are equal.
    Default values is `1E-6`.
"""
function compare_summary(df_lst::Array{DataFrame,1}, inds::Array{Symbol,1}; tol = 1E-6)
    df_lst = copy.(df_lst)
    N = length(df_lst)

    # Rename columns to indicate which values go with which data set.
    val_0 = intersect(find_oftype.(df_lst, AbstractFloat)...)
    vals = [Symbol.(val_0, :_, ind) for ind in inds]
    cols = setdiff(intersect(names.(df_lst)...), val_0)

    # Print warning if attempting to compare multiple values at once. We're not there yet.
    if length(val_0) > 1
        val_0 = ensurearray(val_0[1])
        @warn("compare_summary currently supports comparing one column of values/DataFrame.")
    end

    # Make all keys lowercase to focus on value comparisons.
    df_lst = [edit_with(df, Rename.(val_0, val)) for (df, val) in zip(df_lst, vals)]
    vals = [vals...;]

    # Join all dataframes.
    df = df_lst[1]
    [df = outerjoin(df, df_lst[ii], on = cols) for ii in 2:N]
    [df[!,ind] .= .!ismissing.(df[:,val]) for (ind, val) in zip(inds, vals)]
    
    # Are all keys equal/present in the DataFrame?
    df[!,:equal_keys] .= prod.(eachrow(df[:,inds]))
    
    # Are there discrepancies between PRESENT values (within the specified tolerance)?
    # All values in a row x will be considered "equal" if (max(x) - x_i) / mean(x) < tol
    df_comp = (maximum.(skipmissing.(eachrow(df[:,vals]))) .- df[:,vals]) ./
        Statistics.mean.(skipmissing.(eachrow(df[:,vals])))
    df[!,:equal_values] .= all.(skipmissing.(eachrow(df_comp .< tol)))
    
    return sort(df[:,[cols; sort(vals); sort(inds); [:equal_keys, :equal_values]]], cols)
end

"""
    compare_values(df_lst::Array{DataFrame,1}, inds::Array{Symbol,1})

# Arguments
- df_lst::Array{DataFrame,1}: List of DataFrames to compare.
    These must all share the same column names.
- `inds::Array{Symbol,1}`: List of indicators that describe each DataFrame and track which
    values/keys are present in each DataFrame. There must be an equal number of input
    DataFrames and indicators.

# Keyword Argument
- `tol::Float64 = 1E-6`: Tolerance used when determining whether values are equal.
    Default values is `1E-6`.
"""
function compare_values(df_lst::Array{DataFrame,1}, inds::Array{Symbol,1}; tol = 1E-6)
    df_lst = copy.(df_lst)
    df = compare_summary(copy.(df_lst), inds; tol = tol)
    df = df[.!df[:,:equal_values],:]

    size(df,1) > 0 && @warn("Inconsistent values:", df)
    return df
end

"""
    compare_keys(df_lst::Array{DataFrame,1}, inds::Array{Symbol,1})

# Arguments
- df_lst::Array{DataFrame,1}: List of DataFrames to compare.
    These must all share the same column names.
- `inds::Array{Symbol,1}`: List of indicators that describe each DataFrame and track which
    values/keys are present in each DataFrame. There must be an equal number of input
    DataFrames and indicators.
"""
function compare_keys(df_lst::Array{DataFrame,1}, inds::Array{Symbol,1})
    df_lst = copy.(df_lst)
    N = length(inds)
    cols = intersect(find_oftype.(df_lst, Not(AbstractFloat))...)

    # Determine whether to consider case when comparing keys. Only consider case if there
    # instances of the same keys with differing cases in the same DataFrame.
    d_unique = Dict(col => Dict(inds[ii] => sort(unique(df_lst[ii][:,col]))
        for ii in 1:N) for col in cols)
    d_lower = Dict(col => Dict(inds[ii] => lowercase.(d_unique[col][inds[ii]])
        for ii in 1:N) for col in cols);
    CHECKCASE = Dict(col => any(length.(unique.(values(d_lower[col]))) .!==
        length.(values(d_unique[col]))) for col in cols)

    d_all = Dict(col => CHECKCASE[col] ? sort(unique([values(d_unique[col])...;])) :
        sort(unique([values(d_lower[col])...;])) for col in cols)

    df = DataFrame()

    for col in cols
        df_temp = DataFrame(key = fill(col, size(d_all[col])))
        d_check = CHECKCASE[col] ? d_unique[col] : d_lower[col]

        [df_temp[!,ind] = [v in d_check[ind] ? d_unique[col][ind][v .== d_check[ind]][1] :
            missing for v in d_all[col]] for ind in inds]
        df_temp = unique(df_temp[length.(unique.(eachrow(df_temp[:,inds]))) .> 1, :])

        df = [df; df_temp]
    end
    
    size(df,1) > 0 && @warn("Inconsistent keys:", df)
    return df
end