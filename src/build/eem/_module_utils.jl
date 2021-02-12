# using SLiDE
# using DataFrames
# import CSV


"""
"""
function DataFrames.unstack(df::DataFrame, colkey::Symbol, value::Tuple; fillmissing=0.0)
    colnew = convert_type.(Symbol, unique(df[:,colkey]))
    idx = setdiff(propertynames(df), ensurearray(colkey), ensurearray(value))
    ii0 = length(idx) + 1
    lst = [unstack(df[:,[idx;[colkey,val]]], colkey, val, renamecols=x -> _add_id(x, val))
        for val in value]
    return indexjoin(lst...; fillmissing=fillmissing)
end


"""
"""
function DataFrames.stack(df::DataFrame, id_vars::Tuple)
    from = Dict(k => _with_id(df, k) for k in id_vars)
    to = Dict(k => _remove_id(v, k) for (k, v) in from)
    idx = setdiff(propertynames(df), values(from)...)

    lst = [edit_with(df[:,[idx;from[k]]], [
            Rename.(from[k], to[k]);
            Melt(idx, :key, k);
        ]) for k in keys(from)]

    return indexjoin(lst...)
end


"""
"""
function operate_with(df::DataFrame, conversion::DataFrame; id=[], keepinput::Bool=false)
    # We might do enough unit conversions to make `conversion` a SLiDE constant?
    # If we're specifying some indicator that will tell us which units/values to keep...
    val = findvalue(df)
    utx = findunits(df)
    col = [setdiff(findindex(df), utx); [:units,:value]; utx; val]

    val = _operate_on(df, id, :value)
    utx = _operate_on(df, id, :units)

    !keepinput && (col = setdiff(col, [utx;val]))

    # Join input data and conversion information.
    length(val) < 2 && (conversion = conversion[ismissing.(conversion[:,:operation]),:])
    
    df = leftjoin(df, conversion, on=Pair.(utx, [:from_units,:by_units][1:length(utx)]))
    
    # Calculate the new value, operating only on rows where some operation is defined.
    ii = any.(eachrow(.!ismissing.(df[:,[:factor,:operation]])))

    if !isempty(val)
        operation = unique(df[:,:operation])[1]

        df[!,:value] .= df[:,val[1]]

        df[ii,:value] .= if ismissing(operation)
            df[ii,val[1]] .* df[ii,:factor]
        else
            broadcast.(operation, df[ii,val[1]] .* df[ii,:factor], df[ii,val[2]])
        end
    end

    df = SLiDE.round!(df, :value)

    # Figure out units.
    df[!,:units] .= df[:,utx[1]]
    df[ii,:units] .= df[ii,:to_units]
    return df[:, intersect(col, propertynames(df))]
end


"""
"""
function _operate_on(df::DataFrame, id, val::Symbol)
    lst = (val == :value) ? findvalue(df) : propertynames_with(df, val)
    
    if !isempty(id)
        lst_id = getid.(lst, val)
        lst = vcat([lst[x .== lst_id] for x in id]...)
    end

    return lst
end


"""
"""
split_with(df::DataFrame, splitter::NamedTuple) = split_with(df, DataFrame(permute(splitter)))
# !!!! fill zero here causes issues for value




"""
"""
function index_with(df::DataFrame, splitter)
    idx = findindex(df)
    idx = idx[length.(unique.(eachcol(df[:,idx]))) .> 1]

    df = edit_with(df, Replace.(findvalue(df), [Inf,NaN], 0.0))
    df_in, df_out = split_with(df, splitter)
    return df_in[:,idx], df_out[:,idx]
    # return df_in, df_out
end


"""
"""
function _calc_key(df, col)
    # replace.(v, r"\_|\s" => "")
    df[!,:key] .= append.(ensuretuple.(eachrow(df[:,col])))
    return df
end

_calc_key(df, col::Symbol) = _calc_key(df, ensurearray(col))


"""
"""
function _split_with(df::DataFrame, df_split::DataFrame, key)
    df_split = _calc_key(df_split, key);
    df_in, df_out = split_with(df, df_split)
    df_in = edit_with(df_in, Deselect(setdiff([key;:base], [:key]), "=="))
    df_in = unstack(df_in, :key, (:units, :value))
    return df_in, df_out, df_split
end


"""
"""
function _merge_with(df_in::DataFrame, df_out::DataFrame, df_split::DataFrame)
    df_in = stack(df_in, (:units, :value))
    df_in = indexjoin(df_in, df_split; kind=:left)
    return [dropzero(df_in[:,propertynames(df_out)]); df_out]
end