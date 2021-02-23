bn_id0_avg = antijoin(bn[:inpshrs], bn[:inpshrs_temp], on=[:yr,:r,:g,:s,:sec]; makeunique=true)
bninpshrs = copy(bn[:inpshrs_temp])

set[:ds] = sort(setdiff(maps[:demand][:,:s], maps[:cng][:,:s]))
maps[:e] = DataFrame(g=set[:e], src=set[:e])


xs = set[:ds]
x_idx = [Deselect([:g,:units,:value], "=="); Rename(:src,:g)]

idx_pctgen = edit_with(d[:pctgen][d[:pctgen][:,:value].>0.01, :], x_idx)
idx_ys0 = edit_with(filter_with(d[:ys0], DataFrame(s=x, g=x)), x_idx)
idx_ed0 = edit_with(d[:ed0], x_idx)

idx_id0 = filter_with(innerjoin(idx_pctgen, maps[:demand], on=:sec), (s=x,))
idx_id0_avg = indexjoin(idx_id0, idx_ys0, idx_ed0; kind=:inner)

# Indices to keep:
# idx_pctgen = edit_with(d[:pctgen][d[:pctgen][:,:value].>0.01, 1:end-2], Rename(:src,:g))
# idx_id0 = innerjoin(idx_pctgen, maps[:demand], on=:sec)

# METHOD ONE:
# df = filter_with(copy(d[:id0]), (g=set[:e], s=x))
# df = indexjoin(df, idx_id0; kind=:inner)
# df_id0 = df / transform_over(df, :s; digits=false)

# METHOD TWO:
df = filter_with(copy(d[:id0]), (g=set[:e], s=x))
df = indexjoin(df, maps[:demand]; kind=:inner)

df_sum = transform_over(df, :s; digits=false)

df_id0 = df / df_sum
df_id0 = filter_with(df_id0, idx_id0)

# Calculate average.
idx_id0_avg = antijoin(idx_id0_avg, df_id0,
    on=intersect(propertynames(idx_id0_avg), propertynames(df_id0)))

df_id0_avg = combine_over(df, :r; digits=false) / combine_over(df_sum, :r; digits=false)
df_id0_avg = indexjoin(idx_id0_avg, df_id0_avg; kind=:inner)







# 
# idx_id0_avg = antijoin(idx_id0, df_id0)


# df_id0_avg, df_id0 = split_with(df_id0_tmp, DataFrame(value=NaN))

# df

# df_id0_tmp = df / transform_over(indexjoin(df, idx_id0; kind=:inner), :s; digits=false)

# df_id0


# # Sum id0:
# d[:id0_sum] = sort(combine_over(innerjoin(df, maps[:demand], on=:s), :s; digits=false))

# df_sum = sort(transform_over(innerjoin(df, maps[:demand], on=:s), :s; digits=false))
# df_ans = df / df_sum

# # df_mean = sort(transform_over(innerjoin(df, maps[:demand], on=:s), :s; fun=Statistics.mean, digits=false))

# # col = [:yr,:r,:g,:s,:sec,:value]
# # sort!(select!(df_ans, col))

# # idx_ys0 = filter_with(d[:ys0], (s=set[:ds], g=set[:ds]))[:,1:4]

# # df_sum = transform_over(innerjoin(df, maps[:demand], on=:s), :s; digits=false)
# # df_ans = df / df_sum


# # sort!(select!(df_sum, col))