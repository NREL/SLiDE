####################################
#
# Recursive dynamic extension of SLiDE model
#
####################################

using SLiDE
using CSV
using JuMP
using Complementarity
using DataFrames


############
# LOAD DATA
############

#SLiDE data needs to be built or point to pre-existing build directory
#can pass a name (d, set) = build_data("name_of_build_directory")
!(@isdefined(d_in) && @isdefined(set_in)) && ((d_in, set_in) = build("state_model"))
d = copy(d_in)
set = copy(set_in)

#Specify benchmark year - this is the first solve year where the benchmark replicated
bmkyr = 2016

#Load slide data and time horizon to produce model data and appropriate time-indexed subsets
(sld, set, idx) = model_input(bmkyr, d, set)


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


##############
# PARAMETERS
##############

#benchmark values
@NLparameter(cge, ys0[r in set[:r], s in set[:s], g in set[:g]] == sld[:ys0][r,s,g]); # Sectoral supply
@NLparameter(cge, id0[r in set[:r], s in set[:s], g in set[:g]] == sld[:id0][r,s,g]); # Intermediate demand
@NLparameter(cge, ld0[r in set[:r], s in set[:s]] == sld[:ld0][r,s]); # Labor demand
@NLparameter(cge, kd0[r in set[:r], s in set[:s]] == sld[:kd0][r,s]); # Capital demand
@NLparameter(cge, ty0[r in set[:r], s in set[:s]] == sld[:ty0][r,s]); # Production tax (benchmark)
@NLparameter(cge, m0[r in set[:r], g in set[:g]] == sld[:m0][r,g]); # Imports
@NLparameter(cge, x0[r in set[:r], g in set[:g]] == sld[:x0][r,g]); # Exports of goods and services
@NLparameter(cge, rx0[r in set[:r], g in set[:g]] == sld[:rx0][r,g]); # Re-exports of goods and services
@NLparameter(cge, md0[r in set[:r], m in set[:m], g in set[:g]] == sld[:md0][r,m,g]); # Total margin demand
@NLparameter(cge, nm0[r in set[:r], g in set[:g], m in set[:m]] == sld[:nm0][r,g,m]); # Margin demand from national market
@NLparameter(cge, dm0[r in set[:r], g in set[:g], m in set[:m]] == sld[:dm0][r,g,m]); # Margin supply from local market
@NLparameter(cge, s0[r in set[:r], g in set[:g]] == sld[:s0][r,g]); # Aggregate supply
@NLparameter(cge, a0[r in set[:r], g in set[:g]] == sld[:a0][r,g]); # Armington supply
@NLparameter(cge, ta0[r in set[:r], g in set[:g]] == sld[:ta0][r,g]); # Tax net of subsidy rate on intermediate demand
@NLparameter(cge, tm0[r in set[:r], g in set[:g]] == sld[:tm0][r,g]); # Import tariff
@NLparameter(cge, cd0[r in set[:r], g in set[:g]] == sld[:cd0][r,g]); # Final demand
@NLparameter(cge, c0[r in set[:r]] == sld[:c0][r]); # Aggregate final demand
@NLparameter(cge, yh0[r in set[:r], g in set[:g]] == sld[:yh0][r,g]); #Household production
@NLparameter(cge, bopdef0[r in set[:r]] == sld[:bopdef0][r]); #Balance of payments
@NLparameter(cge, hhadj[r in set[:r]] == sld[:hhadj][r]); # Household adjustment
@NLparameter(cge, g0[r in set[:r], g in set[:g]] == sld[:g0][r,g]); # Government demand
@NLparameter(cge, i0[r in set[:r], g in set[:g]] == sld[:i0][r,g]); # Investment demand
@NLparameter(cge, xn0[r in set[:r], g in set[:g]] == sld[:xn0][r,g]); # Regional supply to national market
@NLparameter(cge, xd0[r in set[:r], g in set[:g]] == sld[:xd0][r,g]); # Regional supply to local market
@NLparameter(cge, dd0[r in set[:r], g in set[:g]] == sld[:dd0][r,g]); # Regional demand to local market
@NLparameter(cge, nd0[r in set[:r], g in set[:g]] == sld[:nd0][r,g]); # Regional demand to national market

#counterfactual taxes
@NLparameter(cge, ty[r in set[:r], s in set[:s]] == sld[:ty0][r,s]); # output tax
@NLparameter(cge, ta[r in set[:r], g in set[:g]] == sld[:ta0][r,g]); # Armington tax
@NLparameter(cge, tm[r in set[:r], g in set[:g]] == sld[:tm0][r,g]); # import tariff

# -- Major Assumptions --
# Temporal/Dynamic modifications

@NLparameter(cge, ir == 0.05); # interest rate
@NLparameter(cge, gr == 0.02); # growth rate --- try sector and set[:r] specific
@NLparameter(cge, dr == 0.05); # capital depreciation rate
@NLparameter(cge, thetax == 0.3); # extant production share

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

# Labor endowment
@NLparameter(cge, le0[r in set[:r], s in set[:s]] == value(ld0[r,s]));

# Benchmark investment supply
@NLparameter(cge, inv0[r in set[:r]] == sum(value(i0[r,g]) for g in set[:g]));

# Benchmark welfare index
@NLparameter(cge, w0[r in set[:r]] == value(inv0[r])+value(c0[r]));

# benchmark value share parameters
@NLparameter(cge, alpha_kl[r in set[:r], s in set[:s]] == ensurefinite(value(ld0[r,s]) / (value(ld0[r,s]) + value(kd0[r,s]))));
@NLparameter(cge, alpha_x[r in set[:r], g in set[:g]] == ensurefinite((value(x0[r,g]) - value(rx0[r,g])) / value(s0[r,g])));
@NLparameter(cge, alpha_d[r in set[:r], g in set[:g]] == ensurefinite(value(xd0[r,g]) / value(s0[r,g])));
@NLparameter(cge, alpha_n[r in set[:r], g in set[:g]] == ensurefinite(value(xn0[r,g]) / value(s0[r,g])));
@NLparameter(cge, theta_n[r in set[:r], g in set[:g]] == ensurefinite(value(nd0[r,g]) / (value(nd0[r,g]) - value(dd0[r,g]))));
@NLparameter(cge, theta_m[r in set[:r], g in set[:g]] == ensurefinite((1+value(tm0[r,g])) * value(m0[r,g]) / (value(nd0[r,g]) + value(dd0[r,g]) + (1 + value(tm0[r,g])) * value(m0[r,g]))));

@NLparameter(cge, theta_inv[r in set[:r], g in set[:g]] == value(i0[r,g]) / value(inv0[r])); # Intermediate input share of investment output

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


################
# VARIABLES
################

# specify lower bound
lo = 0.0

# sectors
#@variable(cge, Y[(r, s) in set[:Y]] >= lo, start = 1);
@variable(cge, X[(r, g) in set[:X]] >= lo, start = 1); # Exports
@variable(cge, A[(r, g) in set[:A]] >= lo, start = 1); # Armington
@variable(cge, C[r in set[:r]] >= lo, start = 1); # Consumption
@variable(cge, MS[r in set[:r], m in set[:m]] >= lo, start = 1); # Margin Supply

#commodities:
@variable(cge, PA[(r, g) in set[:PA]] >= lo, start = 1); # Regional market (input)
@variable(cge, PY[(r, g) in set[:PY]] >= lo, start = 1); # Regional market (output)
@variable(cge, PD[(r, g) in set[:PD]] >= lo, start = 1); # Local market price
@variable(cge, PN[g in set[:g]] >= lo, start =1); # National market
@variable(cge, PL[r in set[:r]] >= lo, start = 1); # Wage rate
#@variable(cge, PK[(r, s) in set[:PK]] >= lo, start =1); # Rental rate of capital ###
@variable(cge, PM[r in set[:r], m in set[:m]] >= lo, start =1); # Margin price
@variable(cge, PC[r in set[:r]] >= lo, start = 1); # Consumer price index #####
@variable(cge, PFX >= lo, start = 1); # Foreign exchange

#consumer:
@variable(cge,RA[r in set[:r]]>=lo,start = value(w0[r])) ;


#--- recursive dynamic variable declaration ---
# sectors
@variable(cge,YM[(r,s) in set[:Y]] >= lo, start = (1-value(thetax))); # Mutable production index - replaces Y
@variable(cge,YX[(r,s) in set[:Y]] >= lo, start = value(thetax)); # Extant production index
@variable(cge,INV[r in set[:r]] >= lo, start = 1); # Investment
@variable(cge,W[r in set[:r]] >= lo, start = 1); # Welfare index

# commodities
@variable(cge,RKX[(r,s) in set[:PK]] >= lo, start = 1); # Return to extant capital
@variable(cge,RK[r in set[:r]] >= lo, start = 1); # Return to regional capital
@variable(cge,PINV[r in set[:r]] >= lo, start = 1); # Investment price index
@variable(cge,PW[r in set[:r]] >= lo, start = 1); # Welfare price index

# Reporting variables
@variable(cge,DKM[(r,s) in set[:PK]] >= lo, start = start_value(YM[(r,s)]) * value(kd0[r,s]));


###############################
# -- PLACEHOLDER VARIABLES --
###############################

#----------
### Recursive Model expressions

#Cobb-douglas for mutable/new
@NLexpression(cge, CVAym[r in set[:r], s in set[:s]],
    PL[r]^alpha_kl[r,s] * RK[r]^(1-alpha_kl[r,s]));

#demand for labor in VA
@NLexpression(cge,ALym[r in set[:r], s in set[:s]],
    ld0[r,s] * CVAym[r,s] / PL[r]);

#demand for capital in VA
@NLexpression(cge,AKym[r in set[:r],s in set[:s]],
    kd0[r,s] * CVAym[r,s] / RK[r]);

@NLexpression(cge,DINV[r in set[:r], g in set[:g]],
    (i0[r,g] * (PINV[r]/(haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0)^es_inv[r])));

#----------

#CES function for output demand - including
# exports (absent of re-exports) times the price for foreign exchange,
# region's supply to national market times the national market price
# regional supply to local market times domestic price
@NLexpression(cge,RX[r in set[:r],g in set[:g]],
  (alpha_x[r,g]*PFX^5+alpha_n[r,g]*PN[g]^5+alpha_d[r,g]*(haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0)^5)^(1/5) );

#demand for exports via demand function
@NLexpression(cge,AX[r in set[:r],g in set[:g]], (x0[r,g] - rx0[r,g])*(PFX/RX[r,g])^4 );

#demand for contribution to national market
@NLexpression(cge,AN[r in set[:r],g in set[:g]], xn0[r,g]*(PN[g]/(RX[r,g]))^4 );

#demand for regionals supply to local market
@NLexpression(cge,AD[r in set[:r],g in set[:g]],
  xd0[r,g] * ((haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0) / (RX[r,g]))^4 );

  ###

# CES function for tradeoff between national and domestic market
@NLexpression(cge,CDN[r in set[:r],g in set[:g]],
  (theta_n[r,g]*PN[g]^(1-2)+(1-theta_n[r,g])*(haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0)^(1-2))^(1/(1-2)) );

# CES function for tradeoff between domestic consumption and foreign exports
# recall tm in the import tariff thus tm / tm0 is the relative change in import tariff rates
@NLexpression(cge,CDM[r in set[:r],g in set[:g]],
  ((1-theta_m[r,g])*CDN[r,g]^(1-4)+theta_m[r,g]*(PFX*(1+tm[r,g])/(1+tm0[r,g]))^(1-4))^(1/(1-4)) );

# set[:r] demand from the national market <- note nesting of CDN in CDM
@NLexpression(cge,DN[r in set[:r],g in set[:g]],
  nd0[r,g]*(CDN[r,g]/PN[g])^2*(CDM[r,g]/CDN[r,g])^4 );

# region demand from local market <- note nesting of CDN in CDM
@NLexpression(cge,DD[r in set[:r],g in set[:g]],
  dd0[r,g]*(CDN[r,g]/(haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0))^2*(CDM[r,g]/CDN[r,g])^4 );

# import demand
@NLexpression(cge,MD[r in set[:r],g in set[:g]],
  m0[r,g]*(CDM[r,g]*(1+tm[r,g])/(PFX*(1+tm0[r,g])))^4 );

# final demand
@NLexpression(cge,CD[r in set[:r],g in set[:g]],
  cd0[r,g]*PC[r] / (haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) );


###############################
# -- Zero Profit Conditions --
###############################

#----------
#Recursive  --- update to Y
@mapping(cge,profit_ym[(r, s) in set[:Y]],
# cost of intermediate demand
    sum((haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * id0[r,g,s] for g in set[:g])
# cost of labor inputs
    + PL[r] * ALym[r,s]
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
    + PL[r] * ld0[r,s]
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

@mapping(cge, profit_inv[r in set[:r]],
# inputs to investment
    sum((haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * DINV[r,g] for g in set[:g])
    -
# Investment
    PINV[r] * inv0[r]
);

@mapping(cge, profit_w[r in set[:r]],
# inputs to welfare index
    PINV[r]*inv0[r] + PC[r]*c0[r]
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

@mapping(cge,market_pl[r in set[:r]],
# supply of labor
    sum(le0[r,s] for s in set[:s])
    -
# demand for labor in all set[:s]
    (
        sum((haskey(YM.lookup[1], (r, s)) ? YM[(r, s)] : 1) * ALym[r,s] for s in set[:s])
        + sum((haskey(YX.lookup[1], (r, s)) ? YX[(r, s)] : 1) * ld0[r,s] for s in set[:s])
    )
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
    W[r] * c0[r]
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
# labor income
        PL[r] * sum(le0[r,s] for s in set[:s])
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

####################
# -- Model Solve --
####################

#set up the options for the path solver
PATHSolver.options(convergence_tolerance=1e-6, output=:yes, time_limit=3600, cumulative_iteration_limit=0)

# solve the model
status = solveMCP(cge)

# Pre-loop calculations
ktot_mx = Dict((r,bmkyr) => value(ks_m[r]) + sum(value(ks_x[r,s]) for s in set[:s])
    for r in set[:r])

srv = 1-value(dr)

# Begin loop
# !!!! consider defining empty dictionaries outside of the loop to store values for postproc
# Been tested from 2017 to 2050 in 1 year increments
for t in 2017:2020
    @info("Begin loop prior to $t Solve.")

    # !!!! Should growth rate be in here? Benchmark cannot replicate if not here.
    # new mutable capital
    newkm = Dict((r,t) => (ktot_mx[r,bmkyr]*(1+value(gr)) - ktot_mx[r,bmkyr]*srv) * result_value(INV[r])
        for r in set[:r]);

    # mutable capital demand from previous solve
    dkml = Dict((r,s) => (haskey(DKM.lookup[1], (r,s)) ? result_value(DKM[(r,s)]) : 0.0)
        for r in set[:r], s in set[:s]);

    # Total mutable/putty capital
    # !!!! Should old putty be frozen?
    # ktot_m = Dict((r,t) => newkm[r,t] + value(ks_m[r])*srv - sum(value(thetax)*dkml[r,s]*srv for s in set[:s])
    #     for r in set[:r]);
    ktot_m = Dict((r,t) => newkm[r,t] + value(ks_m[r])*srv
        for r in set[:r]);

    for r in set[:r]
        set_value(ks_m[r], ktot_m[r,t]);
    end

    yxl = Dict((r,s) => (haskey(YX.lookup[1], (r,s)) ? result_value(YX[(r,s)]) : 0.0)
        for r in set[:r], s in set[:s]);

    # Total extant/clay capital
    # !!!! Should old clay increase by frozen putty each period?
    # ktot_x = Dict((r,s,t) => srv*yxl[r,s]*value(kd0[r,s]) + value(thetax)*dkml[r,s]*srv
    #     for r in set[:r], s in set[:s]);
    ktot_x = Dict((r,s,t) => srv*yxl[r,s]*value(kd0[r,s])
        for r in set[:r], s in set[:s]);

    for r in set[:r], s in set[:s]
        set_value(ks_x[r,s], ktot_x[r,s,t]);
    end

    for r in set[:r], s in set[:s]
    #update labor endowments --- separate parameters for labor endowments versus demand
        set_value(le0[r,s], (1 + value(gr)) * value(le0[r,s]));
    end

    #update balance of payments and household adjustment
    for r in set[:r]
        set_value(bopdef0[r], (1 + value(gr)) * value(bopdef0[r]));
        set_value(hhadj[r], (1 + value(gr)) * value(hhadj[r]));
    end

    #update government and household production
    for r in set[:r], g in set[:g]
        set_value(g0[r,g], (1 + value(gr)) * value(g0[r,g]));
        set_value(yh0[r,g], (1 + value(gr)) * value(yh0[r,g]));
    end

    #update all model variable start values to previous period solution value
    set_start_value.(all_variables(cge), result_value.(all_variables(cge)));

    #update consumption start value
    for r in set[:r]
        set_start_value(C[r], result_value(C[r])*(1+value(gr)));
        set_start_value(INV[r], result_value(INV[r])*(1+value(gr)));
        set_start_value(W[r], result_value(W[r])*(1+value(gr)));
        set_start_value(RA[r], start_value(W[r])*value(w0[r]));
    end

    #update exports start value
    for (r,g) in set[:X]
        set_start_value(X[(r,g)], result_value(X[(r,g)])*(1+value(gr)));
    end

    #update armington start value
    for (r,g) in set[:A]
        set_start_value(A[(r,g)], result_value(A[(r,g)])*(1+value(gr)));
    end

    #update margin supply start value
    for r in set[:r], m in set[:m]
        set_start_value(MS[r,m], result_value(MS[r,m])*(1+value(gr)));
    end

    #update output variable start values
    # !!!! Eventually you could get so much clay, that YM level value is negative (Divide by kd0?)
    for (r,s) in set[:Y]
        set_start_value(YX[(r,s)], value(ks_x[r,s])/value(kd0[r,s])); # !!!! divide by kd0? Sensitive to thetax and dr
        set_start_value(YM[(r,s)], (start_value(C[r]) - start_value(YX[(r,s)])));
        set_start_value(DKM[(r,s)], start_value(YM[(r,s)])*value(kd0[r,s]));
    end

    #update value shares
    for r in set[:r], s in set[:s]
        set_value(alpha_kl[r,s], ensurefinite(value(ld0[r,s])/(value(ld0[r,s]) + value(kd0[r,s]))));
    end

    #update value shares
    for r in set[:r], g in set[:g]
        set_value(alpha_x[r,g], ensurefinite((value(x0[r, g]) - value(rx0[r, g])) / value(s0[r, g])));
        set_value(alpha_d[r,g], ensurefinite((value(xd0[r,g])) / value(s0[r, g])));
        set_value(alpha_n[r,g], ensurefinite(value(xn0[r,g]) / (value(s0[r, g]))));
        set_value(theta_n[r,g], ensurefinite(value(nd0[r, g]) / (value(nd0[r, g]) + value(dd0[r, g]))));
        set_value(theta_m[r,g], ensurefinite((1+value(tm0[r, g])) * value(m0[r, g]) / (value(nd0[r, g]) + value(dd0[r, g]) + (1 + value(tm0[r, g])) * value(m0[r, g]))));
    end

    #set up the options for the path solver
    #PATHSolver.options(convergence_tolerance=1e-6, output=:yes, time_limit=3600, cumulative_iteration_limit=10000)
    PATHSolver.options(convergence_tolerance=1e-6, output=:yes, time_limit=3600, cumulative_iteration_limit=0)

    # solve next period
    status = solveMCP(cge)
end
