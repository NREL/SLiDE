function filter_with(df::DataFrame, set; extrapolate::Bool = false)
    df = copy(df)

    # Find keys that reference both column names in the input DataFrame df and
    # values in the set Dictionary. Then, created a DataFrame containing all permutations.
    cols = find_oftype(df, Not(AbstractFloat))
    cols_set = intersect(cols, collect(keys(set)));
    vals_set = [set[k] for k in cols_set]

    df_set = DataFrame(permute(NamedTuple{Tuple(cols_set,)}(vals_set,)))

    # Save key values that are NOT included in keys. This is relevant in the case that
    # there are multiple types of units in the DataFrame columns.
    df_key = unique(df[:,setdiff(cols, collect(keys(set)))])
    
    # Drop values that are not in the current set.
    df = join(df, df_set, on = cols_set, kind = :inner)
    
    # Fill zeros.
    df_set = edit_with(join(edit_with(df_set, Add(:dummy,1)),
        edit_with(df_key, Add(:dummy,1)), on = :dummy), Drop(:dummy,"all","=="))[:,cols]
    df = fill_zero(df_set, df; permute_keys = false)[2]

    return sort(df)
end