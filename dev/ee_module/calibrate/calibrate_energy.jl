import Ipopt
using JuMP

year = 2016
io_in = read_from("data/state_model/build/eem")
penalty_nokey = SLiDE.DEFAULT_PENALTY_NOKEY

# Read sets.
f_read = joinpath(SLIDE_DIR,"src","build","readfiles")
f_data = joinpath(SLIDE_DIR,"data")
set = merge(
    read_from(joinpath(f_read,"setlist.yml")),
    Dict(k=>df[:,1] for (k,df) in read_from(joinpath(f_data,"coresets","eem"))),
)
set[:g] = unique(dropmissing(io[:ys0])[:,:g])
set[:s] = unique(dropmissing(io[:ys0])[:,:s])
set[:eneg] = ["col","ele","oil"]

# Add bluenote data where we have not yet saved EEM output.
merge!(io_in, Dict(
    :fvs => bn[:fvs],
    :netgen => bn[:netgen],
))

# Isolate year to loop over.
io = Dict(k => filter_with(df, (yr=year,); drop=true) for (k,df) in io_in)

# Calculate additional values for constraints.
io[:va0] = io[:ld0] + io[:kd0]
[io[append(k,:nat)] = combine_over(io[k],:r) for k in [:ys0,:x0,:m0,:va0,:g0,:i0,:cd0]]
[io[append(:fvs,k)] = filter_with(io[:fvs], (parameter=k,); drop=true) for k in ["ld0","kd0"]]

io[:netgen] = filter_with(io[:netgen], (dataset="seds",); drop=true)

# Fill zeros and convert to a dictionary of dictionaries.
d = Dict(k => convert_type(Dict, fill_zero(df; with=set)) for (k,df) in copy(io))

# Save set permutations and names.
SLiDE._calibration_set!(set)
SLiDE.add_permutation!(set, (:r,:e))
SLiDE.add_permutation!(set, (:r,:e,:g))
SLiDE.add_permutation!(set, (:r,:g,:e))
SLiDE.add_permutation!(set, (:r,:m,:e))

R = copy(set[:r])
G = copy(set[:g])
S = copy(set[:s])
M = copy(set[:m])
SNAT = setdiff(S,set[:eneg])

calib = Model(optimizer_with_attributes(Ipopt.Optimizer, "max_cpu_time" => 60.0))

lb = 0.25
ub = 1.75
ub_seds = 1.25
lb_seds = 0.75

# ----- INITIALIZE VARIABLES -----
@variables(calib, begin
    YS[r in R, s in S, g in G], (start=d[:ys0][r,s,g], lower_bound=lb*d[:ys0][r,s,g])
    ID[r in R, s in G, g in S], (start=d[:id0][r,g,s], lower_bound=lb*d[:id0][r,g,s])
    LD[r in R, s in S],  (start=d[:ld0][r,s], lower_bound=0)
    KD[r in R, s in S],  (start=d[:kd0][r,s], lower_bound=0)
    ARM[r in R, g in G], (start=d[:a0 ][r,g], lower_bound=lb*d[:a0 ][r,g])
    ND[r in R, g in G],  (start=d[:nd0][r,g], lower_bound=lb*d[:nd0][r,g])
    DD[r in R, g in G],  (start=d[:dd0][r,g], lower_bound=lb*d[:dd0][r,g])
    IMP[r in R, g in G], (start=d[:m0 ][r,g], lower_bound=lb*d[:m0 ][r,g])
    SUP[r in R, g in G], (start=d[:s0 ][r,g], lower_bound=lb*d[:s0 ][r,g])
    XD[r in R, g in G],  (start=d[:xd0][r,g], lower_bound=lb*d[:xd0][r,g])
    XN[r in R, g in G],  (start=d[:xn0][r,g], lower_bound=lb*d[:xn0][r,g])
    XPT[r in R, g in G], (start=d[:x0 ][r,g], lower_bound=lb*d[:x0 ][r,g])
    RX[r in R, g in G],  (start=d[:rx0][r,g], lower_bound=lb*d[:rx0][r,g])
    YH[r in R, g in G],  (start=d[:yh0][r,g], lower_bound=0)
    CD[r in R, g in G],  (start=d[:cd0][r,g], lower_bound=0)
    INV[r in R, g in G], (start=d[:i0 ][r,g], lower_bound=lb*d[:i0 ][r,g], upper_bound=ub*d[:i0][r,g])
    GD[r in R, g in G] , (start=d[:g0 ][r,g], lower_bound=lb*d[:g0 ][r,g])
    NM[r in R, g in G, m in M],   (start=d[:nm0][r,g,m], lower_bound=lb*d[:nm0][r,g,m])
    DM[r in R, g in G, m in M],   (start=d[:dm0][r,g,m], lower_bound=lb*d[:dm0][r,g,m])
    MARD[r in R, m in M, g in G], (start=d[:md0][r,m,g], lower_bound=lb*d[:md0][r,m,g])
    BOP[r in R] >= 0, (start=d[:bopdef0][r])
end)


@time begin
    for r in set[:r]
        # Fix international electricity imports/exports to zero (subject to SEDS data).
        if d[:x0][r,"ele"]>0;       set_lower_bound(XPT[r,"ele"], lb_seds*d[:x0][r,"ele"])
        elseif d[:x0][r,"ele"]==0;  fix(XPT[r,"ele"], 0, force=true)
        end

        if d[:m0][r,"ele"]>0;       set_lower_bound(IMP[r,"ele"], lb_seds*d[:m0][r,"ele"])
        elseif d[:m0][r,"ele"]==0;  fix(IMP[r,"ele"], 0, force=true)
        end

        # Specify a range over which SEDS data can shift.
        for e in set[:e]        
            set_lower_bound(CD[r,e], lb_seds*d[:cd0][r,e])
            set_upper_bound(CD[r,e], ub_seds*d[:cd0][r,e])

            set_lower_bound(YS[r,e,e], lb_seds*d[:ys0][r,e,e])
            set_upper_bound(YS[r,e,e], ub_seds*d[:ys0][r,e,e])
            
            for s in S   # (g -> e)
                set_lower_bound(ID[r,e,s], lb_seds*d[:id0][r,e,s])
                set_upper_bound(ID[r,e,s], ub_seds*d[:id0][r,e,s])
            end

            for g in G   # (s -> e)
                d[:ys0][r,e,g]==0 && fix(YS[r,e,g], 0, force=true)
                d[:id0][r,g,e]==0 && fix(ID[r,g,e], 0, force=true)
            end

            for m in M
                set_lower_bound(MARD[r,m,e], lb_seds*d[:md0][r,m,e])
                set_upper_bound(MARD[r,m,e], ub_seds*d[:md0][r,m,e])
            end
        end

        # Restrict some parameters to zero.
        for g in set[:g]
            d[:rx0][r,g]==0 && fix(RX[r,g], 0, force=true)
            d[:yh0][r,g]==0 && fix(YH[r,g], 0, force=true)

            for m in M
                d[:nm0][r,g,m]==0 && fix(NM[r,g,m], 0, force=true)
                d[:dm0][r,g,m]==0 && fix(DM[r,g,m], 0, force=true)
                d[:md0][r,g,m]==0 && fix(MARD[r,g,m], 0, force=true)
            end
        end
    end

    # Set electricity imports from the national market to Alaska and Hawaii to zero.
    for r in ["ak","hi"]
        fix(ND[r,"ele"], 0, force=true)
        fix(XN[r,"ele"], 0, force=true)
    end
end;

@time begin
    # Fix international electricity imports/exports to zero (subject to SEDS data).
    [d[:x0][r,"ele"]>0 ? set_lower_bound(XPT[r,"ele"], lb_seds*d[:x0][r,"ele"]) : fix(XPT[r,"ele"],0,force=true) for r in R]
    [d[:m0][r,"ele"]>0 ? set_lower_bound(IMP[r,"ele"], lb_seds*d[:m0][r,"ele"]) : fix(IMP[r,"ele"],0,force=true) for r in R]


    [set_lower_bound(CD[r,e], lb_seds*d[:cd0][r,e]) for (r,e) in set[:r,:e]]
    [set_upper_bound(CD[r,e], ub_seds*d[:cd0][r,e]) for (r,e) in set[:r,:e]]

    [set_lower_bound(YS[r,e,e], lb_seds*d[:ys0][r,e,e]) for (r,e) in set[:r,:e]]
    [set_upper_bound(YS[r,e,e], ub_seds*d[:ys0][r,e,e]) for (r,e) in set[:r,:e]]

    [set_lower_bound(ID[r,e,s], lb_seds*d[:id0][r,e,s]) for (r,e,s) in set[:r,:e,:s]]
    [set_upper_bound(ID[r,e,s], ub_seds*d[:id0][r,e,s]) for (r,e,s) in set[:r,:e,:s]]

    [set_lower_bound(MARD[r,m,e], lb_seds*d[:md0][r,m,e]) for (r,m,e) in set[:r,:m,:e]]
    [set_upper_bound(MARD[r,m,e], ub_seds*d[:md0][r,m,e]) for (r,m,e) in set[:r,:m,:e]]

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
end;


# for ()

# # --- DEFINE CONSTRAINTS ---------------------------------------------------------------

# # ------- ZERO PROFIT CONDITIONS -------
# @constraint(calib, PROFIT_Y[r in R, s in S],
#     (1-d[:ty0][r,s]) * sum(YS[r,s,g] for g in G) ==
#     sum(ID[r,g,s] for g in G) + LD[r,s] + KD[r,s]
# )

# @constraint(calib, PROFIT_A[r in R, g in G],
#     (1-d[:ta0][r,g]) * ARM[r,g] + RX[r,g] ==
#     ND[r,g] + DD[r,g] + (1+d[:tm0][r,g])*IMP[r,g] + sum(MARD[r,m,g] for m in M)
# )

# @constraint(calib, PROFIT_X[r in R, g in G],
#     SUP[r,g] + RX[r,g] ==
#     XPT[r,g] + XN[r,g] + XD[r,g]
# )

# @constraint(calib, PROFIT_MS[r in R, m in M],
#     sum(NM[r,s,m] + DM[r,s,m] for s in S) ==
#     sum(MARD[r,m,g] for g in G)
# )

# # ----- MARKET CLEARING CONDITIONS -----
# @constraint(calib, MARKET_PY[r in R, g in G],
#     SUP[r,g] ==
#     sum(YS[r,s,g] for s in S) + YH[r,g]
# )

# @constraint(calib, MARKET_PA[r in R, g in G],
#     ARM[r,g] ==
#     sum(ID[r,g,s] for s in S) + CD[r,g] + GD[r,g] + INV[r,g]
# )

# @constraint(calib, MARKET_PD[r in R, g in G],
#     XD[r,g] ==
#     sum(DM[r,g,m] for m in M) + DD[r,g]
# )

# @constraint(calib, MARKET_PN[g in G],
#     sum(XN[r,g] for r in R) ==
#     sum(NM[r,g,m] for (r,m) in set[:r,:m])
# )

# @constraint(calib, MARKET_PFX,
#     sum(IMP[r,g] for (r,g) in set[:r,:g]) ==
#     sum(BOP[r] + d[:hhadj][r] for r in R) + sum(XPT[r,g] for (r,g) in set[:r,:g])
# )

# # ---------- OTHER CONDITIONS ----------
# # Gross exports > re-exports
# @constraint(calib, EXPDEF[r in R, g in G], XPT[r,g] >= RX[r,g])

# # Income balance
# @constraint(calib, INCBAL[r in R],
#     sum(CD[r,g] + GD[r,g] + INV[r,g] for g in G) ==
#     sum(YH[r,g] + BOP[r] + d[:hhadj][r] for g in G)
#     + sum(LD[r,s]+KD[r,s] for s in S)
#     + sum(d[:ta0][r,g]*ARM[r,g] + d[:tm0][r,g]*IMP[r,g] for g in G)
#     + sum(d[:ty0][r,s] * sum(YS[r,s,g] for g in G) for s in S)
# )

# # Value share conditions
# @constraint(calib, begin
#     LVSHR1[r in R, s in S], LD[r,s] >= 0.5*d[:fvs_ld0][r,s] * sum(YS[r,s,g] for g in G)
#     KVSHR1[r in R, s in S], KD[r,s] >= 0.5*d[:fvs_kd0][r,s] * sum(YS[r,s,g] for g in G)
# end)

# # Net generation of electricity balancing
# @constraints(calib, begin
#     NETGEN_GPOS[r in R; d[:netgen][r] > 0], ND[r,"ele"] - XN[r,"ele"] >= 0.8*d[:netgen][r]
#     NETGEN_LPOS[r in R; d[:netgen][r] > 0], ND[r,"ele"] - XN[r,"ele"] <= 1.2*d[:netgen][r]
#     NETGEN_LNEG[r in R; d[:netgen][r] < 0], ND[r,"ele"] - XN[r,"ele"] <= 0.8*d[:netgen][r]
#     NETGEN_GNEG[r in R; d[:netgen][r] < 0], ND[r,"ele"] - XN[r,"ele"] >= 1.2*d[:netgen][r]
# end)

# # Verify regional totals equal national totals.
# @constraints(calib, begin
#     NATIONAL_X0[s in SNAT], sum(XPT[r,s] for r in R) == d[:x0_nat][s]
#     NATIONAL_M0[s in SNAT], sum(IMP[r,s] for r in R) == d[:m0_nat][s]
#     NATIONAL_VA0[s in SNAT], sum(LD[r,s] + KD[r,s] for r in R) == d[:va0_nat][s]
#     NATIONAL_G0[s in SNAT], sum(GD[r,s] for r in R) == d[:g0_nat][s]
#     NATIONAL_I0[s in SNAT], sum(INV[r,s] for r in R) == d[:i0_nat][s]
#     NATIONAL_C0[s in SNAT], sum(CD[r,s] for r in R) == d[:cd0_nat][s]
# end)


# # --- DEFINE OBJECTIVE -----------------------------------------------------------------
# @objective(calib, Min,
#     # production
#     + sum(abs(d[:ys0][r,s,g]) * (YS[r,s,g]/d[:ys0][r,s,g] - 1)^2 for (r,s,g) in set[:r,:s,:g] if d[:ys0][r,s,g] != 0)
#     + sum(abs(d[:id0][r,g,s]) * (ID[r,g,s]/d[:id0][r,g,s] - 1)^2 for (r,g,s) in set[:r,:g,:s] if d[:id0][r,g,s] != 0)
#     + sum(abs(d[:ld0][r,s]) * (LD[r,s]/d[:ld0][r,s] - 1)^2 for (r,s) in set[:r,:s] if d[:ld0][r,s] != 0)
#     + sum(abs(d[:kd0][r,s]) * (KD[r,s]/d[:kd0][r,s] - 1)^2 for (r,s) in set[:r,:s] if d[:kd0][r,s] != 0)
#     # trade
#     + sum(abs(d[:a0][r,g])  * (ARM[r,g]/d[:a0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:a0][r,g] != 0)
#     + sum(abs(d[:nd0][r,g]) * (ND[r,g]/d[:nd0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:nd0][r,g] != 0)
#     + sum(abs(d[:dd0][r,g]) * (DD[r,g]/d[:dd0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:dd0][r,g] != 0)
#     + sum(abs(d[:m0][r,g])  * (IMP[r,g]/d[:m0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:m0][r,g] != 0)
#     # supply
#     + sum(abs(d[:s0][r,g])  * (SUP[r,g]/d[:s0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:s0][r,g] != 0)
#     + sum(abs(d[:xd0][r,g]) * (XD[r,g]/d[:xd0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:xd0][r,g] != 0)
#     + sum(abs(d[:xn0][r,g]) * (XN[r,g]/d[:xn0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:xn0][r,g] != 0)
#     + sum(abs(d[:x0][r,g])  * (XPT[r,g]/d[:x0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:x0][r,g] != 0)
#     + sum(abs(d[:rx0][r,g]) * (RX[r,g]/d[:rx0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:rx0][r,g] != 0)
#     # margin
#     + sum(abs(d[:nm0][r,g,m]) * (NM[r,g,m]/d[:nm0][r,g,m] - 1)^2   for (r,g,m) in set[:r,:g,:m] if d[:nm0][r,g,m] != 0)
#     + sum(abs(d[:dm0][r,g,m]) * (DM[r,g,m]/d[:dm0][r,g,m] - 1)^2   for (r,g,m) in set[:r,:g,:m] if d[:dm0][r,g,m] != 0)
#     + sum(abs(d[:md0][r,m,g]) * (MARD[r,m,g]/d[:md0][r,m,g] - 1)^2 for (r,m,g) in set[:r,:m,:g] if d[:md0][r,m,g] != 0)
#     # demand
#     + sum(abs(d[:yh0][r,g]) * (YH[r,g]/d[:yh0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:yh0][r,g] != 0)
#     + sum(abs(d[:cd0][r,g]) * (CD[r,g]/d[:cd0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:cd0][r,g] != 0)
#     + sum(abs(d[:i0][r,g])  * (INV[r,g]/d[:i0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:i0][r,g] != 0)
#     + sum(abs(d[:g0][r,g])  * (GD[r,g]/d[:g0][r,g] - 1)^2  for (r,g) in set[:r,:g] if d[:g0][r,g] != 0)
#     + sum(abs(d[:bopdef0][r]) * (BOP[r]/d[:bopdef0][r] - 1)^2 for (r) in R if d[:bopdef0][r] != 0)
# + penalty_nokey * (
#     # production
#     + sum(YS[r,s,g] for (r,s,g) in set[:r,:s,:g] if d[:ys0][r,s,g] == 0)
#     + sum(ID[r,g,s] for (r,g,s) in set[:r,:g,:s] if d[:id0][r,g,s] == 0)
#     + sum(LD[r,s] for (r,s) in set[:r,:s] if d[:ld0][r,s] == 0)
#     + sum(KD[r,s] for (r,s) in set[:r,:s] if d[:kd0][r,s] == 0)
#     # trade
#     + sum(ARM[r,g] for (r,g) in set[:r,:g] if d[:a0][r,g] == 0)
#     + sum(ND[r,g]  for (r,g) in set[:r,:g] if d[:nd0][r,g] == 0)
#     + sum(DD[r,g]  for (r,g) in set[:r,:g] if d[:dd0][r,g] == 0)
#     + sum(IMP[r,g] for (r,g) in set[:r,:g] if d[:m0][r,g] == 0)
#     # supply
#     + sum(SUP[r,g] for (r,g) in set[:r,:g] if d[:s0][r,g] == 0)
#     + sum(XD[r,g]  for (r,g) in set[:r,:g] if d[:xd0][r,g] == 0)
#     + sum(XN[r,g]  for (r,g) in set[:r,:g] if d[:xn0][r,g] == 0)
#     + sum(XPT[r,g] for (r,g) in set[:r,:g] if d[:x0][r,g] == 0)
#     + sum(RX[r,g]  for (r,g) in set[:r,:g] if d[:rx0][r,g] == 0)
#     # margin
#     + sum(NM[r,g,m]   for (r,g,m) in set[:r,:g,:m] if d[:nm0][r,g,m] == 0)
#     + sum(DM[r,g,m]   for (r,g,m) in set[:r,:g,:m] if d[:dm0][r,g,m] == 0)
#     + sum(MARD[r,m,g] for (r,m,g) in set[:r,:m,:g] if d[:md0][r,m,g] == 0)
#     # demand
#     + sum(YH[r,g]  for (r,g) in set[:r,:g] if d[:yh0][r,g] == 0)
#     + sum(CD[r,g]  for (r,g) in set[:r,:g] if d[:cd0][r,g] == 0)
#     + sum(INV[r,g] for (r,g) in set[:r,:g] if d[:i0][r,g] == 0)
#     + sum(GD[r,g]  for (r,g) in set[:r,:g] if d[:g0][r,g] == 0)
#     )
# );

# # --- SET START VALUE ------------------------------------------------------------------
# # production
# [set_start_value(YS[r,s,g], d[:ys0][r,s,g]) for (r,s,g) in set[:r,:s,:g]]
# [set_start_value(ID[r,g,s], d[:id0][r,g,s]) for (r,g,s) in set[:r,:g,:s]]
# [set_start_value(KD[r,s], d[:kd0][r,s]) for (r,s) in set[:r,:s]]
# [set_start_value(LD[r,s], d[:ld0][r,s]) for (r,s) in set[:r,:s]]
# # trade
# [set_start_value(ARM[r,g], d[:a0][r,g]) for (r,g) in set[:r,:g]]
# [set_start_value(ND[r,g], d[:nd0][r,g]) for (r,g) in set[:r,:g]]
# [set_start_value(DD[r,g], d[:dd0][r,g]) for (r,g) in set[:r,:g]]
# [set_start_value(IMP[r,g], d[:m0][r,g]) for (r,g) in set[:r,:g]]
# # supply
# [set_start_value(SUP[r,g], d[:s0][r,g]) for (r,g) in set[:r,:g]]
# [set_start_value(XD[r,g], d[:xd0][r,g]) for (r,g) in set[:r,:g]]
# [set_start_value(XN[r,g], d[:xn0][r,g]) for (r,g) in set[:r,:g]]
# [set_start_value(XPT[r,g], d[:x0][r,g]) for (r,g) in set[:r,:g]]
# [set_start_value(RX[r,g], d[:rx0][r,g]) for (r,g) in set[:r,:g]]
# # margin
# [set_start_value(DM[r,g,m], d[:dm0][r,g,m]) for (r,g,m) in set[:r,:g,:m]]
# [set_start_value(NM[r,g,m], d[:nm0][r,g,m]) for (r,g,m) in set[:r,:g,:m]]
# [set_start_value(MARD[r,m,g], d[:md0][r,m,g]) for (r,m,g) in set[:r,:m,:g]]
# # demand
# [set_start_value(YH[r,g], d[:yh0][r,g]) for (r,g) in set[:r,:g]]
# [set_start_value(CD[r,g], d[:cd0][r,g]) for (r,g) in set[:r,:g]]
# [set_start_value(INV[r,g], d[:i0][r,g]) for (r,g) in set[:r,:g]]
# [set_start_value(GD[r,g], d[:g0][r,g]) for (r,g) in set[:r,:g]]
# [set_start_value(BOP[r], d[:bopdef0][r]) for (r) in R]

# # --- SET BOUNDS -----------------------------------------------------------------------
# # multipliers for lower and upper bound relative
# # to each respective variables reference parameter
# lb = SLiDE.DEFAULT_CALIBRATE_LOWER_BOUND
# ub = SLiDE.DEFAULT_CALIBRATE_UPPER_BOUND

# # [set_lower_bound(YS[r,s,g], max(0, lb * d[:ys0][r,s,g])) for (r,s,g) in set[:r,:s,:g]]
# # [set_lower_bound(ID[r,g,s], max(0, lb * d[:id0][r,g,s])) for (r,g,s) in set[:r,:g,:s]]
# # [set_lower_bound(LD[r,s], max(0, lb * d[:ld0][r,s])) for (r,s) in set[:r,:s]]
# # [set_lower_bound(KD[r,s], max(0, lb * d[:kd0][r,s])) for (r,s) in set[:r,:s]]
# # [set_lower_bound(ARM[r,g], max(0, lb * d[:a0][r,g])) for (r,g) in set[:r,:g]]
# # [set_lower_bound(ND[r,g], max(0, lb * d[:nd0][r,g])) for (r,g) in set[:r,:g]]
# # [set_lower_bound(DD[r,g], max(0, lb * d[:dd0][r,g])) for (r,g) in set[:r,:g]]
# # [set_lower_bound(IMP[r,g], max(0, lb * d[:m0][r,g])) for (r,g) in set[:r,:g]]
# # [set_lower_bound(SUP[r,g], max(0, lb * d[:s0][r,g])) for (r,g) in set[:r,:g]]
# # [set_lower_bound(XD[r,g], max(0, lb * d[:xd0][r,g])) for (r,g) in set[:r,:g]]
# # [set_lower_bound(XN[r,g], max(0, lb * d[:xn0][r,g])) for (r,g) in set[:r,:g]]
# # [set_lower_bound(XPT[r,g], max(0, lb * d[:x0][r,g])) for (r,g) in set[:r,:g]]
# # [set_lower_bound(RX[r,g], max(0, lb * d[:rx0][r,g])) for (r,g) in set[:r,:g]]
# # [set_lower_bound(NM[r,g,m], max(0, lb * d[:nm0][r,g,m])) for (r,g,m) in set[:r,:g,:m]]
# # [set_lower_bound(DM[r,g,m], max(0, lb * d[:dm0][r,g,m])) for (r,g,m) in set[:r,:g,:m]]
# # [set_lower_bound(MARD[r,m,g], max(0, lb * d[:md0][r,m,g])) for (r,m,g) in set[:r,:m,:g]]
# # [set_lower_bound(YH[r,g], max(0, lb * d[:yh0][r,g])) for (r,g) in set[:r,:g]]
# # [set_lower_bound(CD[r,g], max(0, lb * d[:cd0][r,g])) for (r,g) in set[:r,:g]]
# # [set_lower_bound(INV[r,g], max(0, lb * d[:i0][r,g])) for (r,g) in set[:r,:g]]
# # [set_lower_bound(GD[r,g], max(0, lb * d[:g0][r,g])) for (r,g) in set[:r,:g]]
# # [set_lower_bound(BOP[r], max(0, lb * d[:bopdef0][r])) for (r) in R]

# # [set_upper_bound(YS[r,s,g], abs(ub * d[:ys0][r,s,g])) for (r,s,g) in set[:r,:s,:g]]
# # [set_upper_bound(ID[r,g,s], abs(ub * d[:id0][r,g,s])) for (r,g,s) in set[:r,:g,:s]]
# # [set_upper_bound(LD[r,s], abs(ub * d[:ld0][r,s])) for (r,s) in set[:r,:s]]
# # [set_upper_bound(KD[r,s], abs(ub * d[:kd0][r,s])) for (r,s) in set[:r,:s]]
# # [set_upper_bound(ARM[r,g], abs(ub * d[:a0][r,g])) for (r,g) in set[:r,:g]]
# # [set_upper_bound(ND[r,g], abs(ub * d[:nd0][r,g])) for (r,g) in set[:r,:g]]
# # [set_upper_bound(DD[r,g], abs(ub * d[:dd0][r,g])) for (r,g) in set[:r,:g]]
# # [set_upper_bound(IMP[r,g], abs(ub * d[:m0][r,g])) for (r,g) in set[:r,:g]]
# # [set_upper_bound(SUP[r,g], abs(ub * d[:s0][r,g])) for (r,g) in set[:r,:g]]
# # [set_upper_bound(XD[r,g], abs(ub * d[:xd0][r,g])) for (r,g) in set[:r,:g]]
# # [set_upper_bound(XN[r,g], abs(ub * d[:xn0][r,g])) for (r,g) in set[:r,:g]]
# # [set_upper_bound(XPT[r,g], abs(ub * d[:x0][r,g])) for (r,g) in set[:r,:g]]
# # [set_upper_bound(RX[r,g], abs(ub * d[:rx0][r,g])) for (r,g) in set[:r,:g]]
# # [set_upper_bound(NM[r,g,m], abs(ub * d[:nm0][r,g,m])) for (r,g,m) in set[:r,:g,:m]]
# # [set_upper_bound(DM[r,g,m], abs(ub * d[:dm0][r,g,m])) for (r,g,m) in set[:r,:g,:m]]
# # [set_upper_bound(MARD[r,m,g], abs(ub * d[:md0][r,m,g])) for (r,m,g) in set[:r,:m,:g]]
# # [set_upper_bound(YH[r,g], abs(ub * d[:yh0][r,g])) for (r,g) in set[:r,:g]]
# # [set_upper_bound(CD[r,g], abs(ub * d[:cd0][r,g])) for (r,g) in set[:r,:g]]
# # [set_upper_bound(INV[r,g], abs(ub * d[:i0][r,g])) for (r,g) in set[:r,:g]]
# # [set_upper_bound(GD[r,g], abs(ub * d[:g0][r,g])) for (r,g) in set[:r,:g]]
# # [set_upper_bound(BOP[r], abs(ub * d[:bopdef0][r])) for (r) in R]

