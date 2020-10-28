"""
    compare_summary(df_lst::Array{DataFrame,1}, inds::Array{Symbol,1}; kwargs...)

# Arguments
- `df::Array{DataFrame,1}`: List of DataFrames to compare.
    These must all share the same column names.
- `d::Array{Dict,1}`: Array of dictonaries of DataFrames to compare.
- `indicator::Array{Symbol,1}`: List of indicators that describe each DataFrame and track which
    values/keys are present in each DataFrame. There must be an equal number of input
    DataFrames and indicators.

# Keywords
- `tol::Float64 = 1E-6`: Tolerance used when determining whether values are equal.
    Default values is `1E-6`.
- `complete_summary::Bool = false`: Should we include the full summary DataFrame or only the
    problematic rows (i.e., ones where either `equal_keys = false` or `equal_values = false`)?

# Returns
- `df::DataFrame`: Summary DataFrame including the index columns and values from the original
    `df`, marked to indicate which input DataFrame they came from, the `reldiff` between
    the values, and booleans `equal_key` (are values for the index present in both DataFrames?)
    and `equal_value` (are the values the same within the given `tol`?)
- `d::Dict`: Dictionary of summary DataFrames
"""
function compare_summary(
    df::Array{DataFrame,1},
    indicator::Array{Symbol,1};
    tol::Float64 = DEFAULT_TOL,
    complete_summary::Bool = false
    )

    rel = length(df) == 1 ? :reldiff : :maxreldiff

    # Do some checks on the indices before comparing.
    idx = findindex.(df)
    length(unique(sort.(idx))) > 1 && @error("Cannot compare DataFrames with different indices.")
    length(unique(idx)) > 1 && @warn("Comparing DataFrames with different index orders.")

    df = indexjoin(df; indicator = [:slide,:bluenote], mark_source = true, fillmissing = false)
    idx = findindex(df)
    val = setdiff(findvalue(df), indicator)

    # Are all of the keys here?
    df[!,:equal_keys] .= prod.(eachrow(df[:,indicator]))

    if !isempty(val)
        # Are there discrepancies between PRESENT values (within the specified tolerance)?
        # All values in a row x will be considered "equal" if (max(x) - x_i) / mean(x) < tol
        df_comp = abs.(df[:,val])
        df_comp = (maximum.(skipmissing.(eachrow(df_comp))) .- df_comp) ./
            Statistics.mean.(skipmissing.(eachrow(df_comp)))

        df[!,rel] .= maximum.(skipmissing.(eachrow(df_comp)))
        df[!,:equal_values] .= df[:,rel] .<= tol

        # What if some zeros were include but not others?
        # df[all.(eachrow(.|(ismissing.(df[:,val]), df[:,val].==0))), :equal_values] .= true
        select!(df, [idx; val; indicator; rel; :equal_keys; :equal_values])
        ii = df[:,:equal_keys] .* df[:,:equal_values]
    else
        select!(df, [idx; indicator; :equal_keys])
        ii = df[:,:equal_keys]
    end

    !complete_summary && (df = df[.!ii,:])
    return df
end

function compare_summary(
    d::Array{Dict{Symbol,DataFrame},1},
    indicator::Array{Symbol,1};
    tol::Float64=SLiDE.DEFAULT_TOL,
    complete_summary::Bool=false
)
    keys_comp = intersect(collect.(keys.(d))...)
    d = Dict(k => compare_summary([d[m][k] for m in keys(d)], indicator;
        tol=tol, complete_summary=complete_summary) for k in keys_comp)
    return d
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
function compare_values(df_lst::Array{DataFrame,1}, inds::Array{Symbol,1}; tol = DEFAULT_TOL)
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


"""
    benchmark_against(d_summ::Dict, k::Symbol, d_bench::Dict, d_calc::Dict;
"""
function benchmark_against(
    df_calc::DataFrame,
    df_bench::DataFrame;
    key = missing,
    tol = DEFAULT_TOL,
    small = DEFAULT_SMALL)

    # Remove very small numbers. These might be zero or missing in the other DataFrame,
    # and we're not splitting hairs here.
    if small !== missing
        df_calc = df_calc[abs.(df_calc[:,:value] .> small), :]
        df_bench = df_bench[abs.(df_bench[:,:value] .> small), :]
    end

    (key !== missing) && println("  Comparing keys and values for ", key)

    df_comp = compare_summary([df_calc, df_bench], [:calc,:bench]; tol = tol)
    key == :utd && (df_comp = edit_with(df_comp, Drop(:yr,2002,"<")))

    # If the dataframes are in agreement, store this value as "true".
    # Otherwise, store the comparison dataframe rows that are not in agreement.
    return size(df_comp,1) == 0 ? true : df_comp
end


function benchmark_against(calc::Dict, bench::Dict; tol = DEFAULT_TOL, small = DEFAULT_SMALL)
    keys_comp = intersect(keys(calc), keys(bench))
    
    if length(keys_comp) == 0
        @warn("Cannot compare Dictionaries that share no common keys.")
        return
    end

    return Dict(k => benchmark_against(calc[k], bench[k]; key = k, tol = tol) for k in keys_comp)
end


"""
    verify_over(df::DataFrame, col::Any; tol = 1E-6)
"""
function verify_over(df::DataFrame, col::Any; tol = DEFAULT_TOL)
    df = combine_over(df, col)
    df = df[(df[:,:value] .- 1.0) .> tol, :]
    return size(df,1) == 0 ? true : df
end