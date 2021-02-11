# reporting for loop
#= reporting update for complementarity.jl instead of JuMP.MOI
report = Dict()

function convert_type_mcp(::Type{DataFrame}, arr::JuMP.Containers.DenseAxisArray; cols=[])
    cols = ensurearray(cols)

    val = result_value.(arr.data)
    ind = permute(arr.axes);
    val = collect(Iterators.flatten(val));

    df = hcat(DataFrame(ensuretuple.(ind)), DataFrame([val], [:value]))
    return edit_with(df, Rename.(propertynames(df)[1:length(cols)], cols))
end

report[:YM] = convert_type_mcp(DataFrame, YM; cols=idx[:Y])

for (k,d) in report
    CSV.write("$k.csv",d)
end
=#

vrep = Dict() # Dictionary for variable storage
prep = Dict() # Dictionary for parameter storage

# +++++ Store Variables +++++
# (r,s) in set[:Y]
vrep[:YM] = Dict()
vrep[:YX] = Dict()

# (r,g) in set[:X]
vrep[:X] = Dict()

# (r,g) in set[:A]
vrep[:A] = Dict()

# r in set[:r], m in set[:m]
vrep[:MS] = Dict()
vrep[:PM] = Dict()

# r in set[:r]
vrep[:C] = Dict()
vrep[:INV] = Dict()
vrep[:RA] = Dict()
vrep[:LS] = Dict()
vrep[:Z] = Dict()
vrep[:W] = Dict()

vrep[:RK] = Dict()
vrep[:PC] = Dict()
vrep[:PINV] = Dict()
vrep[:PW] = Dict()
vrep[:PL] = Dict()
vrep[:PLS] = Dict()
vrep[:PZ] = Dict()

# (r,g) in set[:PY]
vrep[:PY] = Dict()

# (r,g) in set[:PA]
vrep[:PA] = Dict()

# (r,g) in set[:PD]
vrep[:PD] = Dict()

# g in set[:g]
vrep[:PN] = Dict()

# (r,s) in set[:PK]
vrep[:RKX] = Dict()
vrep[:DKM] = Dict()

# no index
vrep[:PFX] = Dict()



for (r,s) in set[:Y]
    push!(vrep[:YM], (r,s)=>result_value(YM[(r,s)]))
    push!(vrep[:YX], (r,s)=>result_value(YX[(r,s)]))
end

for (r,g) in set[:X]
    push!(vrep[:X], (r,g)=>result_value(X[(r,g)]))
end

for (r,g) in set[:A]
    push!(vrep[:A], (r,g)=>result_value(A[(r,g)]))
end

for r in set[:r], m in set[:m]
    push!(vrep[:MS], (r,m)=>result_value(MS[r,m]))
    push!(vrep[:PM], (r,m)=>result_value(PM[r,m]))
end

for r in set[:r]
    push!(vrep[:C], (r)=>result_value(C[r]))
    push!(vrep[:INV], (r)=>result_value(INV[r]))
    push!(vrep[:RA], (r)=>result_value(RA[r]))
    push!(vrep[:LS], (r)=>result_value(LS[r]))
    push!(vrep[:Z], (r)=>result_value(Z[r]))
    push!(vrep[:W], (r)=>result_value(W[r]))
    push!(vrep[:PC], (r)=>result_value(PC[r]))
    push!(vrep[:RK], (r)=>result_value(RK[r]))
    push!(vrep[:PINV], (r)=>result_value(PINV[r]))
    push!(vrep[:PLS], (r)=>result_value(PLS[r]))
    push!(vrep[:PL], (r)=>result_value(PL[r]))
    push!(vrep[:PZ], (r)=>result_value(PZ[r]))
    push!(vrep[:PW], (r)=>result_value(PW[r]))
end

for (r,g) in set[:PY]
    push!(vrep[:PY], (r,g)=>result_value(PY[(r,g)]))
end

for (r,g) in set[:PA]
    push!(vrep[:PA], (r,g)=>result_value(PA[(r,g)]))
end

for (r,g) in set[:PD]
    push!(vrep[:PD], (r,g)=>result_value(PD[(r,g)]))
end

for (r,s) in set[:PK]
    push!(vrep[:RKX], (r,s)=>result_value(RKX[(r,s)]))
    push!(vrep[:DKM], (r,s)=>result_value(DKM[(r,s)]))
end

for g in set[:g]
    push!(vrep[:PN], (g)=>result_value(PN[g]))
end

vrep[:PFX] = result_value(PFX)

# +++++ Store Parameters +++++
prep[:ys0] = Dict()
prep[:id0] = Dict()
prep[:ld0] = Dict()
prep[:kd0] = Dict()
prep[:ty0] = Dict()
prep[:m0] = Dict()
prep[:x0] = Dict()
prep[:rx0] = Dict()
prep[:md0] = Dict()
prep[:nm0] = Dict()
prep[:dm0] = Dict()
prep[:s0] = Dict()
prep[:a0] = Dict()
prep[:ta0] = Dict()
prep[:tm0] = Dict()
prep[:cd0] = Dict()
prep[:c0] = Dict()
prep[:yh0] = Dict()
prep[:bopdef0] = Dict()
prep[:hhadj] = Dict()
prep[:g0] = Dict()
prep[:i0] = Dict()
prep[:xn0] = Dict()
prep[:xd0] = Dict()
prep[:dd0] = Dict()
prep[:nd0] = Dict()

prep[:ta] = Dict()
prep[:ty] = Dict()
prep[:tm] = Dict()

prep[:ir] = Dict()
prep[:gr] = Dict()
prep[:dr] = Dict()
prep[:thetax] = Dict()
prep[:ks_n] = Dict()
prep[:ks_s] = Dict()
prep[:ks_m] = Dict()
prep[:ks_x] = Dict()
prep[:inv0] = Dict()
prep[:le0] = Dict()
prep[:lab0] = Dict()
prep[:tl0] = Dict()
prep[:theta_ll] = Dict()
prep[:lte0] = Dict()
prep[:leis0] = Dict()
prep[:z0] = Dict()
prep[:theta_lz] = Dict()
prep[:w0] = Dict()

prep[:alpha_kl] = Dict()
prep[:alpha_x] = Dict()
prep[:alpha_d] = Dict()
prep[:alpha_n] = Dict()
prep[:theta_n] = Dict()
prep[:theta_m] = Dict()
prep[:theta_inv] = Dict()
prep[:theta_cd] = Dict()

prep[:es_va] = Dict()
prep[:es_y] = Dict()
prep[:es_m] = Dict()
prep[:et_x] = Dict()
prep[:es_a] = Dict()
prep[:es_mar] = Dict()
prep[:es_d] = Dict()
prep[:es_f] = Dict()
prep[:es_inv] = Dict()
prep[:es_cd] = Dict()

prep[:ulse] = Dict()
prep[:es_z] = Dict()

prep[:aeeigr] = Dict()
prep[:aeeigrcd] = Dict()
prep[:aeei] = Dict()
prep[:aeeicd] = Dict()

for r in set[:r]
    push!(prep[:c0], (r)=>value(c0[r]))
    push!(prep[:bopdef0], (r)=>value(bopdef0[r]))
    push!(prep[:hhadj], (r)=>value(hhadj[r]))
    push!(prep[:ks_m], (r)=>value(ks_m[r]))
    push!(prep[:inv0], (r)=>value(inv0[r]))
    push!(prep[:lab0], (r)=>value(lab0[r]))
    push!(prep[:tl0], (r)=>value(tl0[r]))
    push!(prep[:lte0], (r)=>value(lte0[r]))
    push!(prep[:leis0], (r)=>value(leis0[r]))
    push!(prep[:z0], (r)=>value(z0[r]))
    push!(prep[:theta_lz], (r)=>value(theta_lz[r]))
    push!(prep[:w0], (r)=>value(w0[r]))
    push!(prep[:es_inv], (r)=>value(es_inv[r]))
    push!(prep[:es_z], (r)=>value(es_z[r]))
    push!(prep[:aeeigrcd], (r)=>value(aeeigrcd[r]))
    push!(prep[:aeeicd], (r)=>value(aeeicd[r]))
end

for r in set[:r], s in set[:s]
    push!(prep[:ld0], (r,s)=>value(ld0[r,s]))
    push!(prep[:kd0], (r,s)=>value(kd0[r,s]))
    push!(prep[:ty0], (r,s)=>value(ty0[r,s]))
    push!(prep[:ty], (r,s)=>value(ty[r,s]))
    push!(prep[:ks_n], (r,s)=>value(ks_n[r,s]))
    push!(prep[:ks_s], (r,s)=>value(ks_s[r,s]))
    push!(prep[:ks_x], (r,s)=>value(ks_x[r,s]))
    push!(prep[:le0], (r,s)=>value(le0[r,s]))
    push!(prep[:alpha_kl], (r,s)=>value(alpha_kl[r,s]))
    push!(prep[:es_va], (r,s)=>value(es_va[r,s]))
    push!(prep[:es_y], (r,s)=>value(es_y[r,s]))
    push!(prep[:es_m], (r,s)=>value(es_m[r,s]))
end

for r in set[:r], g in set[:g]
    push!(prep[:m0], (r,g)=>value(m0[r,g]))
    push!(prep[:x0], (r,g)=>value(x0[r,g]))
    push!(prep[:rx0], (r,g)=>value(rx0[r,g]))
    push!(prep[:s0], (r,g)=>value(s0[r,g]))
    push!(prep[:a0], (r,g)=>value(a0[r,g]))
    push!(prep[:ta0], (r,g)=>value(ta0[r,g]))
    push!(prep[:tm0], (r,g)=>value(tm0[r,g]))
    push!(prep[:cd0], (r,g)=>value(cd0[r,g]))
    push!(prep[:yh0], (r,g)=>value(yh0[r,g]))
    push!(prep[:g0], (r,g)=>value(g0[r,g]))
    push!(prep[:i0], (r,g)=>value(i0[r,g]))
    push!(prep[:xn0], (r,g)=>value(xn0[r,g]))
    push!(prep[:xd0], (r,g)=>value(xd0[r,g]))
    push!(prep[:dd0], (r,g)=>value(dd0[r,g]))
    push!(prep[:nd0], (r,g)=>value(nd0[r,g]))
    push!(prep[:ta], (r,g)=>value(ta[r,g]))
    push!(prep[:tm], (r,g)=>value(tm[r,g]))
    push!(prep[:alpha_x], (r,g)=>value(alpha_x[r,g]))
    push!(prep[:alpha_d], (r,g)=>value(alpha_d[r,g]))
    push!(prep[:alpha_n], (r,g)=>value(alpha_n[r,g]))
    push!(prep[:theta_n], (r,g)=>value(theta_n[r,g]))
    push!(prep[:theta_m], (r,g)=>value(theta_m[r,g]))
    push!(prep[:theta_inv], (r,g)=>value(theta_inv[r,g]))
    push!(prep[:theta_cd], (r,g)=>value(theta_cd[r,g]))
    push!(prep[:et_x], (r,g)=>value(et_x[r,g]))
    push!(prep[:es_a], (r,g)=>value(es_a[r,g]))
    push!(prep[:es_mar], (r,g)=>value(es_mar[r,g]))
    push!(prep[:es_d], (r,g)=>value(es_d[r,g]))
    push!(prep[:es_f], (r,g)=>value(es_f[r,g]))
    push!(prep[:aeeigr], (r,g)=>value(aeeigr[r,g]))
    push!(prep[:aeei], (r,g)=>value(aeei[r,g]))
end


for r in set[:r], s in set[:s], g in set[:g]
    push!(prep[:ys0], (r,s,g)=>value(ys0[r,s,g]))
    push!(prep[:id0], (r,s,g)=>value(id0[r,s,g]))
end

for r in set[:r], g in set[:g], m in set[:m]
    push!(prep[:nm0], (r,g,m)=>value(nm0[r,g,m]))
    push!(prep[:dm0], (r,g,m)=>value(dm0[r,g,m]))
end

for r in set[:r], m in set[:m], g in set[:g]
    push!(prep[:md0], (r,m,g)=>value(md0[r,m,g]))
end

prep[:ir] = value(ir)
prep[:gr] = value(gr)
prep[:dr] = value(dr)
prep[:thetax] = value(thetax)
prep[:theta_ll] = value(theta_ll)
prep[:es_cd] = value(es_cd)
prep[:ulse] = value(ulse)

# +++++ Save data for next loop +++++
using JLD2, FileIO
# save("data.jld2","YM",reportd[:YM])
# load("data.jld2","YM")

@save joinpath(SLIDE_DIR,"model","data_$loopyr.jld2") vrep prep
#@save "data_$bmkyr.jld2" vrep
#@load "data_$bmkyr.jld2" rep
