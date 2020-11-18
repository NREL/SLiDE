################################################
#
# SLiDE Model - Static Model Benchmark Replication
#
################################################

using SLiDE
using CSV
using JuMP
using Complementarity
using DataFrames


#################
# -- FUNCTIONS --
#################

"This function replaces `NaN` or `Inf` values with `0.0`."
ensurefinite(x::Float64) = (isnan(x) || x==Inf) ? 0.0 : x


"""
    nonzero_subset(df::DataFrame)

# Returns
- `x::Array{Tuple,1}` of all parameter indices corresponding with non-zero values
- `idx::Array{Symbol,1}` of parameter indices in `df`
"""
function nonzero_subset(df::DataFrame)
    idx = findindex(df)
    val = convert_type(Array{Tuple}, dropzero(df)[:,idx])
    return (val, idx)
end


"""
    _model_input(year::Int, d::Dict{Symbol,DataFrame}, set::Dict, idx::Dict)

# Arguments
- `year::Int`: year for which to perform calibration
- `d::Dict{Symbol,DataFrame}` of DataFrames containing the model data.
- `set::Dict` of Arrays describing region, sector, final demand, etc.
- `idx::Dict` of parameter indices

# Returns
- `d::Dict{Symbol,Dict}` of model data with all zeros filled
- `set::Dict` of model indices, with added arrays of tuples indicating which (region,sector)
    or (region,good) combinations are relevant to the zero-profit and market-clearing
    conditions.
- `idx::Dict` of parameter indices.
"""
function _model_input(year::Int, d::Dict{Symbol,DataFrame}, set::Dict, idx::Dict = Dict())
    @info("Preparing model data for $year.")
    
    d = Dict(k => filter_with(df, (yr = year,); drop = true) for (k,df) in d)

    isempty(idx) && (idx = Dict(k => findindex(df) for (k,df) in d))
    (set, idx) = _model_set!(d, set, idx)

    d = Dict(k => convert_type(Dict, fill_zero(set, df)) for (k,df) in d)
    return (d, set, idx)
end


"""
    _model_set!(d::Dict{Symbol,DataFrame}, set::Dict, idx::Dict)
This function returns subsets intended to limit the size of the model by including only
non-zero values when mapping zero-profit and market-clearing conditions.

# Arguments
- `d::Dict{Symbol,DataFrame}` of DataFrames containing the model data.
- `set::Dict` of Arrays describing region, sector, final demand, etc.
- `idx::Dict` of parameter indices

# Returns
- `d::Dict{Symbol,Dict}` of model data with all zeros filled
- `set::Dict` of model indices, with added arrays of tuples indicating which (region,sector)
    or (region,good) combinations are relevant to the zero-profit and market-clearing
    conditions.
- `idx::Dict` of indices, updated to include those used to define the newly-added sets.
"""
function _model_set!(d::Dict{Symbol,DataFrame}, set::Dict, idx::Dict)
    (set[:A], idx[:A]) = nonzero_subset(d[:a0] + d[:rx0])
    (set[:Y], idx[:Y]) = nonzero_subset(combine_over(d[:ys0], :g))
    (set[:X], idx[:X]) = nonzero_subset(d[:s0])
    (set[:PA], idx[:PA]) = nonzero_subset(d[:a0])
    (set[:PD], idx[:PD]) = nonzero_subset(d[:xd0])
    (set[:PK], idx[:PK]) = nonzero_subset(d[:kd0])
    (set[:PY], idx[:PY]) = nonzero_subset(d[:s0])
    return (set, idx)
end

############
# LOAD DATA
############

#SLiDE data needs to be built or point to pre-existing build directory
#can pass a name (d, set) = build_data("name_of_build_directory")
!(@isdefined(d_in) && @isdefined(set_in)) && ((d_in, set_in) = build_data("state_model"))
d = copy(d_in)
set = copy(set_in)

bmkyr = 2016
(sld, set, idx) = _model_input(bmkyr, d, set)


########## Model ##########
cge = MCPModel();

##############
# PARAMETERS
##############

#benchmark values
@NLparameter(cge, ys0[r in set[:r], s in set[:s], g in set[:g]] == sld[:ys0][r,s,g]); 
@NLparameter(cge, id0[r in set[:r], s in set[:s], g in set[:g]] == sld[:id0][r,s,g]);
@NLparameter(cge, ld0[r in set[:r], s in set[:s]] == sld[:ld0][r,s]);
@NLparameter(cge, kd0[r in set[:r], s in set[:s]] == sld[:kd0][r,s]);
@NLparameter(cge, ty0[r in set[:r], s in set[:s]] == sld[:ty0][r,s]);
@NLparameter(cge, ty[r in set[:r], s in set[:s]] == sld[:ty0][r,s]);
@NLparameter(cge, m0[r in set[:r], g in set[:g]] == sld[:m0][r,g]);
@NLparameter(cge, x0[r in set[:r], g in set[:g]] == sld[:x0][r,g]);
@NLparameter(cge, rx0[r in set[:r], g in set[:g]] == sld[:rx0][r,g]);
@NLparameter(cge, md0[r in set[:r], m in set[:m], g in set[:g]] == sld[:md0][r,m,g]);
@NLparameter(cge, nm0[r in set[:r], g in set[:g], m in set[:m]] == sld[:nm0][r,g,m]);
@NLparameter(cge, dm0[r in set[:r], g in set[:g], m in set[:m]] == sld[:dm0][r,g,m]);
@NLparameter(cge, s0[r in set[:r], g in set[:g]] == sld[:s0][r,g]);
@NLparameter(cge, a0[r in set[:r], g in set[:g]] == sld[:a0][r,g]);
@NLparameter(cge, ta0[r in set[:r], g in set[:g]] == sld[:ta0][r,g]);
@NLparameter(cge, ta[r in set[:r], g in set[:g]] == sld[:ta0][r,g]);
@NLparameter(cge, tm0[r in set[:r], g in set[:g]] == sld[:tm0][r,g]);
@NLparameter(cge, tm[r in set[:r], g in set[:g]] == sld[:tm0][r,g]);
@NLparameter(cge, cd0[r in set[:r], g in set[:g]] == sld[:cd0][r,g]);
@NLparameter(cge, c0[r in set[:r]] == sld[:c0][r]);
@NLparameter(cge, yh0[r in set[:r], g in set[:g]] == sld[:yh0][r,g]);
@NLparameter(cge, bopdef0[r in set[:r]] == sld[:bopdef0][r]);
@NLparameter(cge, hhadj[r in set[:r]] == sld[:hhadj][r]);
@NLparameter(cge, g0[r in set[:r], g in set[:g]] == sld[:g0][r,g]);
@NLparameter(cge, xn0[r in set[:r], g in set[:g]] == sld[:xn0][r,g]);
@NLparameter(cge, xd0[r in set[:r], g in set[:g]] == sld[:xd0][r,g]);
@NLparameter(cge, dd0[r in set[:r], g in set[:g]] == sld[:dd0][r,g]);
@NLparameter(cge, nd0[r in set[:r], g in set[:g]] == sld[:nd0][r,g]);
@NLparameter(cge, i0[r in set[:r], g in set[:g]] == sld[:i0][r,g]);

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

# Set lower bound
lo = MODEL_LOWER_BOUND

#set[:s]
@variable(cge, Y[(r,s) in set[:Y]] >= lo, start = 1);
@variable(cge, X[(r,g) in set[:X]] >= lo, start = 1);
@variable(cge, A[(r,g) in set[:A]] >= lo, start = 1);
@variable(cge, C[r in set[:r]] >= lo, start = 1);
@variable(cge, MS[r in set[:r], m in set[:m]] >= lo, start = 1);

#commodities:
@variable(cge, PA[(r,g) in set[:PA]] >= lo, start = 1); # Regional market (input)
@variable(cge, PY[(r,g) in set[:PY]] >= lo, start = 1); # Regional market (output)
@variable(cge, PD[(r,g) in set[:PD]] >= lo, start = 1); # Local market price
@variable(cge, PN[g in set[:g]] >= lo, start =1); # National market
@variable(cge, PL[r in set[:r]] >= lo, start = 1); # Wage rate
@variable(cge, PK[(r,s) in set[:PK]] >= lo, start =1); # Rental rate of capital ###
@variable(cge, PM[r in set[:r], m in set[:m]] >= lo, start =1); # Margin price
@variable(cge, PC[r in set[:r]] >= lo, start = 1); # Consumer price index #####
@variable(cge, PFX >= lo, start = 1); # Foreign exchange

#consumer:
@variable(cge,RA[r in set[:r]]>=lo,start = value(c0[r])) ;


###############################
# -- PLACEHOLDER VARIABLES --
###############################

#cobb-douglas function for value added (VA)
@NLexpression(cge,CVA[r in set[:r],s in set[:s]],
  PL[r]^alpha_kl[r,s] * (haskey(PK.lookup[1], (r,s)) ? PK[(r,s)] : 1.0) ^ (1-alpha_kl[r,s]) );

#demand for labor in VA
@NLexpression(cge,AL[r in set[:r], s in set[:s]], ld0[r,s] * CVA[r,s] / PL[r] );

#demand for capital in VA
@NLexpression(cge,AK[r in set[:r],s in set[:s]],
  kd0[r,s] * CVA[r,s] / (haskey(PK.lookup[1], (r,s)) ? PK[(r,s)] : 1.0) );

#CES function for output demand - including
# exports (absent of re-exports) times the price for foreign exchange, 
# region's supply to national market times the national market price
# regional supply to local market times domestic price
@NLexpression(cge,RX[r in set[:r],g in set[:g]],
  (alpha_x[r,g]*PFX^(1 + et_x[r,g])+alpha_n[r,g]*PN[g]^(1 + et_x[r,g])+alpha_d[r,g]*(haskey(PD.lookup[1], (r,g)) ? PD[(r,g)] : 1.0)^(1 + et_x[r,g]))^(1/(1 + et_x[r,g])) );

#demand for exports via demand function
@NLexpression(cge,AX[r in set[:r],g in set[:g]], (x0[r,g] - rx0[r,g])*(PFX/RX[r,g])^et_x[r,g] );

#demand for contribution to national market 
@NLexpression(cge,AN[r in set[:r],g in set[:g]], xn0[r,g]*(PN[g]/(RX[r,g]))^et_x[r,g] );

#demand for regionals supply to local market
@NLexpression(cge,AD[r in set[:r],g in set[:g]],
  xd0[r,g] * ((haskey(PD.lookup[1], (r,g)) ? PD[(r,g)] : 1.0) / (RX[r,g]))^et_x[r,g] );

# CES function for tradeoff between national and domestic market
@NLexpression(cge,CDN[r in set[:r],g in set[:g]],
  (theta_n[r,g]*PN[g]^(1-es_d[r,g])+(1-theta_n[r,g])*(haskey(PD.lookup[1], (r,g)) ? PD[(r,g)] : 1.0)^(1-es_d[r,g]))^(1/(1-es_d[r,g])) );

# CES function for tradeoff between domestic consumption and foreign exports
# recall tm in the import tariff thus tm / tm0 is the relative change in import tariff rates
@NLexpression(cge,CDM[r in set[:r],g in set[:g]],
  ((1-theta_m[r,g])*CDN[r,g]^(1-es_f[r,g])+theta_m[r,g]*(PFX*(1+tm[r,g])/(1+tm0[r,g]))^(1-es_f[r,g]))^(1/(1-es_f[r,g])) );

# set[:r] demand from the national market <- note nesting of CDN in CDM
@NLexpression(cge,DN[r in set[:r],g in set[:g]],
  nd0[r,g]*(CDN[r,g]/PN[g])^es_d[r,g]*(CDM[r,g]/CDN[r,g])^es_f[r,g] );

# region demand from local market <- note nesting of CDN in CDM
@NLexpression(cge,DD[r in set[:r],g in set[:g]],
  dd0[r,g]*(CDN[r,g]/(haskey(PD.lookup[1], (r,g)) ? PD[(r,g)] : 1.0))^es_d[r,g]*(CDM[r,g]/CDN[r,g])^es_f[r,g] );

# import demand
@NLexpression(cge,MD[r in set[:r],g in set[:g]],
  m0[r,g]*(CDM[r,g]*(1+tm[r,g])/(PFX*(1+tm0[r,g])))^es_f[r,g] );

# final demand
@NLexpression(cge,CD[r in set[:r],g in set[:g]],
  cd0[r,g]*PC[r] / (haskey(PA.lookup[1], (r,g)) ? PA[(r,g)] : 1.0) );


###############################
# -- Zero Profit Conditions --
###############################

@mapping(cge,profit_y[(r,s) in set[:Y]],
# cost of intermediate demand
        sum((haskey(PA.lookup[1], (r,g)) ? PA[(r,g)] : 1.0) * id0[r,g,s] for g in set[:g]) 
# cost of labor inputs
        + PL[r] * AL[r,s]
# cost of capital inputs 
        + (haskey(PK.lookup[1], (r,s)) ? PK[(r,s)] : 1.0)* AK[r,s]
        - 
# revenue from sectoral supply (take note of r/s/g indices on ys0)                
        sum((haskey(PY.lookup[1], (r,g)) ? PY[(r,g)] : 1.0)  * ys0[r,s,g] for g in set[:g]) * (1-ty[r,s])
);

@mapping(cge,profit_x[(r,g) in set[:X]],
# output 'cost' from aggregate supply
         (haskey(PY.lookup[1], (r,g)) ? PY[(r,g)] : 1.0) * s0[r,g] 
        - (
# revenues from foreign exchange
        PFX * AX[r,g]
# revenues from national market                  
        + PN[g] * AN[r,g]
# revenues from domestic market
        + (haskey(PD.lookup[1], (r,g)) ? PD[(r,g)] : 1.0) * AD[r,g]
        )
);

@mapping(cge,profit_a[(r,g) in set[:A]],
# costs from national market
        PN[g] * DN[r,g] 
# costs from domestic market                  
        + (haskey(PD.lookup[1], (r,g)) ? PD[(r,g)] : 1.0) * DD[r,g] 
# costs from imports, including import tariff
        + PFX * (1+tm[r,g]) * MD[r,g]
# costs of margin demand                
        + sum(PM[r,m] * md0[r,m,g] for m in set[:m])
        - ( 
# revenues from regional market based on armington supply               
        (haskey(PA.lookup[1], (r,g)) ? PA[(r,g)] : 1.0) * (1-ta[r,g]) * a0[r,g] 
# revenues from re-exports                   
        + PFX * rx0[r,g]
        )
);

@mapping(cge, profit_c[r in set[:r]],
# costs of inputs - computed as final demand times regional market prices
        sum((haskey(PA.lookup[1], (r,g)) ? PA[(r,g)] : 1.0) * CD[r,g] for g in set[:g])
        - 
# revenues/benefit computed as CPI * reference consumption                  
        PC[r] * c0[r]
);

@mapping(cge,profit_ms[r in set[:r], m in set[:m]],
# provision of set[:m] to national market
        sum(PN[gm]   * nm0[r,gm,m] for gm in set[:gm])
# provision of set[:m] to domestic market    
        + sum((haskey(PD.lookup[1], (r,gm)) ? PD[(r,gm)] : 1.0) * dm0[r,gm,m] for gm in set[:gm])
        - 
# total margin demand    
        PM[r,m] * sum(md0[r,m,gm] for gm in set[:gm])
);


###################################
# -- Market Clearing Conditions -- 
###################################

@mapping(cge,market_pa[(r,g) in set[:PA]],
# absorption or supply
        (haskey(A.lookup[1], (r,g)) ? A[(r,g)] : 1.0) * a0[r,g] 
        - ( 
# government demand (exogenous)       
        g0[r,g] 
# demand for investment (exogenous)
        + i0[r,g]
# final demand        
        + C[r] * CD[r,g]
# intermediate demand        
        + sum((haskey(Y.lookup[1], (r,s)) ? Y[(r,s)] : 1.0) * id0[r,g,s] for s in set[:s] if (r,s) in set[:Y])
        )
);

@mapping(cge,market_py[(r,g) in set[:PY]],
# sectoral supply
        sum((haskey(Y.lookup[1], (r,s)) ? Y[(r,s)] : 1.0) *ys0[r,s,g] for s in set[:s])
# household production (exogenous)        
        + yh0[r,g]
        - 
# aggregate supply (akin to market demand)                
       (haskey(X.lookup[1], (r,g)) ? X[(r,g)] : 1.0) * s0[r,g]
);

@mapping(cge,market_pd[(r,g) in set[:PD]],
# aggregate supply
        (haskey(X.lookup[1], (r,g)) ? X[(r,g)] : 1.0)  * AD[r,g] 
        - ( 
# demand for local market          
        (haskey(A.lookup[1], (r,g)) ? A[(r,g)] : 1.0) * DD[r,g]
# margin supply from local market
        + sum(MS[r,m] * dm0[r,g,m] for m in set[:m] if (g in set[:gm] ) )  
        )
);

@mapping(cge,market_pn[g in set[:g]],
# supply to the national market
        sum((haskey(X.lookup[1], (r,g)) ? X[(r,g)] : 1.0)  * AN[r,g] for r in set[:r])
        - ( 
# demand from the national market 
        sum((haskey(A.lookup[1], (r,g)) ? A[(r,g)] : 1.0) * DN[r,g] for r in set[:r])
# market supply to the national market        
        + sum(MS[r,m] * nm0[r,g,m] for r in set[:r] for m in set[:m] if (g in set[:gm]) )
        )
);

@mapping(cge,market_pl[r in set[:r]],
# supply of labor
        sum(ld0[r,s] for s in set[:s])
        - 
# demand for labor in all set[:s]        
        sum((haskey(Y.lookup[1], (r,s)) ? Y[(r,s)] : 1.0) * AL[r,s] for s in set[:s])
);

@mapping(cge,market_pk[(r,s) in set[:PK]],
        kd0[r,s]
        - 
#current year's capital 
       (haskey(Y.lookup[1], (r,s)) ? Y[(r,s)] : 1.0) * AK[r,s]
);

@mapping(cge,market_pm[r in set[:r], m in set[:m]],
# margin supply 
        MS[r,m] * sum(md0[r,m,gm] for gm in set[:gm])
        - 
# margin demand        
        sum((haskey(A.lookup[1], (r,g)) ? A[(r,g)] : 1.0) * md0[r,m,g] for g in set[:g])
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
        + sum((haskey(X.lookup[1], (r,g)) ? X[(r,g)] : 1.0)  * AX[r,g] for r in set[:r] for g in set[:g])
# supply of re-exports        
        + sum((haskey(A.lookup[1], (r,g)) ? A[(r,g)] : 1.0) * rx0[r,g] for r in set[:r] for g in set[:g] if (r,g) in set[:A])
        - 
# import demand                
        sum((haskey(A.lookup[1], (r,g)) ? A[(r,g)] : 1.0) * MD[r,g] for r in set[:r] for g in set[:g] if (r,g) in set[:A])
);

@mapping(cge,income_ra[r in set[:r]],
# consumption/utility
        RA[r] 
        - 
        (
# labor income        
        PL[r] * sum(ld0[r,s] for s in set[:s])
# capital income        
        + sum((haskey(PK.lookup[1], (r,s)) ? PK[(r,s)] : 1.0) * kd0[r,s] for s in set[:s])
# provision of household supply          
        + sum( (haskey(PY.lookup[1], (r,g)) ? PY[(r,g)] : 1.0) * yh0[r,g] for g in set[:g])
# revenue or costs of foreign exchange including household adjustment   
        + PFX * (bopdef0[r] + hhadj[r])
# government and investment provision        
        - sum((haskey(PA.lookup[1], (r,g)) ? PA[(r,g)] : 1.0) * (g0[r,g] + i0[r,g]) for g in set[:g])
# import taxes - assumes lumpsum recycling
        + sum((haskey(A.lookup[1], (r,g)) ? A[(r,g)] : 1.0) * MD[r,g] * PFX * tm[r,g] for g in set[:g] if (r,g) in set[:A])
# taxes on intermediate demand - assumes lumpsum recycling
        + sum((haskey(A.lookup[1], (r,g)) ? A[(r,g)] : 1.0) * a0[r,g]*(haskey(PA.lookup[1], (r,g)) ? PA[(r,g)] : 1.0)*ta[r,g] for g in set[:g] if (r,g) in set[:A])
# production taxes - assumes lumpsum recycling  
        + sum( (haskey(Y.lookup[1], (r,s)) ? Y[(r,s)] : 1.0) * ys0[r,s,g] * ty[r,s] for s in set[:s], g in set[:g])
        )
);


####################################
# -- Complementarity Conditions --
####################################

# define complementarity conditions
# note the pattern of ZPC -> primal variable  &  MCC -> dual variable (price)
@complementarity(cge,profit_y,Y);
@complementarity(cge,profit_x,X);
@complementarity(cge,profit_a,A);
@complementarity(cge,profit_c,C);
@complementarity(cge,profit_ms,MS);
@complementarity(cge,market_pa,PA);
@complementarity(cge,market_py,PY);
@complementarity(cge,market_pd,PD);
@complementarity(cge,market_pn,PN);
@complementarity(cge,market_pl,PL);
@complementarity(cge,market_pk,PK);
@complementarity(cge,market_pm,PM);
@complementarity(cge,market_pc,PC);
@complementarity(cge,market_pfx,PFX);
@complementarity(cge,income_ra,RA);


####################
# -- Model Solve --
####################

#set up the options for the path solver
PATHSolver.options(convergence_tolerance=1e-6, output=:yes, time_limit=3600, cumulative_iteration_limit=0)

# solve the model
status = solveMCP(cge)