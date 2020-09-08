
[shr[k] = sort(edit_with(shr[k], Rename(:value,:share))) for k in keys(shr)]
[cal[k] = fill_zero(cal[k]) for k in keys(cal)]

# io[:va0] = unstack(edit_with(io[:va0], Rename(:j,:s)), :va, :value);
shr[:labor] = edit_with(shr[:labor], Rename(:g,:s))

disagg = Dict()

function share_with(df::DataFrame, df_share::DataFrame; on = [:value, :share])
    df_ans = innerjoin(df, df_share, on = intersect(propertynames(df), propertynames(df_share)))
    # df_ans[!,:ans] = prod.(eachrow(df_ans[:,on]))   # SO SLOW.
    df_ans[!,:ans] = df_ans[:,on[1]] .* df_ans[:,on[2]]
    return df_ans[:, intersect([[:yr,:r,:s,:g,:ans]; on], propertynames(df_ans))]
end

# ys0_(yr,r,s,g) = region_shr(yr,r,s) * ys_0(yr,s,g);
# id0_(yr,r,g,s) = region_shr(yr,r,s) * id_0(yr,g,s);
# ty0_rev_(yr,r,s) = region_shr(yr,r,s) * va_0(yr,'othtax',s);
# ty0_(yr,r,s)$sum(g, ys0_(yr,r,s,g)) = ty0_rev_(yr,r,s) / sum(g, ys0_(yr,r,s,g));
# va0_(yr,r,s) = region_shr(yr,r,s) * (va_0(yr,'compen',s) + va_0(yr,'surplus',s));
disagg[:ys0] = share_with(cal[:ys0], shr[:region], on = [:value, :share])
disagg[:id0] = share_with(cal[:id0], shr[:region], on = [:value, :share])
disagg[:ty0_rev] = share_with(io[:va0], shr[:region], on = [:othtax, :share])

io[:va0][!,:value] = io[:va0][:,:compen] + io[:va0][:,:surplus]
disagg[:va0] = share_with(io[:va0], shr[:region], on = [:value, :share])

# * Split aggregate value added based on GSP components:
# ld0_(yr,r,s) = labor_shr(yr,r,s) * va0_(yr,r,s);
# kd0_(yr,r,s) = va0_(yr,r,s) - ld0_(yr,r,s);

disagg[:ld0] = share_with(disagg[:va0], shr[:labor], on = [:value, :share])

# disagg[]
# disagg[:kd0] = disagg[:ld0][:,:value] - disagg[:ld0][:,:ans]

df = copy(disagg[:va0])
df_share = copy(shr[:labor])

df_ans = innerjoin(df, df_share, on = intersect(propertynames(df), propertynames(df_share)))

# disagg[:ld0] = share_with()
# disagg[:ld0] = copy(sort(disagg[:va0]))
# disagg[:ld0][!,:value] .* disagg[:ld0]