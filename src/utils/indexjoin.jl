"""
    indexjoin(df::DataFrame...; kwargs)
    indexjoin(df::Array{DataFrame,1}; kwargs)

This function joins input DataFrames on their index columns (ones that are not filled with 
`AbstractFloat` or `Bool` DataTypes)

# Argument
- `df::DataFrame...` to join.
"""
function indexjoin(df::Array{DataFrame,1};
    id::Array=[],
    indicator::Bool=false,
    fillmissing=0.0,
    skipindex=[],
    kind=:outer,
)
    df = copy.(df[.!isempty.(df)])
    N = length(df)

    # all(length.(findvalue.(df)) .== 0) && (indicator = true)

    (df, id) = _make_unique(df, id, indicator; skipindex=skipindex)
    (df, id) = _add_indicator(df, id, indicator)
    idx = findindex.(df)
    
    df_ans = copy(df[1])
    for ii in 2:N
        cols = intersect(propertynames(df_ans), idx[ii])
        df_ans = if length(cols) == 0
            crossjoin(df_ans, df[ii])
        else
            if kind == :outer;     outerjoin(df_ans, df[ii], on=cols)
            elseif kind == :inner; innerjoin(df_ans, df[ii], on=cols)
            elseif kind == :left;  leftjoin(df_ans, df[ii],  on=cols)
            elseif kind == :right; rightjoin(df_ans, df[ii], on=cols)
            end
        end
    end

    df_ans = _fill_missing(df_ans, fillmissing)
    col = [findindex(df_ans); find_oftype(df_ans, AbstractFloat); find_oftype(df_ans, Bool)]
    return select(df_ans, col)
end


function indexjoin(df::Vararg{DataFrame};
    id::Array=[],
    indicator::Bool=false,
    fillmissing=0.0,
    skipindex=[],
    kind=:outer
)
    return indexjoin(ensurearray(df);
        id=id,
        indicator=indicator,
        fillmissing=fillmissing,
        skipindex=skipindex,
        kind=kind)
end


"""
"""
function convertjoin(df::Array{DataFrame,1}; id=[])
    return indexjoin(df; id=id, indicator=false, fillmissing=1.0, skipindex=:units, kind=:left)
end


convertjoin(df::Vararg{DataFrame}; id=[]) = convertjoin(ensurearray(df); id=id)


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
function _make_unique(df::Array{DataFrame,1}, id::AbstractArray, indicator::Bool; skipindex=[])
    N = length(df)

    col = propertynames.(df)
    val = findvalue.(df)
    flt = find_oftype.(df, AbstractFloat)

    # If there are no values, don't make any changes.
    all(length.(val) .== 0) && (return df, id)
    
    isempty(id) && (id = _generate_id(N))

    # If all value names are already unique, don't edit these.
    # !!!! What if they're already unique but there's an indicator?
    if length(unique([val...;])) == length([val...;])
        from = fill([], (N,))
        to = fill([], (N,))
    else
        from = val
        # If there is only one value column / input dataframe, we are NOT including an
        # indicator, and ids are defined, rename that one value column to match the given id.
        to = if (all(length.(val) .== 1) && !indicator)
            ensurearray.(id)
        else
            broadcast.(append, val, id)
        end
    end
        
    # Remove indicies to be skipped.
    for ii in 1:N
        for idx in intersect(ensurearray(skipindex), col[ii])
            from[ii] = push!(copy(from[ii]), idx)
            to[ii] = push!(copy(to[ii]), append(idx, id[ii]))
        end
    end

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
    return (df, id)
end


"""
"""
function _fill_missing(df::DataFrame, fillmissing)
    # Do we even want to fill missing values?
    fillmissing === false && (return df)
    fillmissing === true  && (fillmissing = 0.0)

    # Are there missing values to fill?
    dfmiss = df[:,any.(eachcol(ismissing.(df)))]
    isempty(dfmiss) && (return df)
    
    # Replace values.
    bool = find_oftype(dfmiss, Bool)
    num = find_oftype(dfmiss, AbstractFloat)
    
    # Fill missing strings.
    str = findindex(dfmiss)
    str_unique = unique.(skipmissing.(eachcol(df[:,str])));
    ii = length.(str_unique) .== 1

    !isempty(bool) && (df = edit_with(df, Replace.(bool, missing, false)))
    !isempty(num)  && (df = edit_with(df, Replace.(num, missing, fillmissing)))
    any(ii)        && (df = edit_with(df, Replace.(str[ii], missing, [str_unique[ii]...;])))
    return df
end


_fill_missing(df::DataFrame) = _fill_missing(df, 0.0)