
################################################
#
# Replication of the state-level blueNOTE model
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

#Convert/create all combinations of different sets (regions, sectors, etc) as tuples
#Then reshape array of tuples as a one dimensional column vector
#Used in parameter definition
function combvec(set_a...)
    return vec(collect(Iterators.product(set_a...)))
end

# Replaces nan's for denseaxisarray
# Used mainly for value shares w/ zero denominator
function replace_nan_inf(
    cont::T,
) where {T <: JuMP.Containers.DenseAxisArray{NonlinearParameter}}
    for param in cont
        if isnan(value(param)) || value(param) == Inf
            set_value(param, 0.0)
        end
    end
    return
end

############
# LOAD DATA
############

#SLiDE data needs to be built or point to pre-existing build directory
#can pass a name (d, set) = build_data("name_of_build_directory")
(d, set) = build_data("state_model")

#set benchmark year
bmkyr=2016

#sld is the slide dictionary of benchmark values filtered for benchmark year
sld = Dict(k => convert_type(Dict, dropzero(filter_with(d[k], (yr = bmkyr,); drop = true))) for k in keys(d))
# zld = Dict(k => convert_type(Dict, fill_zero(set,
#     filter_with(df, (yr = bmkyr,); drop = true))) for (k,df) in d)

###############
# -- SETS --
###############

#Read sets from SLiDE build dictionary
regions = set[:r]
sectors = set[:s]
goods = set[:g]
margins = set[:m]
goods_margins = set[:gm]


#following subsets are used to limit the size of the model
# the a_set restricits the A variables indices to those
# with positive armington supply or re-exports
a_set = Dict()
[a_set[r,g] = get(sld[:a0], (r,g), 0.0) + get(sld[:rx0], (r,g), 0.0) for r in regions for g in goods]

# y_check is used to make sure the r/s combination 
# has a reference amount of sectoral supply
y_check = Dict()
[y_check[r,s] = sum(get(sld[:ys0], (r,s,g), 0.0) for g in goods) for r in regions for s in sectors]


#subsets for model equation controls
sub_set_y = filter(x -> y_check[x] != 0.0, permute(regions, sectors));
sub_set_a = filter(x -> a_set[x[1], x[2]] != 0.0, permute(regions, goods));
sub_set_x = filter(x -> get(sld[:s0], (x[1], x[2]), 0.0) != 0.0, permute(regions, goods));      # empty
sub_set_pa = filter(x -> get(sld[:a0], (x[1], x[2]), 0.0) != 0.0, permute(regions, goods));     # same as sub_set_a
sub_set_pd = filter(x -> get(sld[:xd0], (x[1], x[2]), 0.0) != 0.0, permute(regions, goods));
sub_set_pk = filter(x -> get(sld[:kd0], (x[1], x[2]), 0.0) != 0.0, permute(regions, goods));
sub_set_py = filter(x -> get(sld[:kd0], (x[1], x[2]), 0.0) != 0.0, permute(regions, goods));
sub_set_py = filter(x -> y_check[x[1], x[2]] != 0, permute(regions, goods));


########## Model ##########
cge = MCPModel();


##############
# PARAMETERS
##############

# add_permutation!(set, (:r,:s,:g))
# @NLparameter(cge, ys0[(r,s,g) in set[:r,:s,:g]] == get(sld[:ys0], (r, s, g), 0.0));

#benchmark values
@NLparameter(cge, ys0[r in regions, s in sectors, g in goods] == get(sld[:ys0], (r, s, g), 0.0));
@NLparameter(cge, id0[r in regions, s in sectors, g in goods] == get(sld[:id0], (r, s, g), 0.0));
@NLparameter(cge, ld0[r in regions, s in sectors] == get(sld[:ld0], (r, s), 0.0));
@NLparameter(cge, kd0[r in regions, s in sectors] == get(sld[:kd0], (r, s), 0.0));
@NLparameter(cge, ty0[r in regions, s in sectors] == get(sld[:ty0], (r, s), 0.0));
@NLparameter(cge, ty[r in regions, s in sectors] == get(sld[:ty0], (r, s), 0.0));
@NLparameter(cge, m0[r in regions, g in goods] == get(sld[:m0], (r, g), 0.0));
@NLparameter(cge, x0[r in regions, g in goods] == get(sld[:x0], (r, g), 0.0));
@NLparameter(cge, rx0[r in regions, g in goods] == get(sld[:rx0], (r, g), 0.0));
@NLparameter(cge, md0[r in regions, m in margins, g in goods] == get(sld[:md0], (r, m, g), 0.0));
@NLparameter(cge, nm0[r in regions, g in goods, m in margins] == get(sld[:nm0], (r, g, m), 0.0));
@NLparameter(cge, dm0[r in regions, g in goods, m in margins] == get(sld[:dm0], (r, g, m), 0.0));
@NLparameter(cge, s0[r in regions, g in goods] == get(sld[:s0], (r, g), 0.0));
@NLparameter(cge, a0[r in regions, g in goods] == get(sld[:a0], (r, g), 0.0));
@NLparameter(cge, ta0[r in regions, g in goods] == get(sld[:ta0], (r, g), 0.0));
@NLparameter(cge, ta[r in regions, g in goods] == get(sld[:ta0], (r, g), 0.0));
@NLparameter(cge, tm0[r in regions, g in goods] == get(sld[:tm0], (r, g), 0.0));
@NLparameter(cge, tm[r in regions, g in goods] == get(sld[:tm0], (r, g), 0.0));
@NLparameter(cge, cd0[r in regions, g in goods] == get(sld[:cd0], (r, g), 0.0));
@NLparameter(cge, c0[r in regions] == get(sld[:c0], r, 0.0));
@NLparameter(cge, yh0[r in regions, g in goods] == get(sld[:yh0], (r, g), 0.0));
@NLparameter(cge, bopdef0[r in regions] == get(sld[:bopdef0], r, 0.0));
@NLparameter(cge, hhadj[r in regions] == get(sld[:hhadj], r, 0.0));
@NLparameter(cge, g0[r in regions, g in goods] == get(sld[:g0], (r, g), 0.0));
@NLparameter(cge, xn0[r in regions, g in goods] == get(sld[:xn0], (r, g), 0.0));
@NLparameter(cge, xd0[r in regions, g in goods] == get(sld[:xd0], (r, g), 0.0));
@NLparameter(cge, dd0[r in regions, g in goods] == get(sld[:dd0], (r, g), 0.0));
@NLparameter(cge, nd0[r in regions, g in goods] == get(sld[:nd0], (r, g), 0.0));
@NLparameter(cge, i0[r in regions, g in goods] == get(sld[:i0], (r, g), 0.0));

# benchmark value share parameters
@NLparameter(cge, alpha_kl[r in regions, s in sectors] == value(ld0[r, s]) / (value(ld0[r, s]) + value(kd0[r, s])));
@NLparameter(cge, alpha_x[r in regions, g in goods] == (value(x0[r, g]) - value(rx0[r, g])) / value(s0[r, g]));
@NLparameter(cge, alpha_d[r in regions, g in goods] == value(xd0[r, g]) / value(s0[r, g]));
@NLparameter(cge, alpha_n[r in regions, g in goods] == value(xn0[r, g]) / value(s0[r, g]));
@NLparameter(cge, theta_n[r in regions, g in goods] == value(nd0[r, g]) / (value(nd0[r, g]) - value(dd0[r, g])));
@NLparameter(cge, theta_m[r in regions, g in goods] == (1+value(tm0[r, g])) * value(m0[r, g]) / (value(nd0[r, g]) + value(dd0[r, g]) + (1 + value(tm0[r, g])) * value(m0[r, g])));

replace_nan_inf(alpha_kl)
replace_nan_inf(alpha_x)
replace_nan_inf(alpha_d)
replace_nan_inf(alpha_n)
replace_nan_inf(theta_n)
replace_nan_inf(theta_m)

#Substitution and transformation elasticities
@NLparameter(cge, es_va[r in regions, s in sectors] == SUB_ELAST[:va]); # value-added nest - substitution elasticity
@NLparameter(cge, es_y[r in regions, s in sectors]  == SUB_ELAST[:y]); # Top-level Y nest (VA,M) - substitution elasticity
@NLparameter(cge, es_m[r in regions, s in sectors]  == SUB_ELAST[:m]); # Materials nest - substitution elasticity
@NLparameter(cge, et_x[r in regions, g in goods]    == TRANS_ELAST[:x]); # Disposition, distribute regional supply to local, national, export - transformation elasticity
@NLparameter(cge, es_a[r in regions, g in goods]    == SUB_ELAST[:a]); # Top-level A nest for aggregate demand (Margins, goods) - substitution elasticity
@NLparameter(cge, es_mar[r in regions, g in goods]  == SUB_ELAST[:mar]); # Margin supply - substitution elasticity
@NLparameter(cge, es_d[r in regions, g in goods]    == SUB_ELAST[:d]); # Domestic demand aggregation nest (intranational) - substitution elasticity
@NLparameter(cge, es_f[r in regions, g in goods]    == SUB_ELAST[:f]); # Domestic and foreign demand aggregation nest (international) - substitution elasticity


################
# VARIABLES
################

# Set lower bound
sv = 0.001

#sectors
@variable(cge, Y[(r, s) in sub_set_y] >= sv, start = 1);
@variable(cge, X[(r, g) in sub_set_x] >= sv, start = 1);
@variable(cge, A[(r, g) in sub_set_a] >= sv, start = 1);
@variable(cge, C[r in regions] >= sv, start = 1);
@variable(cge, MS[r in regions, m in margins] >= sv, start = 1);

#commodities:
@variable(cge, PA[(r, g) in sub_set_pa] >= sv, start = 1); # Regional market (input)
@variable(cge, PY[(r, g) in sub_set_py] >= sv, start = 1); # Regional market (output)
@variable(cge, PD[(r, g) in sub_set_pd] >= sv, start = 1); # Local market price
@variable(cge, PN[g in goods] >= sv, start =1); # National market
@variable(cge, PL[r in regions] >= sv, start = 1); # Wage rate
@variable(cge, PK[(r, s) in sub_set_pk] >= sv, start =1); # Rental rate of capital ###
@variable(cge, PM[r in regions, m in margins] >= sv, start =1); # Margin price
@variable(cge, PC[r in regions] >= sv, start = 1); # Consumer price index #####
@variable(cge, PFX >= sv, start = 1); # Foreign exchange

#consumer:
@variable(cge,RA[r in regions]>=sv,start = value(c0[r])) ;


###############################
# -- PLACEHOLDER VARIABLES --
###############################

#cobb-douglas function for value added (VA)
@NLexpression(cge,CVA[r in regions,s in sectors],
  PL[r]^alpha_kl[r,s] * (haskey(PK.lookup[1], (r, s)) ? PK[(r, s)] : 1.0) ^ (1-alpha_kl[r,s]) );

#demand for labor in VA
@NLexpression(cge,AL[r in regions, s in sectors], ld0[r,s] * CVA[r,s] / PL[r] );

#demand for capital in VA
@NLexpression(cge,AK[r in regions,s in sectors],
  kd0[r,s] * CVA[r,s] / (haskey(PK.lookup[1], (r, s)) ? PK[(r, s)] : 1.0) );

#CES function for output demand - including
# exports (absent of re-exports) times the price for foreign exchange, 
# region's supply to national market times the national market price
# regional supply to local market times domestic price
@NLexpression(cge,RX[r in regions,g in goods],
  (alpha_x[r,g]*PFX^(1 + et_x[r,g])+alpha_n[r,g]*PN[g]^(1 + et_x[r,g])+alpha_d[r,g]*(haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0)^(1 + et_x[r,g]))^(1/(1 + et_x[r,g])) );

#demand for exports via demand function
@NLexpression(cge,AX[r in regions,g in goods], (x0[r,g] - rx0[r,g])*(PFX/RX[r,g])^et_x[r,g] );

#demand for contribution to national market 
@NLexpression(cge,AN[r in regions,g in goods], xn0[r,g]*(PN[g]/(RX[r,g]))^et_x[r,g] );

#demand for regionals supply to local market
@NLexpression(cge,AD[r in regions,g in goods],
  xd0[r,g] * ((haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0) / (RX[r,g]))^et_x[r,g] );

# CES function for tradeoff between national and domestic market
@NLexpression(cge,CDN[r in regions,g in goods],
  (theta_n[r,g]*PN[g]^(1-es_d[r,g])+(1-theta_n[r,g])*(haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0)^(1-es_d[r,g]))^(1/(1-es_d[r,g])) );

# CES function for tradeoff between domestic consumption and foreign exports
# recall tm in the import tariff thus tm / tm0 is the relative change in import tariff rates
@NLexpression(cge,CDM[r in regions, g in goods],
  ((1-theta_m[r,g])*CDN[r,g]^(1-es_f[r,g])+theta_m[r,g]*(PFX*(1+tm[r,g])/(1+tm0[r,g]))^(1-es_f[r,g]))^(1/(1-es_f[r,g])) );

# regions demand from the national market <- note nesting of CDN in CDM
@NLexpression(cge,DN[r in regions,g in goods],
  nd0[r,g]*(CDN[r,g]/PN[g])^es_d[r,g]*(CDM[r,g]/CDN[r,g])^es_f[r,g] );

# region demand from local market <- note nesting of CDN in CDM
@NLexpression(cge,DD[r in regions,g in goods],
  dd0[r,g]*(CDN[r,g]/(haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0))^es_d[r,g]*(CDM[r,g]/CDN[r,g])^es_f[r,g] );

# import demand
@NLexpression(cge,MD[r in regions,g in goods],
  m0[r,g]*(CDM[r,g]*(1+tm[r,g])/(PFX*(1+tm0[r,g])))^es_f[r,g] );

# final demand
@NLexpression(cge,CD[r in regions,g in goods],
  cd0[r,g]*PC[r] / (haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) );


###############################
# -- Zero Profit Conditions --
###############################

@mapping(cge,profit_y[(r, s) in sub_set_y],
# cost of intermediate demand
        sum((haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * id0[r,g,s] for g in goods) 
# cost of labor inputs
        + PL[r] * AL[r,s]
# cost of capital inputs 
        + (haskey(PK.lookup[1], (r, s)) ? PK[(r, s)] : 1.0)* AK[r,s]
        - 
# revenue from sectoral supply (take note of r/s/g indices on ys0)                
        sum((haskey(PY.lookup[1], (r, g)) ? PY[(r, g)] : 1.0)  * ys0[r,s,g] for g in goods) * (1-ty[r,s])
);

@mapping(cge,profit_x[(r, g) in sub_set_x],
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

@mapping(cge,profit_a[(r, g) in sub_set_a],
# costs from national market
        PN[g] * DN[r,g] 
# costs from domestic market                  
        + (haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0) * DD[r,g] 
# costs from imports, including import tariff
        + PFX * (1+tm[r,g]) * MD[r,g]
# costs of margin demand                
        + sum(PM[r,m] * md0[r,m,g] for m in margins)
        - ( 
# revenues from regional market based on armington supply               
        (haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * (1-ta[r,g]) * a0[r,g] 
# revenues from re-exports                   
        + PFX * rx0[r,g]
        )
);

@mapping(cge, profit_c[r in regions],
# costs of inputs - computed as final demand times regional market prices
        sum((haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * CD[r,g] for g in goods)
        - 
# revenues/benefit computed as CPI * reference consumption                  
        PC[r] * c0[r]
);

@mapping(cge,profit_ms[r in regions, m in margins],
# provision of margins to national market
        sum(PN[gm]   * nm0[r,gm,m] for gm in goods_margins)
# provision of margins to domestic market    
        + sum((haskey(PD.lookup[1], (r, gm)) ? PD[(r, gm)] : 1.0) * dm0[r,gm,m] for gm in goods_margins)
        - 
# total margin demand    
        PM[r,m] * sum(md0[r,m,gm] for gm in goods_margins)
);


###################################
# -- Market Clearing Conditions -- 
###################################

@mapping(cge,market_pa[(r, g) in sub_set_pa],
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
        + sum((haskey(Y.lookup[1], (r, s)) ? Y[(r, s)] : 1) * id0[r,g,s] for s in sectors if (y_check[r,s] > 0))
        )
);

@mapping(cge,market_py[(r, g) in sub_set_py],
# sectoral supply
        sum((haskey(Y.lookup[1], (r, s)) ? Y[(r, s)] : 1) *ys0[r,s,g] for s in sectors)
# household production (exogenous)        
        + yh0[r,g]
        - 
# aggregate supply (akin to market demand)                
       (haskey(X.lookup[1], (r, g)) ? X[(r, g)] : 1) * s0[r,g]
);

@mapping(cge,market_pd[(r, g) in sub_set_pd],
# aggregate supply
        (haskey(X.lookup[1], (r, g)) ? X[(r, g)] : 1)  * AD[r,g] 
        - ( 
# demand for local market          
        (haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.) * DD[r,g]
# margin supply from local market
        + sum(MS[r,m] * dm0[r,g,m] for m in margins if (g in goods_margins ) )  
        )
);

@mapping(cge,market_pn[g in goods],
# supply to the national market
        sum((haskey(X.lookup[1], (r, g)) ? X[(r, g)] : 1)  * AN[r,g] for r in regions)
        - ( 
# demand from the national market 
        sum((haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.) * DN[r,g] for r in regions)
# market supply to the national market        
        + sum(MS[r,m] * nm0[r,g,m] for r in regions for m in margins if (g in goods_margins) )
        )
);

@mapping(cge,market_pl[r in regions],
# supply of labor
        sum(ld0[r,s] for s in sectors)
        - 
# demand for labor in all sectors        
        sum((haskey(Y.lookup[1], (r, s)) ? Y[(r, s)] : 1) * AL[r,s] for s in sectors)
);

@mapping(cge,market_pk[(r, s) in sub_set_pk],
        kd0[r,s]
        - 
#current year's capital 
       (haskey(Y.lookup[1], (r, s)) ? Y[(r, s)] : 1.) * AK[r,s]
);

@mapping(cge,market_pm[r in regions, m in margins],
# margin supply 
        MS[r,m] * sum(md0[r,m,gm] for gm in goods_margins)
        - 
# margin demand        
        sum((haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.) * md0[r,m,g] for g in goods)
);

@mapping(cge,market_pc[r in regions],
# a period's final demand
        C[r] * c0[r]
        - 
# consumption / utiltiy        
        RA[r] / PC[r]
);

@mapping(cge,market_pfx,
# balance of payments (exogenous)
        sum(bopdef0[r] for r in regions)
# supply of exports     
        + sum((haskey(X.lookup[1], (r, g)) ? X[(r, g)] : 1)  * AX[r,g] for r in regions for g in goods)
# supply of re-exports        
        + sum((haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.) * rx0[r,g] for r in regions for g in goods if (a_set[r,g] != 0))
        - 
# import demand                
        sum((haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.) * MD[r,g] for r in regions for g in goods if (a_set[r,g] != 0))
);

@mapping(cge,income_ra[r in regions],
# consumption/utility
        RA[r] 
        - 
        (
# labor income        
        PL[r] * sum(ld0[r,s] for s in sectors)
# capital income        
        + sum((haskey(PK.lookup[1], (r, s)) ? PK[(r,s)] : 1.0) * kd0[r,s] for s in sectors)
# provision of household supply          
        + sum( (haskey(PY.lookup[1], (r, g)) ? PY[(r, g)] : 1.0) * yh0[r,g] for g in goods)
# revenue or costs of foreign exchange including household adjustment   
        + PFX * (bopdef0[r] + hhadj[r])
# government and investment provision        
        - sum((haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * (g0[r,g] + i0[r,g]) for g in goods)
# import taxes - assumes lumpsum recycling
        + sum((haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.) * MD[r,g] * PFX * tm[r,g] for g in goods if (a_set[r,g] != 0))
# taxes on intermediate demand - assumes lumpsum recycling
        + sum((haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.) * a0[r,g]*(haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0)*ta[r,g] for g in goods if (a_set[r,g] != 0) )
# production taxes - assumes lumpsum recycling  
        + sum( (haskey(Y.lookup[1], (r, s)) ? Y[(r, s)] : 1) * ys0[r,s,g] * ty[r,s] for s in sectors, g in goods)
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

# export the path license string to the environment
# this is now done in the SLiDE initiation steps 
# ENV["PATH_LICENSE_STRING"]="2617827524&Courtesy&&&USR&64785&11_12_2017&1000&PATH&GEN&31_12_2020&0_0_0&5000&0_0"

# solve the model
status = solveMCP(cge)