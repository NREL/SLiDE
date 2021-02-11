########## Model ##########
cge = MCPModel();


##############
# SETS
##############

# Set description
#set[:s] -> sectors
#set[:g] -> goods
#set[:r] -> regions
#set[:m] -> margins
#set[:gm] -> goods_margins
set[:uti] = ["uti"]
set[:nuti] = setdiff(set[:g],set[:uti])

##############
# PARAMETERS
##############

#benchmark values
@NLparameter(cge, ys0[r in set[:r], s in set[:s], g in set[:g]] == prep[:ys0][r,s,g]); # Sectoral supply
@NLparameter(cge, id0[r in set[:r], s in set[:s], g in set[:g]] == prep[:id0][r,s,g]); # Intermediate demand
@NLparameter(cge, ld0[r in set[:r], s in set[:s]] == prep[:ld0][r,s]); # Labor demand
@NLparameter(cge, kd0[r in set[:r], s in set[:s]] == prep[:kd0][r,s]); # Capital demand
@NLparameter(cge, ty0[r in set[:r], s in set[:s]] == prep[:ty0][r,s]); # Production tax (benchmark)
@NLparameter(cge, m0[r in set[:r], g in set[:g]] == prep[:m0][r,g]); # Imports
@NLparameter(cge, x0[r in set[:r], g in set[:g]] == prep[:x0][r,g]); # Exports of goods and services
@NLparameter(cge, rx0[r in set[:r], g in set[:g]] == prep[:rx0][r,g]); # Re-exports of goods and services
@NLparameter(cge, md0[r in set[:r], m in set[:m], g in set[:g]] == prep[:md0][r,m,g]); # Total margin demand
@NLparameter(cge, nm0[r in set[:r], g in set[:g], m in set[:m]] == prep[:nm0][r,g,m]); # Margin demand from national market
@NLparameter(cge, dm0[r in set[:r], g in set[:g], m in set[:m]] == prep[:dm0][r,g,m]); # Margin supply from local market
@NLparameter(cge, s0[r in set[:r], g in set[:g]] == prep[:s0][r,g]); # Aggregate supply
@NLparameter(cge, a0[r in set[:r], g in set[:g]] == prep[:a0][r,g]); # Armington supply
@NLparameter(cge, ta0[r in set[:r], g in set[:g]] == prep[:ta0][r,g]); # Tax net of subsidy rate on intermediate demand
@NLparameter(cge, tm0[r in set[:r], g in set[:g]] == prep[:tm0][r,g]); # Import tariff
@NLparameter(cge, cd0[r in set[:r], g in set[:g]] == prep[:cd0][r,g]); # Final demand
@NLparameter(cge, c0[r in set[:r]] == prep[:c0][r]); # Aggregate final demand
@NLparameter(cge, yh0[r in set[:r], g in set[:g]] == prep[:yh0][r,g]); #Household production
@NLparameter(cge, bopdef0[r in set[:r]] == prep[:bopdef0][r]); #Balance of payments
@NLparameter(cge, hhadj[r in set[:r]] == prep[:hhadj][r]); # Household adjustment
@NLparameter(cge, g0[r in set[:r], g in set[:g]] == prep[:g0][r,g]); # Government demand
@NLparameter(cge, i0[r in set[:r], g in set[:g]] == prep[:i0][r,g]); # Investment demand
@NLparameter(cge, xn0[r in set[:r], g in set[:g]] == prep[:xn0][r,g]); # Regional supply to national market
@NLparameter(cge, xd0[r in set[:r], g in set[:g]] == prep[:xd0][r,g]); # Regional supply to local market
@NLparameter(cge, dd0[r in set[:r], g in set[:g]] == prep[:dd0][r,g]); # Regional demand to local market
@NLparameter(cge, nd0[r in set[:r], g in set[:g]] == prep[:nd0][r,g]); # Regional demand to national market

#counterfactual taxes
@NLparameter(cge, ty[r in set[:r], s in set[:s]] == prep[:ty0][r,s]); # output tax
@NLparameter(cge, ta[r in set[:r], g in set[:g]] == prep[:ta0][r,g]); # Armington tax
@NLparameter(cge, tm[r in set[:r], g in set[:g]] == prep[:tm0][r,g]); # import tariff

# -- Major Assumptions --
# Temporal/Dynamic modifications

@NLparameter(cge, ir == prep[:ir]); # interest rate
@NLparameter(cge, gr == prep[:gr]); # growth rate --- try sector and set[:r] specific
@NLparameter(cge, dr == prep[:dr]); # capital depreciation rate
@NLparameter(cge, thetax == prep[:thetax]); # extant production share

#new capital endowment
@NLparameter(cge, ks_n[r in set[:r], s in set[:s]] ==
    value(kd0[r, s])  * (value(dr)+value(gr)) / (1 + value(gr)) );

# mutable old capital endowment
@NLparameter(cge, ks_s[r in set[:r], s in set[:s]] ==
    value(kd0[r, s]) * (1 - value(thetax)) - value(ks_n[r,s]) );

# Mutable total capital endowment - Non-extant capital
@NLparameter(cge, ks_m[r in set[:r]] == sum(value(kd0[r,s]) * (1-value(thetax)) for s in set[:s]));

# Extant capital endowment
@NLparameter(cge, ks_x[r in set[:r], s in set[:s]] ==
    value(kd0[r, s]) * value(thetax) );

# Benchmark investment supply
@NLparameter(cge, inv0[r in set[:r]] == sum(value(i0[r,g]) for g in set[:g]));


# --- Labor-leisure setup ---
# Labor endowment
@NLparameter(cge, le0[r in set[:r], s in set[:s]] == value(ld0[r,s]));
@NLparameter(cge, lab0[r in set[:r]] == sum(value(ld0[r,s]) for s in set[:s]));

# Benchmark labor tax rate
@NLparameter(cge, tl0[r in set[:r]] == 0);

# Benchmark leisure share of time endowment
@NLparameter(cge, theta_ll == 0.4);

# Benchmark time endowment
@NLparameter(cge, lte0[r in set[:r]] == value(lab0[r]) / (1-value(theta_ll)));

# Benchmark leisure endowment
@NLparameter(cge, leis0[r in set[:r]] == value(lte0[r]) - value(lab0[r]));

# Benchmark full consumption
@NLparameter(cge, z0[r in set[:r]] == value(c0[r]) + value(leis0[r]));

# Leisure share of full consumption
@NLparameter(cge, theta_lz[r in set[:r]] == value(leis0[r])/value(z0[r]));

# ------

# Benchmark welfare index
@NLparameter(cge, w0[r in set[:r]] == value(inv0[r])+value(z0[r]));


# benchmark value share parameters
@NLparameter(cge, alpha_kl[r in set[:r], s in set[:s]] == ensurefinite(value(ld0[r,s]) / (value(ld0[r,s]) + value(kd0[r,s]))));
@NLparameter(cge, alpha_x[r in set[:r], g in set[:g]] == ensurefinite((value(x0[r,g]) - value(rx0[r,g])) / value(s0[r,g])));
@NLparameter(cge, alpha_d[r in set[:r], g in set[:g]] == ensurefinite(value(xd0[r,g]) / value(s0[r,g])));
@NLparameter(cge, alpha_n[r in set[:r], g in set[:g]] == ensurefinite(value(xn0[r,g]) / value(s0[r,g])));
@NLparameter(cge, theta_n[r in set[:r], g in set[:g]] == ensurefinite(value(nd0[r,g]) / (value(nd0[r,g]) - value(dd0[r,g]))));
@NLparameter(cge, theta_m[r in set[:r], g in set[:g]] == ensurefinite((1+value(tm0[r,g])) * value(m0[r,g]) / (value(nd0[r,g]) + value(dd0[r,g]) + (1 + value(tm0[r,g])) * value(m0[r,g]))));

@NLparameter(cge, theta_inv[r in set[:r], g in set[:g]] == value(i0[r,g]) / value(inv0[r])); # Intermediate input share of investment output

@NLparameter(cge, theta_cd[r in set[:r], g in set[:g]] == ensurefinite(value(cd0[r,g]) / sum(value(cd0[r,gg]) for gg in set[:g]))); # final consumption input demand shares

#Substitution and transformation elasticities
@NLparameter(cge, es_va[r in set[:r], s in set[:s]] == SUB_ELAST[:va]); # value-added nest - substitution elasticity
@NLparameter(cge, es_y[r in set[:r], s in set[:s]]  == SUB_ELAST[:y]); # Top-level Y nest (VA,M) - substitution elasticity
@NLparameter(cge, es_m[r in set[:r], s in set[:s]]  == SUB_ELAST[:m]); # Materials nest - substitution elasticity
@NLparameter(cge, et_x[r in set[:r], g in set[:g]]    == TRANS_ELAST[:x]); # Disposition, distribute regional supply to local, national, export - transformation elasticity
@NLparameter(cge, es_a[r in set[:r], g in set[:g]]    == SUB_ELAST[:a]); # Top-level A nest for aggregate demand (set[:m], set[:g]) - substitution elasticity
@NLparameter(cge, es_mar[r in set[:r], g in set[:g]]  == SUB_ELAST[:mar]); # Margin supply - substitution elasticity
@NLparameter(cge, es_d[r in set[:r], g in set[:g]]    == SUB_ELAST[:d]); # Domestic demand aggregation nest (intranational) - substitution elasticity
@NLparameter(cge, es_f[r in set[:r], g in set[:g]]    == SUB_ELAST[:f]); # Domestic and foreign demand aggregation nest (international) - substitution elasticity

@NLparameter(cge, es_inv[r in set[:r]] == 5); # Investment production - substitution elasticity

@NLparameter(cge, es_cd == 0.99); # Consumption - substitution elasticity - approximate to 1

# Calibrate subsitution elasticity between leisure and consumption
# based on uncompensated elasticity of labor supply
@NLparameter(cge, ulse == 0.05); # uncompensated labor supply elasticity
@NLparameter(cge, es_z[r in set[:r]] == 1 + (value(ulse) / value(theta_lz[r]))); # final consumption nest - substitution elasticity

# Autonomous energy efficienty improvements (aeei)
@NLparameter(cge, aeeigr[r in set[:r], g in set[:g]] == 0.0); # improvement rate
@NLparameter(cge, aeeigrcd[r in set[:r]] == 0.0); # improvement rate for final consumption
@NLparameter(cge, aeei[r in set[:r], g in set[:g]] == 1); # growth factor
@NLparameter(cge, aeeicd[r in set[:r]] == 1); # growth factor for final consumption

# for r in set[:r]
#     for g in set[:g]
#         set_value(aeeigr[r,g], 0.01);
#     end
#     set_value(aeeigrcd[r], 0.01);
# end


################
# VARIABLES
################

# specify lower bound
lo = 0.0

# sectors
#@variable(cge, Y[(r, s) in set[:Y]] >= lo, start = 1);
@variable(cge, X[(r, g) in set[:X]] >= lo, start = vrep[:X][(r,g)]); # Exports
@variable(cge, A[(r, g) in set[:A]] >= lo, start = vrep[:A][(r,g)]); # Armington
@variable(cge, C[r in set[:r]] >= lo, start = vrep[:C][r]); # Consumption
@variable(cge, MS[r in set[:r], m in set[:m]] >= lo, start = vrep[:MS][r,m]); # Margin Supply

#commodities:
@variable(cge, PA[(r, g) in set[:PA]] >= lo, start = vrep[:PA][(r,g)]); # Regional market (input)
@variable(cge, PY[(r, g) in set[:PY]] >= lo, start = vrep[:PY][(r,g)]); # Regional market (output)
@variable(cge, PD[(r, g) in set[:PD]] >= lo, start = vrep[:PD][(r,g)]); # Local market price
@variable(cge, PN[g in set[:g]] >= lo, start = vrep[:PN][g]); # National market
#@variable(cge, PK[(r, s) in set[:PK]] >= lo, start =1); # Rental rate of capital ###
@variable(cge, PM[r in set[:r], m in set[:m]] >= lo, start = vrep[:PM][r,m]); # Margin price
@variable(cge, PC[r in set[:r]] >= lo, start = vrep[:PC][r]); # Consumer price index #####
@variable(cge, PFX >= lo, start = vrep[:PFX]); # Foreign exchange

#consumer:
@variable(cge,RA[r in set[:r]]>=lo,start = vrep[:RA][r]);


#--- recursive dynamic variable declaration ---
# sectors
@variable(cge,YM[(r,s) in set[:Y]] >= lo, start = vrep[:YM][(r,s)]); # Mutable production index - replaces Y
@variable(cge,YX[(r,s) in set[:Y]] >= lo, start = vrep[:YX][(r,s)]); # Extant production index
@variable(cge,INV[r in set[:r]] >= lo, start = vrep[:INV][r]); # Investment

# commodities
@variable(cge,RKX[(r,s) in set[:PK]] >= lo, start = vrep[:RKX][(r,s)]); # Return to extant capital
@variable(cge,RK[r in set[:r]] >= lo, start = vrep[:RK][r]); # Return to regional capital
@variable(cge,PINV[r in set[:r]] >= lo, start = vrep[:PINV][r]); # Investment price index
@variable(cge,PW[r in set[:r]] >= lo, start = vrep[:PW][r]); # Welfare price index

# Reporting variables
@variable(cge,DKM[(r,s) in set[:PK]] >= lo, start = start_value(YM[(r,s)]) * value(kd0[r,s]));

#--- Labor-leisure variable declaration ---
# sectors
@variable(cge, LS[r in set[:r]] >= lo, start = vrep[:LS][r]); # Labor supply
@variable(cge, Z[r in set[:r]] >= lo, start = vrep[:Z][r]); # Full consumption

# commodities
@variable(cge, PL[r in set[:r]] >= lo, start = vrep[:PL][r]); # Wage rate (after tax)
@variable(cge, PLS[r in set[:r]] >= lo, start = vrep[:PLS][r]); # Wage rate (before tax)
@variable(cge, PZ[r in set[:r]] >= lo, start = vrep[:PZ][r]); # Full consumption price index

@variable(cge,W[r in set[:r]] >= lo, start = vrep[:W][r]); # Welfare index

###############################
# -- PLACEHOLDER VARIABLES --
###############################

#----------
### Recursive Model expressions

#Cobb-douglas for mutable/new
@NLexpression(cge, CVAym[r in set[:r], s in set[:s]],
    PLS[r]^alpha_kl[r,s] * RK[r]^(1-alpha_kl[r,s]));

#demand for labor in VA
@NLexpression(cge,ALym[r in set[:r], s in set[:s]],
    ld0[r,s] * CVAym[r,s] / PLS[r]);

#demand for capital in VA
@NLexpression(cge,AKym[r in set[:r],s in set[:s]],
    kd0[r,s] * CVAym[r,s] / RK[r]);

#demand for investment
@NLexpression(cge,DINV[r in set[:r], g in set[:g]],
    (i0[r,g] * (PINV[r]/(haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0)^es_inv[r])));

# Unit cost for full consumption
@NLexpression(cge, CZ[r in set[:r]],
    (theta_lz[r]*PL[r]^(1-es_z[r]) + (1-theta_lz[r])*PC[r]^(1-es_z[r]))^(1/(1-es_z[r])));

# Leisure demand
@NLexpression(cge, DLEIS[r in set[:r]],
    leis0[r]*(CZ[r]/PL[r])^(es_z[r]));

# Consumption demand
@NLexpression(cge, DCONS[r in set[:r]],
    c0[r]*(CZ[r]/PC[r])^(es_z[r]));


# unit cost for consumption
@NLexpression(cge, CC[r in set[:r]],
    sum( theta_cd[r,gg]*(haskey(PA.lookup[1], (r, gg)) ? PA[(r, gg)] : 1.0)^(1-es_cd) for gg in set[:g])^(1/(1-es_cd))
);

# final demand
@NLexpression(cge,CD[r in set[:r],g in set[:g]],
    (cd0[r,g]*(CC[r] / (haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0))^es_cd));
#  cd0[r,g]*PC[r] / (haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0));


#----------

#CES function for output demand - including
# exports (absent of re-exports) times the price for foreign exchange,
# region's supply to national market times the national market price
# regional supply to local market times domestic price
@NLexpression(cge,RX[r in set[:r],g in set[:g]],
  (alpha_x[r,g]*PFX^(1+et_x[r,g])+alpha_n[r,g]*PN[g]^(1+et_x[r,g])+alpha_d[r,g]*(haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0)^(1+et_x[r,g]))^(1/(1+et_x[r,g])) );

#demand for exports via demand function
@NLexpression(cge,AX[r in set[:r],g in set[:g]], (x0[r,g] - rx0[r,g])*(PFX/RX[r,g])^et_x[r,g] );

#demand for contribution to national market
@NLexpression(cge,AN[r in set[:r],g in set[:g]], xn0[r,g]*(PN[g]/(RX[r,g]))^et_x[r,g] );

#demand for regionals supply to local market
@NLexpression(cge,AD[r in set[:r],g in set[:g]],
  xd0[r,g] * ((haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0) / (RX[r,g]))^et_x[r,g] );

  ###

# CES function for tradeoff between national and domestic market
@NLexpression(cge,CDN[r in set[:r],g in set[:g]],
  (theta_n[r,g]*PN[g]^(1-es_d[r,g])+(1-theta_n[r,g])*(haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0)^(1-es_d[r,g]))^(1/(1-es_d[r,g])) );

# CES function for tradeoff between domestic consumption and foreign exports
# recall tm in the import tariff thus tm / tm0 is the relative change in import tariff rates
@NLexpression(cge,CDM[r in set[:r],g in set[:g]],
  ((1-theta_m[r,g])*CDN[r,g]^(1-es_f[r,g])+theta_m[r,g]*(PFX*(1+tm[r,g])/(1+tm0[r,g]))^(1-es_f[r,g]))^(1/(1-es_f[r,g])) );

# set[:r] demand from the national market <- note nesting of CDN in CDM
@NLexpression(cge,DN[r in set[:r],g in set[:g]],
  nd0[r,g]*(CDN[r,g]/PN[g])^es_d[r,g]*(CDM[r,g]/CDN[r,g])^es_f[r,g] );

# region demand from local market <- note nesting of CDN in CDM
@NLexpression(cge,DD[r in set[:r],g in set[:g]],
  dd0[r,g]*(CDN[r,g]/(haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0))^es_d[r,g]*(CDM[r,g]/CDN[r,g])^es_f[r,g] );

# import demand
@NLexpression(cge,MD[r in set[:r],g in set[:g]],
  m0[r,g]*(CDM[r,g]*(1+tm[r,g])/(PFX*(1+tm0[r,g])))^es_f[r,g] );



###############################
# -- Zero Profit Conditions --
###############################

#----------
#Recursive  --- update to Y
@mapping(cge,profit_ym[(r, s) in set[:Y]],
# cost of intermediate demand
    sum((haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * id0[r,g,s] for g in set[:g])
# cost of labor inputs
    + PLS[r] * ALym[r,s]
# cost of capital inputs
    + RK[r] * AKym[r,s]
    -
# revenue from sectoral supply (take note of r/s/g indices on ys0)
    sum((haskey(PY.lookup[1], (r, g)) ? PY[(r, g)] : 1.0)  * ys0[r,s,g] for g in set[:g]) * (1-ty[r,s])
);

@mapping(cge,profit_yx[(r, s) in set[:Y]],
# cost of intermediate demand
    sum((haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * id0[r,g,s] for g in set[:g])
# cost of labor inputs
    + PLS[r] * ld0[r,s]
# cost of capital inputs
    + (haskey(RKX.lookup[1], (r, s)) ? RKX[(r,s)] : 1.0) * kd0[r,s]
    -
# revenue from sectoral supply (take note of r/s/g indices on ys0)
    sum((haskey(PY.lookup[1], (r, g)) ? PY[(r, g)] : 1.0)  * ys0[r,s,g] for g in set[:g]) * (1-ty[r,s])
);

#----------

@mapping(cge,profit_x[(r, g) in set[:X]],
# output 'cost' from aggregate supply
    (haskey(PY.lookup[1], (r, g)) ? PY[(r, g)] : 1.0) * s0[r,g]
    - (
# revenues from foreign exchange
        PFX * AX[r,g]
# revenues from national market
        + PN[g] * AN[r,g]
# revenues from domestic market
        + (haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0) * AD[r,g]
    )
);


@mapping(cge,profit_a[(r, g) in set[:A]],
# costs from national market
    PN[g] * DN[r,g]
# costs from domestic market
    + (haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0) * DD[r,g]
# costs from imports, including import tariff
    + PFX * (1+tm[r,g]) * MD[r,g]
# costs of margin demand
    + sum(PM[r,m] * md0[r,m,g] for m in set[:m])
    - (
# revenues from regional market based on armington supply
       (haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * (1-ta[r,g]) * a0[r,g]
# revenues from re-exports
        + PFX * rx0[r,g]
    )
);

@mapping(cge, profit_c[r in set[:r]],
# costs of inputs - computed as final demand times regional market prices
    sum((haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * CD[r,g] for g in set[:g])
    -
# revenues/benefit computed as CPI * reference consumption
    PC[r] * c0[r]
);

# Full consumption
@mapping(cge, profit_z[r in set[:r]],
    PC[r]*DCONS[r] + PL[r]*DLEIS[r]
    -
    PZ[r]*z0[r]
);

# Labor supply
@mapping(cge, profit_ls[r in set[:r]],
    PL[r]*lab0[r]
    -
    PLS[r]*lab0[r]
);


@mapping(cge, profit_inv[r in set[:r]],
# inputs to investment
    sum((haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * DINV[r,g] for g in set[:g])
    -
# Investment
    PINV[r] * inv0[r]
);

@mapping(cge, profit_w[r in set[:r]],
# inputs to welfare index
    PINV[r]*inv0[r] + PZ[r]*z0[r]
    -
# Welfare
    PW[r]*w0[r]
);

@mapping(cge,profit_ms[r in set[:r], m in set[:m]],
# provision of set[:m] to national market
    sum(PN[gm]   * nm0[r,gm,m] for gm in set[:gm])
# provision of set[:m] to domestic market
    + sum((haskey(PD.lookup[1], (r, gm)) ? PD[(r, gm)] : 1.0) * dm0[r,gm,m] for gm in set[:gm])
    -
# total margin demand
    PM[r,m] * sum(md0[r,m,gm] for gm in set[:gm])
);


###################################
# -- Market Clearing Conditions --
###################################

#----------
#Recursive dynamics mkt clearance

@mapping(cge,market_rk[r in set[:r]],
# mutable capital supply
    ks_m[r]
    -
# mutable capital demand
    sum((haskey(YM.lookup[1], (r, s)) ? YM[(r, s)] : 1.0) * AKym[r,s] for s in set[:s])
);

@mapping(cge,market_rkx[(r, s) in set[:PK]],
# extant capital supply
    (ks_x[r,s])
    -
# extant capital demand
    (haskey(YX.lookup[1], (r, s)) ? YX[(r, s)] : 1.) * kd0[r,s]
);

@mapping(cge,market_pa[(r, g) in set[:PA]],
# absorption or supply
    (haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.) * a0[r,g]
    - (
# government demand (exogenous)
        g0[r,g]
# demand for investment
        + INV[r]*DINV[r,g]
# final demand
        + C[r] * CD[r,g]
# intermediate demand
        + sum((haskey(YM.lookup[1], (r, s)) ? YM[(r, s)] : 1) * id0[r,g,s] for s in set[:s] if (r,s) in set[:Y])
        + sum((haskey(YX.lookup[1], (r, s)) ? YX[(r, s)] : 1) * id0[r,g,s] for s in set[:s] if (r,s) in set[:Y])
    )
);

@mapping(cge,market_py[(r, g) in set[:PY]],
# sectoral supply
    sum((haskey(YM.lookup[1], (r, s)) ? YM[(r, s)] : 0.0) *ys0[r,s,g] for s in set[:s])
    + sum((haskey(YX.lookup[1], (r, s)) ? YX[(r, s)] : 0.0) *ys0[r,s,g] for s in set[:s])
# household production (exogenous)
    + yh0[r,g]
    -
# aggregate supply (akin to market demand)
    (haskey(X.lookup[1], (r, g)) ? X[(r, g)] : 1) * s0[r,g]
);


#----------


@mapping(cge,market_pd[(r, g) in set[:PD]],
# aggregate supply
    (haskey(X.lookup[1], (r, g)) ? X[(r, g)] : 1)  * AD[r,g]
    - (
# demand for local market
        (haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.) * DD[r,g]
# margin formulation from local market
        + sum(MS[r,m] * dm0[r,g,m] for m in set[:m] if (g in set[:gm] ) )
    )
);

@mapping(cge,market_pn[g in set[:g]],
# supply to the national market
    sum((haskey(X.lookup[1], (r, g)) ? X[(r, g)] : 1)  * AN[r,g] for r in set[:r])
    - (
# demand from the national market
        sum((haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.) * DN[r,g] for r in set[:r])
# margin formulation from the national market
        + sum(MS[r,m] * nm0[r,g,m] for r in set[:r] for m in set[:m] if (g in set[:gm]) )
    )
);


@mapping(cge,market_pm[r in set[:r], m in set[:m]],
# margin supply
    MS[r,m] * sum(md0[r,m,gm] for gm in set[:gm])
    -
# margin demand
    sum((haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.0) * md0[r,m,g] for g in set[:g])
);

@mapping(cge,market_pc[r in set[:r]],
# Consumption supply
    C[r] * c0[r]
    -
# Consumption demand
    Z[r]*DCONS[r]
);

@mapping(cge,market_pls[r in set[:r]],
# labor supply
    LS[r]*lab0[r]
    -
# demand for labor in all set[:s]
    (
        sum((haskey(YM.lookup[1], (r, s)) ? YM[(r, s)] : 1) * ALym[r,s] for s in set[:s])
        + sum((haskey(YX.lookup[1], (r, s)) ? YX[(r, s)] : 1) * ld0[r,s] for s in set[:s])
    )
);

@mapping(cge,market_pl[r in set[:r]],
# time endowment - supply
    lte0[r]
    -
# demand for time
    (
        LS[r]*lab0[r]
        + Z[r]*DLEIS[r]
    )
);

@mapping(cge,market_pz[r in set[:r]],
# supply of full consumption good
    Z[r]*z0[r]
    -
# demand for full consumption
    W[r]*z0[r]
);

@mapping(cge, market_pinv[r in set[:r]],
# investment supply
    INV[r]*inv0[r]
    -
# investment demanded
    W[r]*inv0[r]
);

@mapping(cge, market_pw[r in set[:r]],
# welfare supply
    W[r]*w0[r]
    -
# full consumption welfare / utility
    RA[r] / PW[r]
);

@mapping(cge,market_pfx,
# balance of payments (exogenous)
    sum(bopdef0[r] for r in set[:r])
# supply of exports
    + sum((haskey(X.lookup[1], (r, g)) ? X[(r, g)] : 1.0)  * AX[r,g] for r in set[:r] for g in set[:g])
# supply of re-exports
    + sum((haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.0) * rx0[r,g] for r in set[:r] for g in set[:g] if (r,g) in set[:A])
    -
# import demand
    sum((haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.0) * MD[r,g] for r in set[:r] for g in set[:g] if (r,g) in set[:A])
);


#----------
#Income balance update for recursive dynamics
@mapping(cge,income_ra[r in set[:r]],
# consumption/utility
    RA[r]
    -
    (
# # labor income
#         PL[r] * sum(le0[r,s] for s in set[:s])
# value of time endowment
        PL[r]*lte0[r]
# capital income
        + RK[r] * ks_m[r]
        +sum((haskey(RKX.lookup[1], (r, s)) ? RKX[(r,s)] : 1.0) * ks_x[r,s] for s in set[:s])
# provision of household supply
        + sum( (haskey(PY.lookup[1], (r, g)) ? PY[(r, g)] : 1.0) * yh0[r,g] for g in set[:g])
# revenue or costs of foreign exchange including household adjustment
        + PFX * (bopdef0[r] + hhadj[r])
# government provision
        - sum((haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * (g0[r,g]) for g in set[:g])
# import taxes - assumes lumpsum recycling
        + sum((haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.) * MD[r,g] * PFX * tm[r,g] for g in set[:g] if (r,g) in set[:A])
# taxes on intermediate demand - assumes lumpsum recycling
        + sum((haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.) * a0[r,g]*(haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0)*ta[r,g] for g in set[:g] if (r,g) in set[:A])
# production taxes - assumes lumpsum recycling
        + sum( (haskey(YM.lookup[1], (r, s)) ? YM[(r, s)] : 1) * ys0[r,s,g] * ty[r,s] for s in set[:s], g in set[:g])
        + sum( (haskey(YX.lookup[1], (r, s)) ? YX[(r, s)] : 1) * ys0[r,s,g] * ty[r,s] for s in set[:s], g in set[:g])
    )
);

#----------
# Reporting
@mapping(cge, DKMdef[(r,s) in set[:PK]],
    DKM[(r,s)]
    -
    YM[(r,s)]*AKym[r,s]
);

####################################
# -- Complementarity Conditions --
####################################

# define complementarity conditions
# note the pattern of ZPC -> primal variable  &  MCC -> dual variable (price)
#@complementarity(cge,profit_y,Y);
@complementarity(cge,profit_ym,YM);
@complementarity(cge,profit_yx,YX);
@complementarity(cge,profit_x,X);
@complementarity(cge,profit_a,A);
@complementarity(cge,profit_c,C);
@complementarity(cge,profit_ms,MS);
@complementarity(cge,market_pa,PA);
@complementarity(cge,market_py,PY);
@complementarity(cge,market_pd,PD);
@complementarity(cge,market_pn,PN);
@complementarity(cge,market_pl,PL);
#@complementarity(cge,market_pk,PK);
@complementarity(cge,market_rk,RK);
@complementarity(cge,market_rkx,RKX);
@complementarity(cge,market_pm,PM);
@complementarity(cge,market_pc,PC);
@complementarity(cge,market_pfx,PFX);
@complementarity(cge,income_ra,RA);

#----------
#Recursive Dynamics
@complementarity(cge,profit_inv,INV);
@complementarity(cge,profit_w,W);
@complementarity(cge,market_pinv,PINV);
@complementarity(cge,market_pw,PW);

#Reporting
@complementarity(cge,DKMdef,DKM);

#----------
#Labor-Leisure
@complementarity(cge,profit_z,Z);
@complementarity(cge,profit_ls,LS);
@complementarity(cge,market_pls,PLS);
@complementarity(cge,market_pz,PZ);
