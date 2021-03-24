using SLiDE
using DataFrames
include(joinpath(SLIDE_DIR,"dev","ee_module","calibrate","setup.jl"))

calib = Model(optimizer_with_attributes(Ipopt.Optimizer, "max_cpu_time" => 60.0))

# ----- INITIALIZE VARIABLES -----------------------------------------------------------
@variables(calib, begin
    # production
    ys0[r in R, s in S, g in G], (start=d[:ys0][r,s,g], lower_bound=lb*d[:ys0][r,s,g])
    id0[r in R, s in G, g in S], (start=d[:id0][r,g,s], lower_bound=lb*d[:id0][r,g,s])
    ld0[r in R, s in S], (start=d[:ld0][r,s], lower_bound=0)
    kd0[r in R, s in S], (start=d[:kd0][r,s], lower_bound=0)
    # trade
    a0[r in R, g in G],  (start=d[:a0 ][r,g], lower_bound=lb*d[:a0 ][r,g])
    nd0[r in R, g in G], (start=d[:nd0][r,g], lower_bound=lb*d[:nd0][r,g])
    dd0[r in R, g in G], (start=d[:dd0][r,g], lower_bound=lb*d[:dd0][r,g])
    m0[r in R, g in G],  (start=d[:m0 ][r,g], lower_bound=lb*d[:m0 ][r,g])
    # supply
    s0[r in R, g in G],  (start=d[:s0 ][r,g], lower_bound=lb*d[:s0 ][r,g])
    xd0[r in R, g in G], (start=d[:xd0][r,g], lower_bound=lb*d[:xd0][r,g])
    xn0[r in R, g in G], (start=d[:xn0][r,g], lower_bound=lb*d[:xn0][r,g])
    x0[r in R, g in G],  (start=d[:x0 ][r,g], lower_bound=lb*d[:x0 ][r,g])
    rx0[r in R, g in G], (start=d[:rx0][r,g], lower_bound=lb*d[:rx0][r,g])
    # demand
    yh0[r in R, g in G], (start=d[:yh0][r,g], lower_bound=0)
    cd0[r in R, g in G], (start=d[:cd0][r,g], lower_bound=0)
    i0[r in R, g in G],  (start=d[:i0 ][r,g], lower_bound=lb*d[:i0 ][r,g], upper_bound=ub*d[:i0][r,g])
    g0[r in R, g in G] , (start=d[:g0 ][r,g], lower_bound=lb*d[:g0 ][r,g])
    # margin
    nm0[r in R, g in G, m in M], (start=d[:nm0][r,g,m], lower_bound=lb*d[:nm0][r,g,m])
    dm0[r in R, g in G, m in M], (start=d[:dm0][r,g,m], lower_bound=lb*d[:dm0][r,g,m])
    md0[r in R, m in M, g in G], (start=d[:md0][r,m,g], lower_bound=lb*d[:md0][r,m,g])
    # balance of payments
    bopdef0[r in R] >= 0, (start=d[:bopdef0][r])
end)

# --- DEFINE CONSTRAINTS ---------------------------------------------------------------

# Zero profit conditions
@constraints(calib, begin
    PROFIT_Y[r in R, s in S], (
        (1 - d[:ty0][r,s]) * sum(ys0[r,s,g] for g in G) ==
        ld0[r,s] + kd0[r,s] + sum(id0[r,g,s] for g in G)
    )
    PROFIT_A[r in R, g in G], (
        (1 - d[:ta0][r,g])*a0[r,g] + rx0[r,g] ==
        (1 + d[:tm0][r,g])*m0[r,g] + nd0[r,g] + dd0[r,g] + sum(md0[r,m,g] for m in M)
    )
    PROFIT_X[r in R, g in G], s0[r,g] + rx0[r,g] == x0[r,g] + xn0[r,g] + xd0[r,g]
    PROFIT_MS[r in R, m in M], sum(nm0[r,s,m] + dm0[r,s,m] for s in S) == sum(md0[r,m,g] for g in G)
end)

# Market clearing conditions
@constraints(calib, begin
    MARKET_PY[r in R, g in G], s0[r,g] == sum(ys0[r,s,g] for s in S) + yh0[r,g]
    MARKET_PA[r in R, g in G], a0[r,g] == sum(id0[r,g,s] for s in S) + cd0[r,g] + g0[r,g] + i0[r,g]
    MARKET_PD[r in R, g in G], xd0[r,g] == sum(dm0[r,g,m] for m in M) + dd0[r,g]
    MARKET_PN[g in G], sum(xn0[r,g] for r in R) == sum(nm0[r,g,m] for (r,m) in set[:r,:m])
    MARKET_PFX, (
        sum(m0[r,g] for (r,g) in set[:r,:g]) ==
        sum(bopdef0[r] + d[:hhadj][r] for r in R) + sum(x0[r,g] for (r,g) in set[:r,:g])
    )
end)

# Gross exports > re-exports
@constraint(calib, EXPDEF[r in R, g in G], x0[r,g] >= rx0[r,g])

# Income balance
@constraint(calib, INCBAL[r in R],
    sum(cd0[r,g] + g0[r,g] + i0[r,g] for g in G) ==
    sum(yh0[r,g] + bopdef0[r] + d[:hhadj][r] for g in G)
    + sum(ld0[r,s]+kd0[r,s] for s in S)
    + sum(d[:ta0][r,g]*a0[r,g] + d[:tm0][r,g]*m0[r,g] for g in G)
    + sum(d[:ty0][r,s] * sum(ys0[r,s,g] for g in G) for s in S)
)

# Value share conditions
@constraints(calib, begin
    LVSHR[r in R, s in S], ld0[r,s] >= 0.5*d[:fvs_ld0][r,s] * sum(ys0[r,s,g] for g in G)
    KVSHR[r in R, s in S], kd0[r,s] >= 0.5*d[:fvs_kd0][r,s] * sum(ys0[r,s,g] for g in G)
end)

# Net generation of electricity balancing
@constraints(calib, begin
    NETGEN_GPOS[r in R; d[:netgen][r] > 0], nd0[r,"ele"] - xn0[r,"ele"] >= 0.8*d[:netgen][r]
    NETGEN_LPOS[r in R; d[:netgen][r] > 0], nd0[r,"ele"] - xn0[r,"ele"] <= 1.2*d[:netgen][r]
    NETGEN_LNEG[r in R; d[:netgen][r] < 0], nd0[r,"ele"] - xn0[r,"ele"] <= 0.8*d[:netgen][r]
    NETGEN_GNEG[r in R; d[:netgen][r] < 0], nd0[r,"ele"] - xn0[r,"ele"] >= 1.2*d[:netgen][r]
end)

# Verify regional totals equal national totals.
@constraints(calib, begin
    NATIONAL_X0[s in SNAT], sum(x0[r,s] for r in R) == d[:x0_nat][s]
    NATIONAL_M0[s in SNAT], sum(m0[r,s] for r in R) == d[:m0_nat][s]
    NATIONAL_VA0[s in SNAT], sum(ld0[r,s] + kd0[r,s] for r in R) == d[:va0_nat][s]
    NATIONAL_G0[s in SNAT], sum(g0[r,s] for r in R) == d[:g0_nat][s]
    NATIONAL_I0[s in SNAT], sum(i0[r,s] for r in R) == d[:i0_nat][s]
    NATIONAL_C0[s in SNAT], sum(cd0[r,s] for r in R) == d[:cd0_nat][s]
end)

# --- DEFINE OBJECTIVE -----------------------------------------------------------------
@objective(calib, Min,
    # production
    + sum(abs(d[:ys0][r,s,g]) * (ys0[r,s,g]/d[:ys0][r,s,g] - 1)^2 for (r,s,g) in set[:r,:s,:g] if d[:ys0][r,s,g] != 0)
    + sum(abs(d[:id0][r,g,s]) * (id0[r,g,s]/d[:id0][r,g,s] - 1)^2 for (r,g,s) in set[:r,:g,:s] if d[:id0][r,g,s] != 0)
    + sum(abs(d[:ld0][r,s]) * (ld0[r,s]/d[:ld0][r,s] - 1)^2 for (r,s) in set[:r,:s] if d[:ld0][r,s] != 0)
    + sum(abs(d[:kd0][r,s]) * (kd0[r,s]/d[:kd0][r,s] - 1)^2 for (r,s) in set[:r,:s] if d[:kd0][r,s] != 0)
    # trade
    + sum(abs(d[:a0][r,g])  * (a0[r,g] /d[:a0][r,g]  - 1)^2 for (r,g) in set[:r,:g] if d[:a0][r,g]  != 0)
    + sum(abs(d[:nd0][r,g]) * (nd0[r,g]/d[:nd0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:nd0][r,g] != 0)
    + sum(abs(d[:dd0][r,g]) * (dd0[r,g]/d[:dd0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:dd0][r,g] != 0)
    + sum(abs(d[:m0][r,g])  * (m0[r,g] /d[:m0][r,g]  - 1)^2 for (r,g) in set[:r,:g] if d[:m0][r,g]  != 0)
    # supply
    + sum(abs(d[:s0][r,g])  * (s0[r,g] /d[:s0][r,g]  - 1)^2 for (r,g) in set[:r,:g] if d[:s0][r,g]  != 0)
    + sum(abs(d[:xd0][r,g]) * (xd0[r,g]/d[:xd0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:xd0][r,g] != 0)
    + sum(abs(d[:xn0][r,g]) * (xn0[r,g]/d[:xn0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:xn0][r,g] != 0)
    + sum(abs(d[:x0][r,g])  * (x0[r,g] /d[:x0][r,g]  - 1)^2 for (r,g) in set[:r,:g] if d[:x0][r,g]  != 0)
    + sum(abs(d[:rx0][r,g]) * (rx0[r,g]/d[:rx0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:rx0][r,g] != 0)
    # demand
    + sum(abs(d[:yh0][r,g]) * (yh0[r,g]/d[:yh0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:yh0][r,g] != 0)
    + sum(abs(d[:cd0][r,g]) * (cd0[r,g]/d[:cd0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:cd0][r,g] != 0)
    + sum(abs(d[:i0][r,g])  * (i0[r,g] /d[:i0][r,g]  - 1)^2 for (r,g) in set[:r,:g] if d[:i0][r,g]  != 0)
    + sum(abs(d[:g0][r,g])  * (g0[r,g] /d[:g0][r,g]  - 1)^2 for (r,g) in set[:r,:g] if d[:g0][r,g]  != 0)
    + sum(abs(d[:bopdef0][r]) * (bopdef0[r]/d[:bopdef0][r] - 1)^2 for r in R if d[:bopdef0][r] != 0)
    # margin
    + sum(abs(d[:nm0][r,g,m]) * (nm0[r,g,m]/d[:nm0][r,g,m] - 1)^2 for (r,g,m) in set[:r,:g,:m] if d[:nm0][r,g,m] != 0)
    + sum(abs(d[:dm0][r,g,m]) * (dm0[r,g,m]/d[:dm0][r,g,m] - 1)^2 for (r,g,m) in set[:r,:g,:m] if d[:dm0][r,g,m] != 0)
    + sum(abs(d[:md0][r,m,g]) * (md0[r,m,g]/d[:md0][r,m,g] - 1)^2 for (r,m,g) in set[:r,:m,:g] if d[:md0][r,m,g] != 0)
+ penalty_nokey * (
    # production
    + sum(ys0[r,s,g] for (r,s,g) in set[:r,:s,:g] if d[:ys0][r,s,g] == 0)
    + sum(id0[r,g,s] for (r,g,s) in set[:r,:g,:s] if d[:id0][r,g,s] == 0)
    + sum(ld0[r,s] for (r,s) in set[:r,:s] if d[:ld0][r,s] == 0)
    + sum(kd0[r,s] for (r,s) in set[:r,:s] if d[:kd0][r,s] == 0)
    # trade
    + sum(a0[r,g]  for (r,g) in set[:r,:g] if d[:a0][r,g]  == 0)
    + sum(nd0[r,g] for (r,g) in set[:r,:g] if d[:nd0][r,g] == 0)
    + sum(dd0[r,g] for (r,g) in set[:r,:g] if d[:dd0][r,g] == 0)
    + sum(m0[r,g]  for (r,g) in set[:r,:g] if d[:m0][r,g]  == 0)
    # supply
    + sum(s0[r,g]  for (r,g) in set[:r,:g] if d[:s0][r,g]  == 0)
    + sum(xd0[r,g] for (r,g) in set[:r,:g] if d[:xd0][r,g] == 0)
    + sum(xn0[r,g] for (r,g) in set[:r,:g] if d[:xn0][r,g] == 0)
    + sum(x0[r,g]  for (r,g) in set[:r,:g] if d[:x0][r,g]  == 0)
    + sum(rx0[r,g] for (r,g) in set[:r,:g] if d[:rx0][r,g] == 0)
    # demand
    + sum(yh0[r,g] for (r,g) in set[:r,:g] if d[:yh0][r,g] == 0)
    + sum(cd0[r,g] for (r,g) in set[:r,:g] if d[:cd0][r,g] == 0)
    + sum(i0[r,g]  for (r,g) in set[:r,:g] if d[:i0][r,g]  == 0)
    + sum(g0[r,g]  for (r,g) in set[:r,:g] if d[:g0][r,g]  == 0)
    # margin
    + sum(nm0[r,g,m] for (r,g,m) in set[:r,:g,:m] if d[:nm0][r,g,m] == 0)
    + sum(dm0[r,g,m] for (r,g,m) in set[:r,:g,:m] if d[:dm0][r,g,m] == 0)
    + sum(md0[r,m,g] for (r,m,g) in set[:r,:m,:g] if d[:md0][r,m,g] == 0)
    )
);

# ----- SET BOUNDS ---------------------------------------------------------------------
# Fix international electricity imports/exports to zero (subject to SEDS data).
[d[:x0][r,"ele"]>0 ? set_lower_bound(x0[r,"ele"], lb_seds*d[:x0][r,"ele"]) : fix(x0[r,"ele"],0,force=true) for r in R]
[d[:m0][r,"ele"]>0 ? set_lower_bound(m0[r,"ele"], lb_seds*d[:m0][r,"ele"]) : fix(m0[r,"ele"],0,force=true) for r in R]

# Adjust upper and lower bounds to allow SEDS data to shift.
[set_lower_bound(cd0[r,e], lb_seds*d[:cd0][r,e]) for (r,e) in set[:r,:e]]
[set_upper_bound(cd0[r,e], ub_seds*d[:cd0][r,e]) for (r,e) in set[:r,:e]]

[set_lower_bound(ys0[r,e,e], lb_seds*d[:ys0][r,e,e]) for (r,e) in set[:r,:e]]
[set_upper_bound(ys0[r,e,e], ub_seds*d[:ys0][r,e,e]) for (r,e) in set[:r,:e]]

[set_lower_bound(id0[r,e,s], lb_seds*d[:id0][r,e,s]) for (r,e,s) in set[:r,:e,:s]]
[set_upper_bound(id0[r,e,s], ub_seds*d[:id0][r,e,s]) for (r,e,s) in set[:r,:e,:s]]

[set_lower_bound(md0[r,m,e], lb_seds*d[:md0][r,m,e]) for (r,m,e) in set[:r,:m,:e]]
[set_upper_bound(md0[r,m,e], ub_seds*d[:md0][r,m,e]) for (r,m,e) in set[:r,:m,:e]]

# --- FIX ZEROS ------------------------------------------------------------------------
# Restrict some parameters to zero.
[fix(ys0[r,e,g], 0, force=true) for (r,e,g) in set[:r,:e,:g] if d[:ys0][r,e,g]==0]
[fix(id0[r,g,e], 0, force=true) for (r,g,e) in set[:r,:g,:e] if d[:id0][r,g,e]==0]

[fix(rx0[r,g], 0, force=true) for (r,g) in set[:r,:g] if d[:rx0][r,g]==0]
[fix(yh0[r,g], 0, force=true) for (r,g) in set[:r,:g] if d[:yh0][r,g]==0]
[fix(nm0[r,g,m], 0, force=true) for (r,g,m) in set[:r,:g,:m] if d[:nm0][r,g,m]==0]
[fix(dm0[r,g,m], 0, force=true) for (r,g,m) in set[:r,:g,:m] if d[:dm0][r,g,m]==0]
[fix(md0[r,m,g], 0, force=true) for (r,m,g) in set[:r,:m,:g] if d[:md0][r,m,g]==0]

# Set electricity imports from the national market to Alaska and Hawaii to zero.
[fix(nd0[r,"ele"], 0, force=true) for r in ["ak","hi"]]
[fix(xn0[r,"ele"], 0, force=true) for r in ["ak","hi"]]

calib_inp = copy(calib)
JuMP.optimize!(calib)