df = copy(d[:x0])




# function _module_zero_prod!(d::Dict, )

# [d[k] = filter_with(d[k], Not(idx_zero)) for k in [:ld0,:kd0,:ty0,:id0,:s0,:xd0,:xn0,:x0,:rx0]]



# # --------------------------------------------------------------------
# # function _module_inpshr!(d::Dict, set::Dict, maps::Dict)
# x = unique(d[:id0][:,:g])
# x_idx = [Deselect([:g,:units,:value], "=="); Rename(:src,:g)]

# idx_pctgen = edit_with(d[:pctgen][d[:pctgen][:,:value].>0.01, :], x_idx)
# idx_ys0 = edit_with(filter_with(d[:ys0], DataFrame(s=x, g=x)), x_idx)
# idx_ed0 = edit_with(d[:ed0], x_idx)

# idx_shr = filter_with(innerjoin(idx_pctgen, maps[:demand], on=:sec), (s=x,))
# idx_shr_avg = indexjoin(idx_shr, idx_ys0, idx_ed0; kind=:inner)

# # Average over s.
# df = filter_with(copy(d[:id0]), (g=set[:e], s=x))
# df = indexjoin(df, idx_shr; kind=:inner)

# df_sum = transform_over(df, :s; digits=false)

# df_shr = df / df_sum
# # df_shr = filter_with(df_shr, idx_shr)

# # Average over r.
# idx_shr_avg = antijoin(idx_shr_avg, df_shr,
#     on=intersect(propertynames(idx_shr_avg), propertynames(df_shr)))

# df_shr_num = transform_over(df, :r; digits=false)
# df_shr_den = transform_over(df, [:r,:s]; digits=false)

# df_shr_avg = combine_over(df, :r; digits=false) / combine_over(df_sum, :r; digits=false)
# # df_shr_avg = indexjoin(idx_shr_avg, df_shr_avg; kind=:inner)

# # d[:inpshrs] = vcat(df_shr, df_shr_avg)
# # return d[:inpshrs]
# # end