"""
    indexjoin(df::DataFrame...; kwargs)
    indexjoin(df::Array{DataFrame,1}; kwargs)

This function joins input DataFrames on their index columns (ones that are not filled with 
`AbstractFloat` or `Bool` DataTypes)

# Argument
- `df::DataFrame...` to join.
"""
function indexjoin(df::Array{DataFrame,1};
    id::Array = [],
    indicator::Bool = false,
    fillmissing = 0.0
)

    df = copy.(df[.!isempty.(df)])
    N = length(df)

    # all(length.(findvalue.(df)) .== 0) && (indicator = true)

    (df,id) = _make_unique(df, id, indicator)
    (df,id) = _add_indicator(df, id, indicator)
    idx = findindex.(df)
    
    df_ans = copy(df[1])
    for ii in 2:N
        cols = intersect(propertynames(df_ans), idx[ii])
        df_ans = if length(cols) == 0
            crossjoin(df_ans, df[ii])
        else
            outerjoin(df_ans, df[ii], on=cols)
        end
    end

    df_ans = _fill_missing(df_ans, fillmissing)
    col = [findindex(df_ans); find_oftype(df_ans, AbstractFloat); find_oftype(df_ans, Bool)]
    return select(df_ans, col)
end


function indexjoin(df::Vararg{DataFrame};
    id::Array = [],
    indicator::Bool = false,
    fillmissing = 0.0
    )
    return indexjoin(ensurearray(df);
        id = id, indicator = indicator, fillmissing = fillmissing)
end


"""
This function appends duplicate input value columns with the associated `id` to
track which column was associated with which input DataFrame.

Notes:
1. If each input DataFrame has only one value column and an indicator is NOT required,
    rename this to match the id.
2. If any of the input DataFrames contains the column `units`, `id` this, as well.
    This means that no joins are performed on unit columns to allow for operations that may
    convert between units.
"""
function _make_unique(df::Array{DataFrame,1}, id::Array, indicator::Bool)
    # (!!!!) do we want to keep units in the index or not?
    # Dropping causes problems when benchmarking SEDS.
    N = length(df)

    col = propertynames.(df)
    val = findvalue.(df)
    flt = find_oftype.(df, AbstractFloat)

    # If there are no values, don't make any changes.
    all(length.(val) .== 0) && (return df, id)

    # If all value names are already unique, don't edit these.
    if length(unique([val...;])) == length([val...;])
        from = fill(Array{Symbol,1}[], (N,))
        to = fill(Array{Symbol,1}[], (N,))
    else
        isempty(id) && (id = _generate_id(N))
        from = val
        # If there is only one value column / input dataframe, we are NOT including an
        # indicator, and ids are defined, rename that one value column to match the given id.
        to = if (all(length.(val) .== 1) && !indicator)
            ensurearray.(id)
        else
            broadcast.(append, val, id)
        end
    end
        
    # Determine whether to edit unit names. If there are no float values in any of the input
    # DataFrames, do NOT adjust units. This will prevent editing scaling mapping files
    # (see: MSN). If at least one column has a float, add an id so we can remember where the
    # units came from.
    # if any(.!isempty.(flt))
    #     for ii in 1:N
    #         if :units in col[ii]
    #             push!(from[ii], :units)
    #             push!(to[ii], append(:units, id[ii]))
    #         end
    #     end
    # end

    if any(.!isempty.(from))
        df = [!isempty(from[ii]) ? edit_with(df[ii], Rename.(from[ii], to[ii])) : df[ii]
            for ii in 1:N]
    end
    return df, id
end


"""
If `indicator = true` is specified, add boolean `id` columns to the output DataFrame
indicating which input DataFrame was the source.
"""
function _add_indicator(df::Array{DataFrame,1}, id::Array, indicator::Bool)
    if indicator
        isempty(id) && (id = _generate_id(df))
        df = [edit_with(df[ii], Add(id[ii], true)) for ii in 1:length(df)]
    end
    return (df,id)
end


"""
"""
function _fill_missing(df::DataFrame, fillmissing)
    if fillmissing !== false
        fillmissing == true && (fillmissing = 0.0)
        val_bool = find_oftype(df, Bool)
        val_float = find_oftype(df, AbstractFloat)

        df = edit_with(df, Replace.(val_bool, missing, false))
        df = edit_with(df, Replace.(val_float, missing, fillmissing))
    end
    return df
end


"""
If no id is specified, default to `id = [x1,x2,...,xN]`
where `N` is the length of the input array `x`
"""
_generate_id(N::Int, id::Symbol = :x) = Symbol.(id, 1:N)
_generate_id(x::Array, id::Symbol = :x) = _generate_id(length(x), id)