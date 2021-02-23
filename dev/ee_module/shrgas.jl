# df = filter_with(maps[:demand], (s=set[:s],))
df = unique(d[:shrgas],:src)
dfmap = DataFrame(aggr="cng", disagg=["cru","gas"])
col = [:g,:s]

sw(df, dfmap, from::Pair, to::Symbol) = indexjoin(rename(df, from), dfmap)
sw(df, dfmap, from::Symbol, to::Symbol) = indexjoin(df, dfmap)

function sw(df, dfmap)
    from, to = SLiDE._find_scheme(df, dfmap)
    return sw(df, dfmap, from, to)
end

# Do the full dfmap here.
df = sw(df, dfmap)
dfmap = _extend_over(dfmap, set)

# function sw(df, dfmap, from::Symbol, to::Symbol)
#     return indexjoin(df, dfmap)
# end