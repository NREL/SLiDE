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


#################
# -- FUNCTIONS --
#################

include(joinpath(SLIDE_DIR,"model","modelfunc.jl"))

############
# LOAD DATA
############

#SLiDE data needs to be built or point to pre-existing build directory
#can pass a name (d, set) = build_data("name_of_build_directory")
!(@isdefined(d_in) && @isdefined(set_in)) && ((d_in, set_in) = build_data("state_model"))
d = copy(d_in)
set = copy(set_in)

#Specify benchmark year - this is the first solve year where the benchmark replicated
bmkyr = 2016

#Load slide data and time horizon to produce model data and appropriate time-indexed subsets
(sld, set, idx) = _model_input(bmkyr, d, set)


########## Model ##########
cge = MCPModel();

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
@NLparameter(cge, ty[r in set[:r], s in set[:s]] == sld[:ty0][r,s]); #
@NLparameter(cge, ta[r in set[:r], g in set[:g]] == sld[:ta0][r,g]); #
@NLparameter(cge, tm[r in set[:r], g in set[:g]] == sld[:tm0][r,g]); #

# -- Major Assumptions --
# Temporal/Dynamic modifications

@NLparameter(cge, ir == 0.05); # interest rate
@NLparameter(cge, gr == 0.02); # growth rate --- try sector and set[:r] specific
@NLparameter(cge, dr == 0.07); # capital depreciation rate
@NLparameter(cge, thetax == 0.75); # extant production share

# !!!! Growth rate adder - work out sector/region specific growth and energy-specific growth
# etars_d = Dict()
# [etars_d[r,s]=0.0 for r in set[:r], s in set[:s]]
#@NLparameter(cge, etars[r in set[:r], s in set[:s]] == get(etars_d,(r,s),0.0));
@NLparameter(cge, etars[r in set[:r], s in set[:s]] == 0.0); # Growth rate adder for testing
# set_value(etars["ca","uti"], 0.03);

"""
# !!!! Autonomous energy efficiency improvements (aeei) could also be employed
# (1%/yr) 0.01 for all industries except electricity/power (0.3%/yr) 0.003
# aeeir[r,s] -> aeei annual growth rate
# aeeir[r,s] = 0.01
# aeeir[r,"ele"] = 0.003
# aeeif -> aeei coefficient
# aeeif[r,s] = 1/(1+aeeir)

# !!!! Population growth rate and labor productivity growth
# !!!! labor augmentation rate (ftar) = fpopgr + glr
# !!!! Productivity index gprod = (1+ftar)^t

# !!!! Scale aeei for electricity sector to AEO estimates/forecasts
# !!!! Scale productivity index to GDP estimates/forecasts
# !!!! further calibration for regional/subnational fitting
"""

#new capital endowment
@NLparameter(cge, ks_n[r in set[:r], s in set[:s]] ==
             value(kd0[r, s])  * (value(dr)+value(gr)+value(etars[r,s])) / (1 + value(gr)) );

# mutable old capital endowment
@NLparameter(cge, ks_s[r in set[:r], s in set[:s]] ==
             value(kd0[r, s]) * (1 - value(thetax)) - value(ks_n[r,s]) );


# Extant capital endowment
@NLparameter(cge, ks_x[r in set[:r], s in set[:s]] ==
             value(kd0[r, s]) * value(thetax) );

# Labor endowment
@NLparameter(cge, le0[r in set[:r], s in set[:s]] == value(ld0[r,s]));


# --- end recursive dynamic preproc ---

# benchmark value share parameters
@NLparameter(cge, alpha_kl[r in set[:r], s in set[:s]] == ensurefinite(value(ld0[r,s]) / (value(ld0[r,s]) + value(kd0[r,s]))));
@NLparameter(cge, alpha_x[r in set[:r], g in set[:g]] == ensurefinite((value(x0[r,g]) - value(rx0[r,g])) / value(s0[r,g])));
@NLparameter(cge, alpha_d[r in set[:r], g in set[:g]] == ensurefinite(value(xd0[r,g]) / value(s0[r,g])));
@NLparameter(cge, alpha_n[r in set[:r], g in set[:g]] == ensurefinite(value(xn0[r,g]) / value(s0[r,g])));
@NLparameter(cge, theta_n[r in set[:r], g in set[:g]] == ensurefinite(value(nd0[r,g]) / (value(nd0[r,g]) - value(dd0[r,g]))));
@NLparameter(cge, theta_m[r in set[:r], g in set[:g]] == ensurefinite((1+value(tm0[r,g])) * value(m0[r,g]) / (value(nd0[r,g]) + value(dd0[r,g]) + (1 + value(tm0[r,g])) * value(m0[r,g]))));

#Substitution and transformation elasticities
@NLparameter(cge, es_va[r in set[:r], s in set[:s]] == SUB_ELAST[:va]); # value-added nest - substitution elasticity
@NLparameter(cge, es_y[r in set[:r], s in set[:s]]  == SUB_ELAST[:y]); # Top-level Y nest (VA,M) - substitution elasticity
@NLparameter(cge, es_m[r in set[:r], s in set[:s]]  == SUB_ELAST[:m]); # Materials nest - substitution elasticity
@NLparameter(cge, et_x[r in set[:r], g in set[:g]]    == TRANS_ELAST[:x]); # Disposition, distribute regional supply to local, national, export - transformation elasticity
@NLparameter(cge, es_a[r in set[:r], g in set[:g]]    == SUB_ELAST[:a]); # Top-level A nest for aggregate demand (set[:m], set[:g]) - substitution elasticity
@NLparameter(cge, es_mar[r in set[:r], g in set[:g]]  == SUB_ELAST[:mar]); # Margin supply - substitution elasticity
@NLparameter(cge, es_d[r in set[:r], g in set[:g]]    == SUB_ELAST[:d]); # Domestic demand aggregation nest (intranational) - substitution elasticity
@NLparameter(cge, es_f[r in set[:r], g in set[:g]]    == SUB_ELAST[:f]); # Domestic and foreign demand aggregation nest (international) - substitution elasticity


################
# VARIABLES
################

# specify value close to zero - true zero creates convergence issues in this version
lo = 0.001

# sectors
#@variable(cge, Y[(r, s) in set[:Y]] >= lo, start = 1);
@variable(cge, X[(r, g) in set[:X]] >= lo, start = 1);
@variable(cge, A[(r, g) in set[:A]] >= lo, start = 1);
@variable(cge, C[r in set[:r]] >= lo, start = 1);
@variable(cge, MS[r in set[:r], m in set[:m]] >= lo, start = 1);

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
@variable(cge,RA[r in set[:r]]>=lo,start = value(c0[r])) ;


#--- recursive dynamic variable declaration ---
@variable(cge,YM[(r,s) in set[:Y]] >= lo, start = (1-value(thetax))); #Mutable production index - replaces Y
@variable(cge,YX[(r,s) in set[:Y]] >= lo, start = value(thetax)); #Extant production index

@variable(cge,RKX[(r,s) in set[:PK]] >= lo, start = 1); # Return to extant capital
@variable(cge,RK[(r,s) in set[:PK]] >= lo, start = 1); #Return to regional capital

"""
# !!!! Zero-profit and market clearance for investment?

# !!!! Capital and Investment assumptions, global, national, local market clearing price?
# !!!! Assume initial steady-state investment?
# .... Derived from benchmark capital or from Investment demand (i0[r,s])?

# Investment produced using intermediate goods
# Investment and Consumption combined to produce welfare index W (fixed proportions)
# W demanded by RA --- or INV and C demanded by RA

"""
###############################
# -- PLACEHOLDER VARIABLES --
###############################

#----------
### Recursive Model expressions

#Cobb-douglas for mutable/new
@NLexpression(cge, CVAym[r in set[:r], s in set[:s]],
              PL[r]^alpha_kl[r,s] * (haskey(RK.lookup[1], (r, s)) ? RK[(r,s)] : 1.0) ^(1-alpha_kl[r,s])
              );

#demand for labor in VA
@NLexpression(cge,ALym[r in set[:r], s in set[:s]],
              ld0[r,s] * CVAym[r,s] / PL[r]
              );

#demand for capital in VA
@NLexpression(cge,AKym[r in set[:r],s in set[:s]],
              kd0[r,s] * CVAym[r,s] / (haskey(RK.lookup[1], (r, s)) ? RK[(r,s)] : 1.0)
              );

###
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
        + (haskey(RK.lookup[1], (r, s)) ? RK[(r,s)] : 1.0) * AKym[r,s]
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

# @mapping(cge,profit_y[(r, s) in set[:Y]],
# # cost of intermediate demand
#         sum((haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * id0[r,g,s] for g in set[:g])
# # cost of labor inputs
#         + PL[r] * AL[r,s]
# # cost of capital inputs
#         + (haskey(PK.lookup[1], (r, s)) ? PK[(r, s)] : 1.0)* AK[r,s]
#         -
# # revenue from sectoral supply (take note of r/s/g indices on ys0)
#         sum((haskey(PY.lookup[1], (r, g)) ? PY[(r, g)] : 1.0)  * ys0[r,s,g] for g in set[:g]) * (1-ty[r,s])
# );



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

@mapping(cge,market_rk[(r, s) in set[:PK]],
        (ks_n[r,s] + ks_s[r,s])
        -
#current year's capital
       (haskey(YM.lookup[1], (r, s)) ? YM[(r, s)] : 1.) * AKym[r,s]
);

@mapping(cge,market_rkx[(r, s) in set[:PK]],
         (ks_x[r,s])
         -
       (haskey(YX.lookup[1], (r, s)) ? YX[(r, s)] : 1.) * kd0[r,s]
);


@mapping(cge,market_pa[(r, g) in set[:PA]],
# absorption or supply
        (haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.) * a0[r,g]
        - (
# government demand (exogenous)
        g0[r,g]
# demand for investment (exogenous)
        + i0[r,g]
# final demand
        + C[r] * CD[r,g]
# intermediate demand
#            + sum((haskey(Y.lookup[1], (r, s)) ? Y[(r, s)] : 1) * id0[r,g,s] for s in set[:s] if (r,s) in set[:Y])
            + sum((haskey(YM.lookup[1], (r, s)) ? YM[(r, s)] : 1) * id0[r,g,s] for s in set[:s] if (r,s) in set[:Y])
            + sum((haskey(YX.lookup[1], (r, s)) ? YX[(r, s)] : 1) * id0[r,g,s] for s in set[:s] if (r,s) in set[:Y])
        )
);

@mapping(cge,market_py[(r, g) in set[:PY]],
# sectoral supply
#        sum((haskey(Y.lookup[1], (r, s)) ? Y[(r, s)] : 1) *ys0[r,s,g] for s in set[:s])
         sum((haskey(YM.lookup[1], (r, s)) ? YM[(r, s)] : 1) *ys0[r,s,g] for s in set[:s])
         + sum((haskey(YX.lookup[1], (r, s)) ? YX[(r, s)] : 1) *ys0[r,s,g] for s in set[:s])
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
#        sum((haskey(Y.lookup[1], (r, s)) ? Y[(r, s)] : 1) * AL[r,s] for s in set[:s])
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
# margin supply from local market
        + sum(MS[r,m] * dm0[r,g,m] for m in set[:m] if (g in set[:gm] ) )
        )
);

@mapping(cge,market_pn[g in set[:g]],
# supply to the national market
        sum((haskey(X.lookup[1], (r, g)) ? X[(r, g)] : 1)  * AN[r,g] for r in set[:r])
        - (
# demand from the national market
        sum((haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.) * DN[r,g] for r in set[:r])
# market supply to the national market
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
# a period's final demand
        C[r] * c0[r]
        -
# consumption / utiltiy
        RA[r] / PC[r]
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
            +sum((haskey(RK.lookup[1], (r, s)) ? RK[(r,s)] : 1.0) * (ks_n[r,s]+ks_s[r,s]) for s in set[:s])
            +sum((haskey(RKX.lookup[1], (r, s)) ? RKX[(r,s)] : 1.0) * ks_x[r,s] for s in set[:s])
        #+ sum((haskey(PK.lookup[1], (r, s)) ? PK[(r,s)] : 1.0) * kd0[r,s] for s in set[:s])
# provision of household supply
        + sum( (haskey(PY.lookup[1], (r, g)) ? PY[(r, g)] : 1.0) * yh0[r,g] for g in set[:g])
# revenue or costs of foreign exchange including household adjustment
        + PFX * (bopdef0[r] + hhadj[r])
# government and investment provision
        - sum((haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * (g0[r,g] + i0[r,g]) for g in set[:g])
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


####################
# -- Model Solve --
####################

#set up the options for the path solver
PATHSolver.options(convergence_tolerance=1e-6, output=:yes, time_limit=3600, cumulative_iteration_limit=0)


# solve the model

status = solveMCP(cge)

for t in 1:3

# !!!! Save for later when making investment better
#scale(r,s,t) = (1-delta)*(ks_n(r,s,"%bmkyr%")+ks_s(r,s,"%bmkyr%")+ks_x(r,s,"%bmkyr%")) / (i0(r,s)*(ir+delta));
#ks_n(r,s,t) = scale(r,s,t)*i0(r,s))*I.l(r,s)*(ir+delta);
#total_cap = ks_n+ks_s+ks_x

total_cap = Dict()
[total_cap[r,s]=value(ks_n[r,s])+value(ks_s[r,s])+value(ks_x[r,s]) for r in set[:r], s in set[:s]]

scalecap=Dict()
[scalecap[r,s]=(1-value(dr))*total_cap[r,s]/(value(i0[r,s])*(value(ir)+value(dr))) for r in set[:r], s in set[:s]]
# get(scalecap, (r,s), 0.0)

# Update parameters for next period
for r in set[:r], s in set[:s]
#update capital endowments
    set_value(ks_s[r,s], (1-value(dr)) * (value(ks_s[r,s]) + value(ks_n[r,s])));
    set_value(ks_x[r,s], (1-value(dr)) * value(ks_x[r,s]));
#    set_value(ks_n[r,s], (value(ir) + value(dr)) * value(i0[r,s]) );
    set_value(ks_n[r,s], value(dr)*(1 + value(gr) + value(etars[r,s]))*get(total_cap,(r,s),0.0));
#    set_value(ks_n[r,s], value(dr)*get(total_cap,(r,s),0.0));
end

#steady-state investment assumption test
testk=Dict()
[testk[r,s]=value(kd0[r,s])-(value(ks_n[r,s])+value(ks_s[r,s])+value(ks_x[r,s])) for r in set[:r], s in set[:s]]

for r in set[:r], s in set[:s]
#update labor endowments --- I think I need separate parameters for labor endowments versus demand
    set_value(le0[r,s], (1 + value(gr)+value(etars[r,s])) * value(le0[r,s]));
end

#update balance of payments
for r in set[:r]
    set_value(bopdef0[r], (1 + value(gr)) * value(bopdef0[r]));
end

#update government and exogenous investment parameters
# !!!! What should happen with i0?
for r in set[:r], g in set[:g]
    set_value(g0[r,g], (1 + value(gr)+value(etars[r,g])) * value(g0[r,g]));
    set_value(i0[r,g], (1 + value(gr)+value(etars[r,g])) * value(i0[r,g]));
end

#update all model variable start values to previous period solution value
set_start_value.(all_variables(cge), result_value.(all_variables(cge)));

#update consumption start value
for r in set[:r]
    set_start_value(C[r], result_value(C[r])*(1+value(gr)));
end

#update exports start value
for (r,g) in set[:X]
    set_start_value(X[(r,g)], result_value(X[(r,g)])*(1+value(gr)+value(etars[r,g])));
end

#update armington start value
for (r,g) in set[:A]
    set_start_value(A[(r,g)], result_value(A[(r,g)])*(1+value(gr)+value(etars[r,g])));
end

for r in set[:r], m in set[:m]
    set_start_value(MS[r,m], result_value(MS[r,m])*(1+value(gr)));
end

#update output variable start values
for (r,s) in set[:Y]
    set_start_value(YX[(r,s)], result_value(YX[(r,s)])*(1-value(dr)));
    set_start_value(YM[(r,s)], result_value(YM[(r,s)])*(1+value(gr)+value(etars[r,s])));
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
PATHSolver.options(convergence_tolerance=1e-6, output=:yes, time_limit=3600, cumulative_iteration_limit=100000)

# solve next period
status = solveMCP(cge)
end
