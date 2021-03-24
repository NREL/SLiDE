using SLiDE
using DataFrames
include(joinpath(SLIDE_DIR,"dev","ee_module","calibrate","setup.jl"))

calib = Model(optimizer_with_attributes(Ipopt.Optimizer, "max_cpu_time" => 60.0))

# ----- INITIALIZE VARIABLES -----------------------------------------------------------
@variables(calib, begin
    # production
    YS[r in R, s in S, g in G], (start=d[:ys0][r,s,g], lower_bound=lb*d[:ys0][r,s,g])
    ID[r in R, s in G, g in S], (start=d[:id0][r,g,s], lower_bound=lb*d[:id0][r,g,s])
    LD[r in R, s in S],  (start=d[:ld0][r,s], lower_bound=0)
    KD[r in R, s in S],  (start=d[:kd0][r,s], lower_bound=0)
    # trade
    ARM[r in R, g in G], (start=d[:a0 ][r,g], lower_bound=lb*d[:a0 ][r,g])
    ND[r in R, g in G],  (start=d[:nd0][r,g], lower_bound=lb*d[:nd0][r,g])
    DD[r in R, g in G],  (start=d[:dd0][r,g], lower_bound=lb*d[:dd0][r,g])
    IMP[r in R, g in G], (start=d[:m0 ][r,g], lower_bound=lb*d[:m0 ][r,g])
    # supply
    SUP[r in R, g in G], (start=d[:s0 ][r,g], lower_bound=lb*d[:s0 ][r,g])
    XD[r in R, g in G],  (start=d[:xd0][r,g], lower_bound=lb*d[:xd0][r,g])
    XN[r in R, g in G],  (start=d[:xn0][r,g], lower_bound=lb*d[:xn0][r,g])
    XPT[r in R, g in G], (start=d[:x0 ][r,g], lower_bound=lb*d[:x0 ][r,g])
    RX[r in R, g in G],  (start=d[:rx0][r,g], lower_bound=lb*d[:rx0][r,g])
    # demand
    YH[r in R, g in G],  (start=d[:yh0][r,g], lower_bound=0)
    CD[r in R, g in G],  (start=d[:cd0][r,g], lower_bound=0)
    INV[r in R, g in G], (start=d[:i0 ][r,g], lower_bound=lb*d[:i0 ][r,g], upper_bound=ub*d[:i0][r,g])
    GD[r in R, g in G] , (start=d[:g0 ][r,g], lower_bound=lb*d[:g0 ][r,g])
    # margin
    NM[r in R, g in G, m in M],   (start=d[:nm0][r,g,m], lower_bound=lb*d[:nm0][r,g,m])
    DM[r in R, g in G, m in M],   (start=d[:dm0][r,g,m], lower_bound=lb*d[:dm0][r,g,m])
    MARD[r in R, m in M, g in G], (start=d[:md0][r,m,g], lower_bound=lb*d[:md0][r,m,g])
    # balance of payments
    BOP[r in R] >= 0, (start=d[:bopdef0][r])
end)

# --- DEFINE CONSTRAINTS ---------------------------------------------------------------

# Zero profit conditions
@constraints(calib, begin
    PROFIT_Y[r in R, s in S], (
        (1 - d[:ty0][r,s]) * sum(YS[r,s,g] for g in G) ==
        LD[r,s] + KD[r,s] + sum(ID[r,g,s] for g in G)
    )
    PROFIT_A[r in R, g in G], (
        (1 - d[:ta0][r,g])*ARM[r,g] + RX[r,g] ==
        (1 + d[:tm0][r,g])*IMP[r,g] + ND[r,g] + DD[r,g] + sum(MARD[r,m,g] for m in M)
    )
    PROFIT_X[r in R, g in G], SUP[r,g] + RX[r,g] == XPT[r,g] + XN[r,g] + XD[r,g]
    PROFIT_MS[r in R, m in M], sum(NM[r,s,m] + DM[r,s,m] for s in S) == sum(MARD[r,m,g] for g in G)
end)

# Market clearing conditions
@constraints(calib, begin
    MARKET_PY[r in R, g in G], SUP[r,g] == sum(YS[r,s,g] for s in S) + YH[r,g]
    MARKET_PA[r in R, g in G], ARM[r,g] == sum(ID[r,g,s] for s in S) + CD[r,g] + GD[r,g] + INV[r,g]
    MARKET_PD[r in R, g in G], XD[r,g] == sum(DM[r,g,m] for m in M) + DD[r,g]
    MARKET_PN[g in G], sum(XN[r,g] for r in R) == sum(NM[r,g,m] for (r,m) in set[:r,:m])
    MARKET_PFX, (
        sum(IMP[r,g] for (r,g) in set[:r,:g]) ==
        sum(BOP[r] + d[:hhadj][r] for r in R) + sum(XPT[r,g] for (r,g) in set[:r,:g])
    )
end)

# Gross exports > re-exports
@constraint(calib, EXPDEF[r in R, g in G], XPT[r,g] >= RX[r,g])

# Income balance
@constraint(calib, INCBAL[r in R],
    sum(CD[r,g] + GD[r,g] + INV[r,g] for g in G) ==
    sum(YH[r,g] + BOP[r] + d[:hhadj][r] for g in G)
    + sum(LD[r,s]+KD[r,s] for s in S)
    + sum(d[:ta0][r,g]*ARM[r,g] + d[:tm0][r,g]*IMP[r,g] for g in G)
    + sum(d[:ty0][r,s] * sum(YS[r,s,g] for g in G) for s in S)
)

# Value share conditions
@constraints(calib, begin
    LVSHR1[r in R, s in S], LD[r,s] >= 0.5*d[:fvs_ld0][r,s] * sum(YS[r,s,g] for g in G)
    KVSHR1[r in R, s in S], KD[r,s] >= 0.5*d[:fvs_kd0][r,s] * sum(YS[r,s,g] for g in G)
end)

# Net generation of electricity balancing
@constraints(calib, begin
    NETGEN_GPOS[r in R; d[:netgen][r] > 0], ND[r,"ele"] - XN[r,"ele"] >= 0.8*d[:netgen][r]
    NETGEN_LPOS[r in R; d[:netgen][r] > 0], ND[r,"ele"] - XN[r,"ele"] <= 1.2*d[:netgen][r]
    NETGEN_LNEG[r in R; d[:netgen][r] < 0], ND[r,"ele"] - XN[r,"ele"] <= 0.8*d[:netgen][r]
    NETGEN_GNEG[r in R; d[:netgen][r] < 0], ND[r,"ele"] - XN[r,"ele"] >= 1.2*d[:netgen][r]
end)

# Verify regional totals equal national totals.
@constraints(calib, begin
    NATIONAL_X0[s in SNAT], sum(XPT[r,s] for r in R) == d[:x0_nat][s]
    NATIONAL_M0[s in SNAT], sum(IMP[r,s] for r in R) == d[:m0_nat][s]
    NATIONAL_VA0[s in SNAT], sum(LD[r,s] + KD[r,s] for r in R) == d[:va0_nat][s]
    NATIONAL_G0[s in SNAT], sum(GD[r,s] for r in R) == d[:g0_nat][s]
    NATIONAL_I0[s in SNAT], sum(INV[r,s] for r in R) == d[:i0_nat][s]
    NATIONAL_C0[s in SNAT], sum(CD[r,s] for r in R) == d[:cd0_nat][s]
end)

# --- DEFINE OBJECTIVE -----------------------------------------------------------------
@objective(calib, Min,
    # production
    + sum(abs(d[:ys0][r,s,g]) * (YS[r,s,g]/d[:ys0][r,s,g] - 1)^2 for (r,s,g) in set[:r,:s,:g] if d[:ys0][r,s,g] != 0)
    + sum(abs(d[:id0][r,g,s]) * (ID[r,g,s]/d[:id0][r,g,s] - 1)^2 for (r,g,s) in set[:r,:g,:s] if d[:id0][r,g,s] != 0)
    + sum(abs(d[:ld0][r,s]) * (LD[r,s]/d[:ld0][r,s] - 1)^2 for (r,s) in set[:r,:s] if d[:ld0][r,s] != 0)
    + sum(abs(d[:kd0][r,s]) * (KD[r,s]/d[:kd0][r,s] - 1)^2 for (r,s) in set[:r,:s] if d[:kd0][r,s] != 0)
    # trade
    + sum(abs(d[:a0][r,g])  * (ARM[r,g]/d[:a0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:a0][r,g] != 0)
    + sum(abs(d[:nd0][r,g]) * (ND[r,g]/d[:nd0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:nd0][r,g] != 0)
    + sum(abs(d[:dd0][r,g]) * (DD[r,g]/d[:dd0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:dd0][r,g] != 0)
    + sum(abs(d[:m0][r,g])  * (IMP[r,g]/d[:m0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:m0][r,g] != 0)
    # supply
    + sum(abs(d[:s0][r,g])  * (SUP[r,g]/d[:s0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:s0][r,g] != 0)
    + sum(abs(d[:xd0][r,g]) * (XD[r,g]/d[:xd0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:xd0][r,g] != 0)
    + sum(abs(d[:xn0][r,g]) * (XN[r,g]/d[:xn0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:xn0][r,g] != 0)
    + sum(abs(d[:x0][r,g])  * (XPT[r,g]/d[:x0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:x0][r,g] != 0)
    + sum(abs(d[:rx0][r,g]) * (RX[r,g]/d[:rx0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:rx0][r,g] != 0)
    # demand
    + sum(abs(d[:yh0][r,g]) * (YH[r,g]/d[:yh0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:yh0][r,g] != 0)
    + sum(abs(d[:cd0][r,g]) * (CD[r,g]/d[:cd0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:cd0][r,g] != 0)
    + sum(abs(d[:i0][r,g])  * (INV[r,g]/d[:i0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:i0][r,g] != 0)
    + sum(abs(d[:g0][r,g])  * (GD[r,g]/d[:g0][r,g] - 1)^2  for (r,g) in set[:r,:g] if d[:g0][r,g] != 0)
    + sum(abs(d[:bopdef0][r]) * (BOP[r]/d[:bopdef0][r] - 1)^2 for (r) in R if d[:bopdef0][r] != 0)
    # margin
    + sum(abs(d[:nm0][r,g,m]) * (NM[r,g,m]/d[:nm0][r,g,m] - 1)^2   for (r,g,m) in set[:r,:g,:m] if d[:nm0][r,g,m] != 0)
    + sum(abs(d[:dm0][r,g,m]) * (DM[r,g,m]/d[:dm0][r,g,m] - 1)^2   for (r,g,m) in set[:r,:g,:m] if d[:dm0][r,g,m] != 0)
    + sum(abs(d[:md0][r,m,g]) * (MARD[r,m,g]/d[:md0][r,m,g] - 1)^2 for (r,m,g) in set[:r,:m,:g] if d[:md0][r,m,g] != 0)
+ penalty_nokey * (
    # production
    + sum(YS[r,s,g] for (r,s,g) in set[:r,:s,:g] if d[:ys0][r,s,g] == 0)
    + sum(ID[r,g,s] for (r,g,s) in set[:r,:g,:s] if d[:id0][r,g,s] == 0)
    + sum(LD[r,s] for (r,s) in set[:r,:s] if d[:ld0][r,s] == 0)
    + sum(KD[r,s] for (r,s) in set[:r,:s] if d[:kd0][r,s] == 0)
    # trade
    + sum(ARM[r,g] for (r,g) in set[:r,:g] if d[:a0][r,g] == 0)
    + sum(ND[r,g]  for (r,g) in set[:r,:g] if d[:nd0][r,g] == 0)
    + sum(DD[r,g]  for (r,g) in set[:r,:g] if d[:dd0][r,g] == 0)
    + sum(IMP[r,g] for (r,g) in set[:r,:g] if d[:m0][r,g] == 0)
    # supply
    + sum(SUP[r,g] for (r,g) in set[:r,:g] if d[:s0][r,g] == 0)
    + sum(XD[r,g]  for (r,g) in set[:r,:g] if d[:xd0][r,g] == 0)
    + sum(XN[r,g]  for (r,g) in set[:r,:g] if d[:xn0][r,g] == 0)
    + sum(XPT[r,g] for (r,g) in set[:r,:g] if d[:x0][r,g] == 0)
    + sum(RX[r,g]  for (r,g) in set[:r,:g] if d[:rx0][r,g] == 0)
    # demand
    + sum(YH[r,g]  for (r,g) in set[:r,:g] if d[:yh0][r,g] == 0)
    + sum(CD[r,g]  for (r,g) in set[:r,:g] if d[:cd0][r,g] == 0)
    + sum(INV[r,g] for (r,g) in set[:r,:g] if d[:i0][r,g] == 0)
    + sum(GD[r,g]  for (r,g) in set[:r,:g] if d[:g0][r,g] == 0)
    # margin
    + sum(NM[r,g,m]   for (r,g,m) in set[:r,:g,:m] if d[:nm0][r,g,m] == 0)
    + sum(DM[r,g,m]   for (r,g,m) in set[:r,:g,:m] if d[:dm0][r,g,m] == 0)
    + sum(MARD[r,m,g] for (r,m,g) in set[:r,:m,:g] if d[:md0][r,m,g] == 0)
    )
);

# ----- SET BOUNDS ---------------------------------------------------------------------
# Fix international electricity imports/exports to zero (subject to SEDS data).
[d[:x0][r,"ele"]>0 ? set_lower_bound(XPT[r,"ele"], lb_seds*d[:x0][r,"ele"]) : fix(XPT[r,"ele"],0,force=true) for r in R]
[d[:m0][r,"ele"]>0 ? set_lower_bound(IMP[r,"ele"], lb_seds*d[:m0][r,"ele"]) : fix(IMP[r,"ele"],0,force=true) for r in R]

# Adjust upper and lower bounds to allow SEDS data to shift.
[set_lower_bound(CD[r,e], lb_seds*d[:cd0][r,e]) for (r,e) in set[:r,:e]]
[set_upper_bound(CD[r,e], ub_seds*d[:cd0][r,e]) for (r,e) in set[:r,:e]]

[set_lower_bound(YS[r,e,e], lb_seds*d[:ys0][r,e,e]) for (r,e) in set[:r,:e]]
[set_upper_bound(YS[r,e,e], ub_seds*d[:ys0][r,e,e]) for (r,e) in set[:r,:e]]

[set_lower_bound(ID[r,e,s], lb_seds*d[:id0][r,e,s]) for (r,e,s) in set[:r,:e,:s]]
[set_upper_bound(ID[r,e,s], ub_seds*d[:id0][r,e,s]) for (r,e,s) in set[:r,:e,:s]]

[set_lower_bound(MARD[r,m,e], lb_seds*d[:md0][r,m,e]) for (r,m,e) in set[:r,:m,:e]]
[set_upper_bound(MARD[r,m,e], ub_seds*d[:md0][r,m,e]) for (r,m,e) in set[:r,:m,:e]]

# --- FIX ZEROS ------------------------------------------------------------------------
# Restrict some parameters to zero.
[fix(YS[r,e,g], 0, force=true) for (r,e,g) in set[:r,:e,:g] if d[:ys0][r,e,g]==0]
[fix(ID[r,g,e], 0, force=true) for (r,g,e) in set[:r,:g,:e] if d[:id0][r,g,e]==0]

[fix(RX[r,g], 0, force=true) for (r,g) in set[:r,:g] if d[:rx0][r,g]==0]
[fix(YH[r,g], 0, force=true) for (r,g) in set[:r,:g] if d[:yh0][r,g]==0]
[fix(NM[r,g,m], 0, force=true) for (r,g,m) in set[:r,:g,:m] if d[:nm0][r,g,m]==0]
[fix(DM[r,g,m], 0, force=true) for (r,g,m) in set[:r,:g,:m] if d[:dm0][r,g,m]==0]
[fix(MARD[r,m,g], 0, force=true) for (r,m,g) in set[:r,:m,:g] if d[:md0][r,m,g]==0]

# Set electricity imports from the national market to Alaska and Hawaii to zero.
[fix(ND[r,"ele"], 0, force=true) for r in ["ak","hi"]]
[fix(XN[r,"ele"], 0, force=true) for r in ["ak","hi"]]

calib_inp = copy(calib)
JuMP.optimize!(calib)