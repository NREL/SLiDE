
df = copy(d[:shrgas])
dfmap = maps[:og]
x = copy(set[:sector])


# For only g or only s.
col = :g

function _find_scheme(df, dfmap::DataFrame)
    idx = findindex(df)
    idxmap = propertynames(dfmap)

    from = intersect(idx, idxmap)[1]
    to = setdiff(idxmap, [from])[1]
    return from, to
end

function _find_scheme(df, set::AbstractArray)
    # Determine which column overlaps completely with the set.
    # We will scale from/to using this scheme.
    col = propertynames(df)
    ii = length.([intersect(set, col) for col in eachcol(df)]) .== SLiDE.nunique(df)

    aggr = propertynames(df)[ii][1]
    disagg = propertynames(df)[.!ii][1]
    return aggr, disagg
end


function _extend_over(df::DataFrame, set::AbstractArray, col::Symbol; add_id=false)
    # Determine which column overlaps completely with the set.
    # We will scale from/to using this scheme.
    from, to = _find_scheme(df, set)
    x = add_id ? Rename.([from;to], SLiDE._add_id.([from;to], col; replace=from)) : Rename(from,col)

    return edit_with(df, x)
end

function _extend_over(df::DataFrame, set::AbstractArray)
    # Determine which column overlaps completely with the set.
    # We will scale from/to using this scheme.
    from, to = _find_scheme(df, set)
    # x = add_id ? Rename.([from;to], SLiDE._add_id.([from;to], col; replace=from)) : Rename(from,col)

    df = leftjoin(DataFrame(from=>set), df, on=from)
    return edit_with(df, Replace(to, missing, "$from value"))
end


function _scale_with(df, dfmap, col::Symbol; add_id=false)
    from, to = _find_scheme(df, dfmap)
    x = add_id ? Rename.([from;to], SLiDE._add_id.([from;to], col; replace=to)) : Rename(to,col)
    return edit_with(_scale_with(df, dfmap), x)
end

_scale_with(df, dfmap) = indexjoin(df, dfmap)


function _scale_extend(df, dfmap, set, col::AbstractArray)
    from, to = _find_scheme(df, dfmap)
    x = Dict(k => Rename.([from;to], SLiDE._add_id.([from;to], k; replace=to)) for k in col)

    df = _scale_with(df, dfmap)
    dfmap = _extend_over(dfmap, set)

    dfout = vcat([crossjoin(edit_with(df, x[col]), edit_with(dfmap, x[rev]))
        for (col, rev) in zip(sort!(col), sort(col; rev=true))]...)
    return dfout
end

# crossjoin(_extend_over(dfmap, df, :g))


# function _scale_extend_over(df, dfmap, x, col::AbstractArray)
    # idx = findindex(df)
    # idxmap = propertynames(dfmap)

    # from = intersect(idx, idxmap)[1]
    # to = setdiff(idxmap, [from])[1]


# end


# from, to = _find_scheme(df, dfmap)

# edit_with(x)


# function _scale_sector_with()






# share_slice(x, d[:og,:s])

# function _



# df_s = indexjoin(df, edit_with(dfmap, Rename.(SLiDE._find_sector(dfmap),col)))

# col = :g
# df_g = indexjoin(df, edit_with(dfmap, Rename.(SLiDE._find_sector(dfmap),col)))

# dfmap_g = share_slice(x, Rename.(SLiDE._find_sector(dfmap),col))

# d[:shrgas,:s] = indexjoin(df, )

col = propertynames(df)
colmap = propertynames(dfmap)
from = intersect(col, colmap)[1]
to = setdiff(colmap, [from])[1]