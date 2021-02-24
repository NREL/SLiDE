writeset(df) = replace(string(findindex(df))[2:end-1], " "=>"")
writeidx(df) = replace(writeset(df), ":"=>"")

s = Dict(k => (set=writeset(df), idx=writeidx(df), var=uppercase(string(k)[1:end-1])) for (k,df) in d)
s[:a0]  = (set=writeset(d[:a0]), idx=writeidx(d[:a0]),  var="ARM")
s[:m0]  = (set=writeset(d[:m0]), idx=writeidx(d[:a0]),  var="IMP")
s[:s0]  = (set=writeset(d[:s0]), idx=writeidx(d[:s0]),  var="SUP")
s[:x0]  = (set=writeset(d[:x0]), idx=writeidx(d[:x0]),  var="XPT")
s[:md0] = (set=writeset(d[:md0]),idx=writeidx(d[:md0]), var="MARD")
s[:i0]  = (set=writeset(d[:i0]), idx=writeidx(d[:i0]),  var="INV")
s[:g0]  = (set=writeset(d[:g0]), idx=writeidx(d[:g0]),  var="GD")
s[:bopdef0] = (set=writeset(d[:bopdef0]), idx=writeidx(d[:bopdef0]), var="BOP")

lst = [:ys0,:id0,:ld0,:kd0,:a0,:nd0,:dd0,:m0,:s0,:xd0,:xn0,:x0,:rx0,:nm0,:dm0,:md0,:yh0,:cd0,:i0,:g0,:bopdef0]

# [println("+ sum(abs(d[:$K][$IDX]) * ($VAR[$IDX]/d[:$K][$IDX] - 1)^2 for ($IDX) in set[$SET] if d[:$K][$IDX] != 0)")
#     for (K,SET,IDX,VAR) in zip(keys(s), getindex.(values(s),1), getindex.(values(s),2), getindex.(values(s),3))]
# [println("+ sum($VAR[$IDX] for ($IDX) in set[$SET] if d[:$K][$IDX] == 0)")
#     for (K,SET,IDX,VAR) in zip(keys(s), getindex.(values(s),1), getindex.(values(s),2), getindex.(values(s),3))]

s_set_start = Dict(K => string("[set_start_value($VAR[$IDX], d[:$K][$SET]) for ($IDX) in set[$SET]]")
    for (K,SET,IDX,VAR) in zip(keys(s), getindex.(values(s),1), getindex.(values(s),2), getindex.(values(s),3)))
[println(s_set_start[k]) for k in lst]

s_lower_bound = Dict(K => string("[set_lower_bound($VAR[$IDX], max(0, lb * d[:$K][$SET])) for ($IDX) in set[$SET]]")
    for (K,SET,IDX,VAR) in zip(keys(s), getindex.(values(s),1), getindex.(values(s),2), getindex.(values(s),3)))
[println(s_lower_bound[k]) for k in lst]

s_upper_bound = Dict(K => string("[set_upper_bound($VAR[$IDX], abs(ub * d[:$K][$SET])) for ($IDX) in set[$SET]]")
    for (K,SET,IDX,VAR) in zip(keys(s), getindex.(values(s),1), getindex.(values(s),2), getindex.(values(s),3)))
[println(s_upper_bound[k]) for k in lst]

# K=:ys0
# V=s[K]
# IDX=V.idx
# SET=V.set
# VAR=V.var

# # Test:
# println("sum(abs(d[:$K][$IDX]) * ($VAR[$IDX]/d[:$K][$IDX] - 1)^2 for ($IDX) in set[$SET] if d[:$K][$IDX] != 0)")
# sum(abs(d[:ys0][s,g]) * (YS[s,g] / d[:ys0][s,g] - 1)^2 for (j,i) in set[:s,:g] if d[:ys0][s,g] != 0)
# sum(abs(d[:ys0][s,g]) * (YS[s,g] / d[:ys0][s,g] - 1)^2 for (s,g) in set[:s,:g] if d[:ys0][s,g] != 0)

# println("sum($VAR[$IDX] for ($IDX) in set[$SET] if d[:$K][$IDX] == 0)")
# # sum(YS[s,g] for (s,g) in set[:s,:g] if d[:ys0][s,g] == 0)
# # sum(YS[s,g] for (s,g) in set[:s,:g] if d[:ys0][s,g] == 0)


# println("[set_start_value($VAR[$IDX], d[:$K][$SET]) for ($IDX) in set[$SET]]")
# # [set_start_value(YS[r,s,g], d[:ys0][:r,:s,:g]) for (r,s,g) in set[:r,:s,:g]]
# # [set_start_value(ys[j,i], d[:ys0][s,g]) for (s,g) in set[:s,:g]]

# println("[set_lower_bound($VAR[$IDX], max(0, lb * d[:$K][$SET])) for ($IDX) in set[$SET]]")
# [set_lower_bound(YS[r,s,g], max(0, lb*d[:ys0][:r,:s,:g])) for (r,s,g) in set[:r,:s,:g]]
# [set_lower_bound(YS[s,g], max(0, lb * d[:ys0][s,g])) for (s,g) in set[:s,:g]]

# println("[set_upper_bound($VAR[$IDX], abs(ub * d[:$K][$SET])) for ($IDX) in set[$SET]]")
# [set_upper_bound(YS[r,s,g], abs(ub * d[:ys0][:r,:s,:g])) for (r,s,g) in set[:r,:s,:g]]
# [set_upper_bound(YS[s,g], abs(ub * d[:ys0][s,g]))  for (s,g)  in set[:s,:g]]