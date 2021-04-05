# Our project is the largest-scale operation in CGE modeling in Julia/JuMP

"""
"""
function scale_with_share(df::DataFrame, dfmap::DataFrame, on; key=missing)
    if !isempty(ensurearray(on))
        idx = setdiff(intersect(findindex(df), propertynames(dfmap)), on)
        from, to = SLiDE._find_scheme(df, dfmap, on)
        _print_scale_status(from, to; key=key)
        
        # Split the DataFrame based on what needs editing and what doesn't (df_ones).
        # If df maps completely to dfmap, df_ones will be empty.
        df_ones = antijoin(df, unique(dfmap[:,ensurearray(from)]), on=from)
        df = edit_with(df, Map(dfmap, [idx;from], [to;:value], [idx;on], [on;:share], :inner))

        df[!,:value] .= df[:,:value] .* df[:,:share]
        
        df = vcat(df_ones, df; cols=:intersect)
    end

    return df
end


"""
"""
function scale_with_map(df::DataFrame, dfmap::DataFrame, on; key=missing)
    if !isempty(ensurearray(on))
        idx = setdiff(intersect(findindex(df), propertynames(dfmap)), on)
        from, to = SLiDE._find_scheme(select(df,Not(idx)), select(dfmap,Not(idx)))
        SLiDE._print_scale_status(from, to; key=key)

        # Split the DataFrame based on what needs editing and what doesn't (df_ones).
        # If df maps completely to dfmap, df_ones will be empty.
        df_ones = antijoin(df, unique(dfmap[:,ensurearray(from)]), on=from)
        df = edit_with(df, Map(dfmap,[from;],[to;],[on;],[on;],:inner))

        df = vcat(df_ones, df)
    end

    return df
end


"""
# Examples

If given a DataFrame, return a Tuple of DataFrame columns in the order
(aggregate-level, disaggregate-level). This is determined from the number of unique entries
in each column under the assumption that the aggregate-level will have fewer unique entries.

```jldoctest
df = DataFrame(s="cng", src=["cru","gas"])
SLiDE._find_scheme(df)

# output

(:s, :src)
```

If given a DataFrame `df` and a mapping DataFrame `dfmap`, find the columns to map (from,to)
based on the overlap in propertynames. If there is no overlap in propertynames,
look for overlap in values.

```jldoctest
df = DataFrame(s = ["cng", "col", "ele", "oil"], src = ["ind","ind","ele","ref"])
dfmap = DataFrame(aggr="cng", disagg=["cru","gas"])
SLiDE._find_scheme(df, dfmap)

# output

(:s => :aggr, :disagg)
```

If given a DataFrame and a set to scale FROM, return the DataFrame propertynames
that will be scaled (from, to). This is determined from the overlap of `df` with the input
`set`, such that we scale FROM the column that does overlap TO the column that does not.

```jldoctest
df = DataFrame(s="cng", src=["cru","gas"])
set = ["cng", "col", "con", "eint", "ele", "oil", "ommf", "osrv", "roe", "trn"]
SLiDE._find_scheme(df, set)

# output

(:s, :src)
```
"""
function _find_scheme(df::DataFrame)
    # Sort in case there are sets of aggregate- and disaggregate-level information.
    # !!!! Does this (^) ever come up? Should it? Or does it just mess us up?
    col = sort(setdiff(findindex(df), [:yr]))
    # col = findindex(df)
    nn_col = SLiDE.nunique(df[:,col])
    nn_unique = unique(nn_col)

    # If there is only ONE column on each the aggregate and disaggregate level...
    if nn_col == nn_unique
        ii = sortperm(nn_unique)
        agg, dis = col[ii[1]], col[ii[end]]
    else
        scheme = [col[nn_col.==nn] for nn in sort(nn_unique)]
        # agg, dis = sort(scheme[1]), sort(scheme[end])
        agg, dis = scheme[1], scheme[end]
    end
    
    return agg, dis
end


function _find_scheme(df, dfmap::DataFrame)
    idx = setdiff(findindex(df), [:yr])
    idxmap = setdiff(findindex(dfmap), [:yr])

    # from = intersect(idxmap, idx)
    # on = from

    # If there is NO overlap in names, look for overlap in values.
    # !!!! This will might cause weirdness if multiple columns in df map to dfmap,
    # but this shouldn't be too bad to address later.
    # if isempty(from)
        dfmap = dfmap[SLiDE.nunique.(eachrow(dfmap[:,idxmap])).==length(idxmap), idxmap]

        col = unique.(eachcol(df[:,idx]))
        colmap = unique.(skipmissing.(eachcol(dfmap)))
        from = [k => kmap for (k,c) in zip(idx,col) for (kmap,cmap) in zip(idxmap, colmap)
            if !isempty(intersect(cmap,c))]
        # on = getindex.(x,1)
        # from = unique(getindex.(x,2))
        to = setdiff(idxmap, getindex.(from,2))
    # else
    #     to = setdiff(idxmap, from)
    # end

    # Flatten lists.
    if length(from) == 1
        from, to = from[1], to[1]
    end

    # if 

    return from, to
end


function SLiDE._find_scheme(df, dfmap::DataFrame, col)
    idx = setdiff(intersect(findindex(df), propertynames(dfmap)), col)
    from, to = SLiDE._find_scheme(select(df,Not(idx)), select(dfmap,Not(idx)))

    return from, to
end


function _find_scheme(df, x::AbstractArray)
    # Determine which column overlaps completely with the set.
    # We will scale from/to using this scheme.
    col = setdiff(findindex(df), [:yr])

    ii = length.([intersect(x, c) for c in eachcol(df[:,col])]) .== SLiDE.nunique(df[:,col])
    
    if all(ii)
        ii = sortperm(SLiDE.nunique(df[:,col]))
        aggr = col[ii[1]]
        dis = col[ii[end]]
    else
        aggr = col[ii][1]
        dis = col[.!ii][1]
    end

    return aggr, dis
end


"""
"""
function _extend_over(df::DataFrame, set::AbstractArray, col::Symbol; add_id=false)
    # Determine which column overlaps completely with the set.
    # We will scale from/to using this scheme.
    from, to = _find_scheme(df, set)
    x = add_id ? Rename.([from;to], SLiDE._add_id.([from;to], col; replace=from)) : Rename(from,col)

    return edit_with(df, x)
end


function SLiDE._extend_over(df::DataFrame, set::AbstractArray)
    # Determine which column overlaps completely with the set.
    # We will scale from/to using this scheme.
    from, to = SLiDE._find_scheme(df, set)

    val = unique.(eachcol(dropmissing(df)[:,findindex(df)]))
    ii = .!isempty.([intersect(set, v) for v in val])
    xdiff = setdiff(set, vcat(val...))

    colmap = [from;to]
    dfmap = DataFrame(fill(xdiff, length(colmap)), colmap)

    if size(dfmap,2) !== size(df,2)
        idx = setdiff(findindex(df), colmap)
        dfadd = unique(df[:,idx])
        dfadd[!,findvalue(df)[1]] .= 1.0

        dfmap = crossjoin(dfmap, dfadd)
    end

    return vcat(df, dfmap)

    # x = add_id ? Rename.([from;to], SLiDE._add_id.([from;to], col; replace=from)) : Rename(from,col)
    # df = leftjoin(DataFrame(from=>set), df, on=from)
    # return edit_with(df, Replace(to, missing, "$from value"))
end


"""
"""
_scale_with(df, dfmap) = indexjoin(df, dfmap)

function _scale_with(df, dfmap, col::Symbol; add_id=false)
    from, to = _find_scheme(df, dfmap)
    x = add_id ? Rename.([from;to], SLiDE._add_id.([from;to], col; replace=to)) : Rename(to,col)
    return edit_with(_scale_with(df, dfmap), x)
end


"""
"""
_scale_extend(df::DataFrame, dfmap::DataFrame, set::AbstractArray, col::Symbol) = _scale_with(df, dfmap, col)

function _scale_extend(df::DataFrame, dfmap::DataFrame, set::AbstractArray, col::AbstractArray)
    if length(col) == 1
        df = _scale_extend(df, dfmap, set, col[1])
    else
        from, to = _find_scheme(df, dfmap)
        x = Dict(k => Rename.([from;to], SLiDE._add_id.([from;to], k; replace=to)) for k in col)
        
        idxmap = get_to.(vcat(values(x)...))
        
        # Do the full dfmap here.
        df = _scale_with(df, dfmap)
        dfmap = _extend_over(dfmap, set)
        
        df = vcat([crossjoin(edit_with(df, x[col]), edit_with(dfmap, x[rev]))
            for (col, rev) in zip(sort!(col), sort(col; rev=true))]...)
            
        # --------- SEPARATE FUNCTION ------------------------------------------------------
        # In the case that (g,s) is the same  at the summary level, address the following cases:
        #   1. (g,s) are the SAME at the disaggregate level, sum all of the share values.
        #   2. (g,s) are DIFFERENT at the disaggregate level, drop these.
        idx = setdiff(findindex(df), idxmap)
        agg, dis = _find_scheme(df[:,idxmap])
        
        splitter = DataFrame(fill(unique(df[:,agg[1]]), length(col)), col)
        df_same, df_diff = split_with(df, splitter)

        # df_same[!,:value] .= df_same[:,:value] .* SLiDE._find_constant.(eachrow(df_same[:,dis]))
        ii_same = SLiDE._find_constant.(eachrow(df_same[:,dis]))
        df_same = df_same[ii_same,:]
        
        df = select(vcat(df_same, df_diff), [idx;agg;dis;:value])
        # df = vcat(df_same, df_diff)
    end
    return df
end


"""
"""
function _print_scale_status(from, to; key=missing)
    from = _print_list(from)
    to = _print_list(to)

    if ismissing(key); println("  Scaling from -> to")
    else;              println("  Scaling $key: $from -> $to")
    end

    return nothing
end

"""
"""
_print_list(x::AbstractArray) = "(" * string(string.(x,",")...)[1:end-1] * ")"
_print_list(x) = string(x)