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

    # dfavg = indexjoin(condition, dfavg; kind=kind)
    return indexjoin(condition, dfavg; kind=kind)
end

# # --------------------------------------------------------------
# # shrgas
# # df = copy(d[:prodval])
# # df = df / transform_over(df, :src)
# # col = :r

# # # dfweight = 
# # condition = crossjoin(
# #     filter_with(combine_over(d[:ys0], :g), (s="cng",); drop=true)[:,1:end-1],
# #     DataFrame(src=unique(df[:,:src])),
# # )

# # df = impute_mean(df, col; condition=condition)

# # df = df / combine_over(df, :src)
# # df = select(df, Not(:units))


# # --------------------------------------------------------------
# var = :pq
# val = [:units,:value]

# splitter = DataFrame(permute((src=[set[:ff];"ele"], sec=set[:demsec], pq=["p","q"])))
# splitter = indexjoin(splitter, maps[:pq]; kind=:left)
# idx = [:yr,:r,:src]

# df, df_out = split_with(copy(d[:energy]), splitter);

# # p, q = split_with(df, (pq="p",); drop=true)

# # df[!,:pq] .= df[:,:p] .* df[:,:q]
# # pedef = combine_over(df,:sec)
# # pedef[!,:value] .= pedef[:,:pq] ./ pedef[:,:q]
# # pedef[!,:units] .= pedef[:,:units_p]

# # idx = intersect(findindex(pedef), propertynames(df_out))

# # --------------------------------------------------------------
