import Ipopt
using JuMP

year = 2016
io = read_from("data/state_model/build/eem")
penalty_nokey = SLiDE.DEFAULT_PENALTY_NOKEY

d = Dict(k => convert_type(Dict, fill_zero(filter_with(df, (yr=year,); drop=true); with=set))
    for (k,df) in copy(io))
SLiDE._calibration_set!(set)
calib = Model(optimizer_with_attributes(Ipopt.Optimizer, "max_cpu_time" => 60.0))

# din = read_from("data/") 


# ----- INITIALIZE VARIABLES -----
# production
@variable(calib, YS[r in set[:r], s in set[:s], g in set[:g]] >= 0, start = 0);
@variable(calib, ID[r in set[:r], s in set[:g], g in set[:s]] >= 0, start = 0);
@variable(calib, LD[r in set[:r], s in set[:s]]               >= 0, start = 0);
@variable(calib, KD[r in set[:r], s in set[:s]]               >= 0, start = 0);
# trade
@variable(calib, ARM[r in set[:r], g in set[:g]] >= 0, start = 0);    # a0
@variable(calib, ND[r in set[:r], g in set[:g]]  >= 0, start = 0);
@variable(calib, DD[r in set[:r], g in set[:g]]  >= 0, start = 0);
@variable(calib, IMP[r in set[:r], g in set[:g]] >= 0, start = 0);    # m0
# supply
@variable(calib, SUP[r in set[:r], g in set[:g]] >= 0, start = 0);    # s0
@variable(calib, XD[r in set[:r], g in set[:g]]  >= 0, start = 0);
@variable(calib, XN[r in set[:r], g in set[:g]]  >= 0, start = 0);
@variable(calib, XPT[r in set[:r], g in set[:g]] >= 0, start = 0);    # x0
@variable(calib, RX[r in set[:r], g in set[:g]]  >= 0, start = 0);
# margin
@variable(calib, NM[r in set[:r], g in set[:g], m in set[:m]]   >= 0, start = 0);
@variable(calib, DM[r in set[:r], g in set[:g], m in set[:m]]   >= 0, start = 0);
@variable(calib, MARD[r in set[:r], m in set[:m], g in set[:g]] >= 0, start = 0); #md
# demand
@variable(calib, YH[r in set[:r], g in set[:g]]  >= 0, start = 0);
@variable(calib, CD[r in set[:r], g in set[:g]]  >= 0, start = 0);
@variable(calib, INV[r in set[:r], g in set[:g]] >= 0, start = 0);    #i0
@variable(calib, GD[r in set[:r], g in set[:g]]  >= 0, start = 0);    #g0

@variable(calib, BOP[r in set[:r]]  >= 0, start = 0);

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
    # margin
    + sum(abs(d[:nm0][r,g,m]) * (NM[r,g,m]/d[:nm0][r,g,m] - 1)^2   for (r,g,m) in set[:r,:g,:m] if d[:nm0][r,g,m] != 0)
    + sum(abs(d[:dm0][r,g,m]) * (DM[r,g,m]/d[:dm0][r,g,m] - 1)^2   for (r,g,m) in set[:r,:g,:m] if d[:dm0][r,g,m] != 0)
    + sum(abs(d[:md0][r,m,g]) * (MARD[r,m,g]/d[:md0][r,m,g] - 1)^2 for (r,m,g) in set[:r,:m,:g] if d[:md0][r,m,g] != 0)
    # demand
    + sum(abs(d[:yh0][r,g]) * (YH[r,g]/d[:yh0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:yh0][r,g] != 0)
    + sum(abs(d[:cd0][r,g]) * (CD[r,g]/d[:cd0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:cd0][r,g] != 0)
    + sum(abs(d[:i0][r,g])  * (INV[r,g]/d[:i0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:i0][r,g] != 0)
    + sum(abs(d[:g0][r,g])  * (GD[r,g]/d[:g0][r,g] - 1)^2  for (r,g) in set[:r,:g] if d[:g0][r,g] != 0)
    + sum(abs(d[:bopdef0][r]) * (BOP[r]/d[:bopdef0][r] - 1)^2 for (r) in set[:r] if d[:bopdef0][r] != 0)
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
    # margin
    + sum(NM[r,g,m]   for (r,g,m) in set[:r,:g,:m] if d[:nm0][r,g,m] == 0)
    + sum(DM[r,g,m]   for (r,g,m) in set[:r,:g,:m] if d[:dm0][r,g,m] == 0)
    + sum(MARD[r,m,g] for (r,m,g) in set[:r,:m,:g] if d[:md0][r,m,g] == 0)
    # demand
    + sum(YH[r,g]  for (r,g) in set[:r,:g] if d[:yh0][r,g] == 0)
    + sum(CD[r,g]  for (r,g) in set[:r,:g] if d[:cd0][r,g] == 0)
    + sum(INV[r,g] for (r,g) in set[:r,:g] if d[:i0][r,g] == 0)
    + sum(GD[r,g]  for (r,g) in set[:r,:g] if d[:g0][r,g] == 0)
    )
);

# --- SET START VALUE ------------------------------------------------------------------
# production
[set_start_value(YS[r,s,g], d[:ys0][r,s,g]) for (r,s,g) in set[:r,:s,:g]]
[set_start_value(ID[r,g,s], d[:id0][r,g,s]) for (r,g,s) in set[:r,:g,:s]]
[set_start_value(KD[r,s], d[:kd0][r,s]) for (r,s) in set[:r,:s]]
[set_start_value(LD[r,s], d[:ld0][r,s]) for (r,s) in set[:r,:s]]
# tad
[set_start_value(ARM[r,g], d[:a0][r,g]) for (r,g) in set[:r,:g]]
[set_start_value(ND[r,g], d[:nd0][r,g]) for (r,g) in set[:r,:g]]
[set_start_value(DD[r,g], d[:dd0][r,g]) for (r,g) in set[:r,:g]]
[set_start_value(IMP[r,g], d[:m0][r,g]) for (r,g) in set[:r,:g]]
# supl
[set_start_value(SUP[r,g], d[:s0][r,g]) for (r,g) in set[:r,:g]]
[set_start_value(XD[r,g], d[:xd0][r,g]) for (r,g) in set[:r,:g]]
[set_start_value(XN[r,g], d[:xn0][r,g]) for (r,g) in set[:r,:g]]
[set_start_value(XPT[r,g], d[:x0][r,g]) for (r,g) in set[:r,:g]]
[set_start_value(RX[r,g], d[:rx0][r,g]) for (r,g) in set[:r,:g]]
# margin
[set_start_value(DM[r,g,m], d[:dm0][r,g,m]) for (r,g,m) in set[:r,:g,:m]]
[set_start_value(NM[r,g,m], d[:nm0][r,g,m]) for (r,g,m) in set[:r,:g,:m]]
[set_start_value(MARD[r,m,g], d[:md0][r,m,g]) for (r,m,g) in set[:r,:m,:g]]
# demand
[set_start_value(YH[r,g], d[:yh0][r,g]) for (r,g) in set[:r,:g]]
[set_start_value(CD[r,g], d[:cd0][r,g]) for (r,g) in set[:r,:g]]
[set_start_value(INV[r,g], d[:i0][r,g]) for (r,g) in set[:r,:g]]
[set_start_value(GD[r,g], d[:g0][r,g]) for (r,g) in set[:r,:g]]
[set_start_value(BOP[r], d[:bopdef0][r]) for (r) in set[:r]]

# --- SET BOUNDS -----------------------------------------------------------------------
# multipliers for lower and upper bound relative
# to each respective variables reference parameter
lb = SLiDE.DEFAULT_CALIBRATE_LOWER_BOUND
ub = SLiDE.DEFAULT_CALIBRATE_UPPER_BOUND

[set_lower_bound(YS[r,s,g], max(0, lb * d[:ys0][r,s,g])) for (r,s,g) in set[:r,:s,:g]]
[set_lower_bound(ID[r,g,s], max(0, lb * d[:id0][r,g,s])) for (r,g,s) in set[:r,:g,:s]]
[set_lower_bound(LD[r,s], max(0, lb * d[:ld0][r,s])) for (r,s) in set[:r,:s]]
[set_lower_bound(KD[r,s], max(0, lb * d[:kd0][r,s])) for (r,s) in set[:r,:s]]
[set_lower_bound(ARM[r,g], max(0, lb * d[:a0][r,g])) for (r,g) in set[:r,:g]]
[set_lower_bound(ND[r,g], max(0, lb * d[:nd0][r,g])) for (r,g) in set[:r,:g]]
[set_lower_bound(DD[r,g], max(0, lb * d[:dd0][r,g])) for (r,g) in set[:r,:g]]
[set_lower_bound(IMP[r,g], max(0, lb * d[:m0][r,g])) for (r,g) in set[:r,:g]]
[set_lower_bound(SUP[r,g], max(0, lb * d[:s0][r,g])) for (r,g) in set[:r,:g]]
[set_lower_bound(XD[r,g], max(0, lb * d[:xd0][r,g])) for (r,g) in set[:r,:g]]
[set_lower_bound(XN[r,g], max(0, lb * d[:xn0][r,g])) for (r,g) in set[:r,:g]]
[set_lower_bound(XPT[r,g], max(0, lb * d[:x0][r,g])) for (r,g) in set[:r,:g]]
[set_lower_bound(RX[r,g], max(0, lb * d[:rx0][r,g])) for (r,g) in set[:r,:g]]
[set_lower_bound(NM[r,g,m], max(0, lb * d[:nm0][r,g,m])) for (r,g,m) in set[:r,:g,:m]]
[set_lower_bound(DM[r,g,m], max(0, lb * d[:dm0][r,g,m])) for (r,g,m) in set[:r,:g,:m]]
[set_lower_bound(MARD[r,m,g], max(0, lb * d[:md0][r,m,g])) for (r,m,g) in set[:r,:m,:g]]
[set_lower_bound(YH[r,g], max(0, lb * d[:yh0][r,g])) for (r,g) in set[:r,:g]]
[set_lower_bound(CD[r,g], max(0, lb * d[:cd0][r,g])) for (r,g) in set[:r,:g]]
[set_lower_bound(INV[r,g], max(0, lb * d[:i0][r,g])) for (r,g) in set[:r,:g]]
[set_lower_bound(GD[r,g], max(0, lb * d[:g0][r,g])) for (r,g) in set[:r,:g]]
[set_lower_bound(BOP[r], max(0, lb * d[:bopdef0][r])) for (r) in set[:r]]

[set_upper_bound(YS[r,s,g], abs(ub * d[:ys0][r,s,g])) for (r,s,g) in set[:r,:s,:g]]
[set_upper_bound(ID[r,g,s], abs(ub * d[:id0][r,g,s])) for (r,g,s) in set[:r,:g,:s]]
[set_upper_bound(LD[r,s], abs(ub * d[:ld0][r,s])) for (r,s) in set[:r,:s]]
[set_upper_bound(KD[r,s], abs(ub * d[:kd0][r,s])) for (r,s) in set[:r,:s]]
[set_upper_bound(ARM[r,g], abs(ub * d[:a0][r,g])) for (r,g) in set[:r,:g]]
[set_upper_bound(ND[r,g], abs(ub * d[:nd0][r,g])) for (r,g) in set[:r,:g]]
[set_upper_bound(DD[r,g], abs(ub * d[:dd0][r,g])) for (r,g) in set[:r,:g]]
[set_upper_bound(IMP[r,g], abs(ub * d[:m0][r,g])) for (r,g) in set[:r,:g]]
[set_upper_bound(SUP[r,g], abs(ub * d[:s0][r,g])) for (r,g) in set[:r,:g]]
[set_upper_bound(XD[r,g], abs(ub * d[:xd0][r,g])) for (r,g) in set[:r,:g]]
[set_upper_bound(XN[r,g], abs(ub * d[:xn0][r,g])) for (r,g) in set[:r,:g]]
[set_upper_bound(XPT[r,g], abs(ub * d[:x0][r,g])) for (r,g) in set[:r,:g]]
[set_upper_bound(RX[r,g], abs(ub * d[:rx0][r,g])) for (r,g) in set[:r,:g]]
[set_upper_bound(NM[r,g,m], abs(ub * d[:nm0][r,g,m])) for (r,g,m) in set[:r,:g,:m]]
[set_upper_bound(DM[r,g,m], abs(ub * d[:dm0][r,g,m])) for (r,g,m) in set[:r,:g,:m]]
[set_upper_bound(MARD[r,m,g], abs(ub * d[:md0][r,m,g])) for (r,m,g) in set[:r,:m,:g]]
[set_upper_bound(YH[r,g], abs(ub * d[:yh0][r,g])) for (r,g) in set[:r,:g]]
[set_upper_bound(CD[r,g], abs(ub * d[:cd0][r,g])) for (r,g) in set[:r,:g]]
[set_upper_bound(INV[r,g], abs(ub * d[:i0][r,g])) for (r,g) in set[:r,:g]]
[set_upper_bound(GD[r,g], abs(ub * d[:g0][r,g])) for (r,g) in set[:r,:g]]
[set_upper_bound(BOP[r], abs(ub * d[:bopdef0][r])) for (r) in set[:r]]