####################################
#
# Extension of SLiDE model to include
#       dynamics and perfect foresight
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

function _model_input(year::Array{Int,1}, d::Dict{Symbol,DataFrame}, set::Dict, idx::Dict = Dict())
        @info("Preparing model data for $year.")
        
        d2 = Dict(k => filter_with(df, (yr = year,); extrapolate = true, drop = false) for (k,df) in d)
    
        isempty(idx) && (idx = Dict(k => findindex(df) for (k,df) in d2))
        (set, idx) = _model_set!(d2, set, idx)

        d1 = Dict(k => filter_with(df, (yr = year,); extrapolate = false, drop = true) for (k,df) in d)
        d1 = Dict(k => convert_type(Dict, fill_zero(set, df)) for (k,df) in d1)
        return (d1, set, idx)
end

function _model_input(year::UnitRange{Int64}, d::Dict{Symbol,DataFrame}, set::Dict, idx::Dict = Dict())
        return _model_input(ensurearray(year), d, set, idx)
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

#Specify benchmark year and end year for dynamic model time horizon
bmkyr = 2016
endyr = 2018

#Define range of years in time horizon
years = bmkyr:endyr

#Load slide data and time horizon to produce model data and appropriate time-indexed subsets
(sld, set, idx) = _model_input(years, d, set)

#last year is the maximum of all years
years_last = maximum(years)

#Create boolean indicators of first and last year of time horizon
bool_firstyear = Dict()
bool_lastyear = Dict()
for t in years
        if t!=years_last
                push!(bool_lastyear,t=>0)
        else
                push!(bool_lastyear,t=>1)
        end

        if t!=bmkyr
                push!(bool_firstyear,t=>0)
        else
                push!(bool_firstyear,t=>1)
        end
end


###############
# -- SETS --
###############

#Read sets from SLiDE build dictionary
# set[:r] = set[:r]
# set[:s] = set[:s]
# set[:g] = set[:g]
# set[:m] = set[:m]
# set[:gm] = set[:gm]

#Subsetting for terminal capital - omit year index
set[:PKT] = filter(x -> sld[:kd0][x] != 0.0, permute(set[:r], set[:s]));

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

# Temporal/Dynamic modifications
@NLparameter(cge, ir == 0.05); # Interest rate
#model only solves with zero growth rate currently
@NLparameter(cge, gr == 0.0); # Growth rate
@NLparameter(cge, dr == 0.02); # Depreciation rate

@NLparameter(cge, pvm[yr in years] == (1/(1+value(ir)))^(yr-bmkyr)); # Reference price path - Present value multiplier
@NLparameter(cge, qvm[yr in years] == (1 + value(gr))^(yr-bmkyr)); # Reference quantity path multiplier

@NLparameter(cge, rk0 == value(ir) + value(dr)); # Initial return to capital 

###Not used, will likely be used in updated model
# Initial capital earnings vk0
@NLparameter(cge, vk0[r in set[:r], s in set[:s]] == value(kd0[r,s]));
# Initial capital stock k0 
@NLparameter(cge, k0[r in set[:r], s in set[:s]] == value(vk0[r,s])/value(rk0));
# Initial investment inv0
@NLparameter(cge, inv0[r in set[:r], s in set[:s]] == (value(dr)+value(gr))*value(k0[r,s]));
###

##################
# -- VARIABLES -- 
##################

# small value that acts as a lower limit to variable values
# default is zero
lo = 0.00

# set[:s]
@variable(cge, Y[(yr,r,s) in set[:Y]] >= lo, start = value(qvm[yr])); #
@variable(cge, X[(yr,r,g) in set[:X]] >= lo, start = value(qvm[yr])); #
@variable(cge, A[(yr,r,g) in set[:A]] >= lo, start = value(qvm[yr])); # 
@variable(cge, C[yr in years, r in set[:r]] >= lo, start = value(qvm[yr])); #
@variable(cge, MS[yr in years, r in set[:r], m in set[:m]] >= lo, start = value(qvm[yr])); #

@variable(cge, K[(yr,r,s) in set[:PK]] >= lo, start = value(qvm[yr])*value(kd0[r,s])); # Capital
@variable(cge, I[(yr,r,s) in set[:PK]] >= lo, start = value(qvm[yr])*(value(dr)+value(gr))*value(kd0[r,s])); # Investment
@variable(cge, TK[(r,s) in set[:PKT]] >= lo, start = value(kd0[r,s]) * value(qvm[years_last])*(1+value(gr))); # Terminal Capital

#Future updates to capital stock/investment
# @variable(cge, K[(yr,r,s) in set[:PK]] >= lo, start = value(qvm[yr])*value(k0[r,s])); # Capital
# @variable(cge, I[(yr,r,s) in set[:PK]] >= lo, start = value(qvm[yr])*value(inv0[r,s])); #investment
# @variable(cge, TK[(r,s) in set[:PKT]] >= lo, start = value(k0[r,s]) * (1 + value(gr))^(years_last-bmkyr)); # Terminal Capital

# commodities
@variable(cge, PA[(yr,r,g) in set[:PA]] >= lo, start = value(pvm[yr])); # Regional market (input)
@variable(cge, PY[(yr,r,g) in set[:PY]] >= lo, start = value(pvm[yr])); # Regional market (output)
@variable(cge, PD[(yr,r,g) in set[:PD]] >= lo, start = value(pvm[yr])); # Local market price
@variable(cge, PN[yr in years, g in set[:g]] >= lo, start = value(pvm[yr])); # National market
@variable(cge, PL[yr in years, r in set[:r]] >= lo, start = value(pvm[yr])); # Wage rate
@variable(cge, PM[yr in years, r in set[:r], m in set[:m]] >= lo, start = value(pvm[yr])); # Margin price
@variable(cge, PC[yr in years, r in set[:r]] >= lo, start = value(pvm[yr])); # Consumer price index #####
@variable(cge, PFX[yr in years] >= lo, start = value(pvm[yr])); # Foreign exchange

@variable(cge, PK[(yr,r,s) in set[:PK]] >= lo, start = value(pvm[yr]) * (1 + value(ir))); # Price of capital
@variable(cge, RK[(yr,r,s) in set[:PK]] >= lo, start = value(pvm[yr])*value(rk0)); # Capital rental rate
@variable(cge, PKT[(r,s) in set[:PKT]] >= lo, start = value(pvm[years_last])); # Terminal capital price
#@variable(cge, PKT[(r,s) in set[:PKT]] >= lo, start = start_value(PK[years_last,r,s])/(1+value(ir)); # Terminal capital price

# consumer
@variable(cge,RA[yr in years, r in set[:r]]>=lo,start = value(qvm[yr])*value(pvm[yr])*value(c0[r])); #Representative Agent

# Values when zero or missing from set control
# For haskey variable filters
fixV=Dict()
fixV[:Y]=1.0
fixV[:X]=1.0
fixV[:A]=1.0
fixV[:K]=0.0
fixV[:I]=0.0
fixV[:TK]=0.0

fixV[:PA]=1.0
fixV[:PY]=1.0
fixV[:PD]=1.0
fixV[:RK]=1.0
fixV[:PK]=1.0
fixV[:PKT]=1.0

###############################
# -- PLACEHOLDER VARIABLES --
###############################

#cobb-douglas function for value added (VA)
@NLexpression(cge,CVA[yr in years,r in set[:r],s in set[:s]],
  PL[yr,r]^alpha_kl[r,s] * ((haskey(RK.lookup[1], (yr,r,s)) ? RK[(yr,r,s)] : 1.0)/rk0)^ (1-alpha_kl[r,s]) );

#demand for labor in VA
@NLexpression(cge,AL[yr in years, r in set[:r], s in set[:s]], ld0[r,s] * CVA[yr,r,s] / PL[yr,r] );

#demand for capital in VA
@NLexpression(cge,AK[yr in years, r in set[:r],s in set[:s]],
  kd0[r,s] * CVA[yr,r,s] / ((haskey(RK.lookup[1], (yr,r,s)) ? RK[(yr,r,s)] : 1.0)/rk0));

#CES function for output demand - including
# exports (absent of re-exports) times the price for foreign exchange, 
# region's supply to national market times the national market price
# regional supply to local market times domestic price

@NLexpression(cge,RX[yr in years,r in set[:r],g in set[:g]],
  (alpha_x[r,g]*PFX[yr]^(1 + et_x[r,g])+alpha_n[r,g]*PN[yr,g]^(1 + et_x[r,g])+alpha_d[r,g]*(haskey(PD.lookup[1], (yr,r,g)) ? PD[(yr,r,g)] : 1.0)^(1 + et_x[r,g]))^(1/(1 + et_x[r,g])) );

#demand for exports via demand function
@NLexpression(cge,AX[yr in years,r in set[:r],g in set[:g]], (x0[r,g] - rx0[r,g])*(PFX[yr]/RX[yr,r,g])^et_x[r,g] );

#demand for contribution to national market 
@NLexpression(cge,AN[yr in years,r in set[:r],g in set[:g]], xn0[r,g]*(PN[yr,g]/(RX[yr,r,g]))^et_x[r,g] );

#demand for regionals supply to local market
@NLexpression(cge,AD[yr in years,r in set[:r],g in set[:g]],
  xd0[r,g] * ((haskey(PD.lookup[1], (yr,r,g)) ? PD[(yr,r,g)] : 1.0) / (RX[yr,r,g]))^et_x[r,g] );

# CES function for tradeoff between national and domestic market
@NLexpression(cge,CDN[yr in years,r in set[:r],g in set[:g]],
(theta_n[r,g]*PN[yr,g]^(1-es_d[r,g])+(1-theta_n[r,g])*(haskey(PD.lookup[1], (yr,r,g)) ? PD[(yr,r,g)] : 1.0)^(1-es_d[r,g]))^(1/(1-es_d[r,g])) );

# CES function for tradeoff between domestic consumption and foreign exports
# recall tm in the import tariff thus tm / tm0 is the relative change in import tariff rates
@NLexpression(cge,CDM[yr in years,r in set[:r],g in set[:g]],
((1-theta_m[r,g])*CDN[yr,r,g]^(1-es_f[r,g])+theta_m[r,g]*(PFX[yr]*(1+tm[r,g])/(1+tm0[r,g]))^(1-es_f[r,g]))^(1/(1-es_f[r,g])) );

# set[:r] demand from the national market <- note nesting of CDN in CDM
@NLexpression(cge,DN[yr in years,r in set[:r],g in set[:g]],
  nd0[r,g]*(CDN[yr,r,g]/PN[yr,g])^es_d[r,g]*(CDM[yr,r,g]/CDN[yr,r,g])^es_f[r,g] );

# region demand from local market <- note nesting of CDN in CDM
@NLexpression(cge,DD[yr in years,r in set[:r],g in set[:g]],
  dd0[r,g]*(CDN[yr,r,g]/(haskey(PD.lookup[1], (yr,r,g)) ? PD[(yr,r,g)] : 1.0))^es_d[r,g]*(CDM[yr,r,g]/CDN[yr,r,g])^es_f[r,g] );

# import demand
@NLexpression(cge,MD[yr in years,r in set[:r],g in set[:g]],
  m0[r,g]*(CDM[yr,r,g]*(1+tm[r,g])/(PFX[yr]*(1+tm0[r,g])))^es_f[r,g] );

# final demand
@NLexpression(cge,CD[yr in years,r in set[:r],g in set[:g]],
  cd0[r,g]*PC[yr,r] / (haskey(PA.lookup[1], (yr,r,g)) ? PA[(yr,r,g)] : 1.0) );


###############################
# -- Zero Profit Conditions --
###############################

@mapping(cge,profit_y[(yr,r,s) in set[:Y]],
# cost of intermediate demand
        sum((haskey(PA.lookup[1], (yr,r,g)) ? PA[(yr,r,g)] : 1.0) * id0[r,g,s] for g in set[:g]) 
# cost of labor inputs
        + PL[yr,r] * AL[yr,r,s]
# cost of capital inputs 
        + ((haskey(RK.lookup[1], (yr,r,s)) ? RK[(yr,r,s)] : 1.0)/rk0)* AK[yr,r,s]
        - 
# revenue from sectoral supply (take note of r/s/g indices on ys0)                
        sum((haskey(PY.lookup[1], (yr,r,g)) ? PY[(yr,r,g)] : 1.0)  * ys0[r,s,g] for g in set[:g]) * (1-ty[r,s])
);

@mapping(cge,profit_x[(yr,r,g) in set[:X]],
# output 'cost' from aggregate supply
         (haskey(PY.lookup[1], (yr,r,g)) ? PY[(yr,r,g)] : 1.0) * s0[r,g] 
        - (
# revenues from foreign exchange
        PFX[yr] * AX[yr,r,g]
# revenues from national market                  
        + PN[yr,g] * AN[yr,r,g]
# revenues from domestic market
        + (haskey(PD.lookup[1], (yr,r,g)) ? PD[(yr,r,g)] : 1.0) * AD[yr,r,g]
        )
);

@mapping(cge,profit_a[(yr,r,g) in set[:A]],
# costs from national market
        PN[yr,g] * DN[yr,r,g] 
# costs from domestic market                  
        + (haskey(PD.lookup[1], (yr,r,g)) ? PD[(yr,r,g)] : 1.0) * DD[yr,r,g] 
# costs from imports, including import tariff
        + PFX[yr] * (1+tm[r,g]) * MD[yr,r,g]
# costs of margin demand                
        + sum(PM[yr,r,m] * md0[r,m,g] for m in set[:m])
        - ( 
# revenues from regional market based on armington supply               
        (haskey(PA.lookup[1], (yr,r,g)) ? PA[(yr,r,g)] : 1.0) * (1-ta[r,g]) * a0[r,g] 
# revenues from re-exports                   
        + PFX[yr] * rx0[r,g]
        )
);

@mapping(cge, profit_c[yr in years,r in set[:r]],
# costs of inputs - computed as final demand times regional market prices
        sum((haskey(PA.lookup[1], (yr,r,g)) ? PA[(yr,r,g)] : 1.0) * CD[yr,r,g] for g in set[:g])
        - 
# revenues/benefit computed as CPI * reference consumption                  
        PC[yr,r] * c0[r]
);

@mapping(cge,profit_k[(yr,r,s) in set[:PK]],
        (haskey(PK.lookup[1], (yr,r,s)) ? PK[(yr,r,s)] : 1.0)
        - (
        (haskey(RK.lookup[1], (yr,r,s)) ? RK[(yr,r,s)] : 1.0)
        + (1-dr) * (yr!=years_last ? (haskey(PK.lookup[1], (yr+1,r,s)) ? PK[(yr+1,r,s)] : 1.0) : (haskey(PKT.lookup[1], (r,s)) ? PKT[(r,s)] : 1.0))
        )
);

@mapping(cge,profit_i[(yr,r,s) in set[:PK]],
        (haskey(PY.lookup[1], (yr,r,s)) ? PY[(yr,r,s)] : 1.0)
        - 
        (yr!=years_last ? (haskey(PK.lookup[1], (yr+1,r,s)) ? PK[(yr+1,r,s)] : 1.0) : (haskey(PKT.lookup[1], (r,s)) ? PKT[(r,s)] : 1.0))
);

@mapping(cge,profit_ms[yr in years,r in set[:r],m in set[:m]],
# provision of set[:m] to national market
        sum(PN[yr,gm]   * nm0[r,gm,m] for gm in set[:gm])
# provision of set[:m] to domestic market    
        + sum((haskey(PD.lookup[1], (yr,r,gm)) ? PD[(yr,r,gm)] : 1.0) * dm0[r,gm,m] for gm in set[:gm])
        - 
# total margin demand    
        PM[yr,r,m] * sum(md0[r,m,gm] for gm in set[:gm])
);


###################################
# -- Market Clearing Conditions -- 
###################################

@mapping(cge,market_pa[(yr,r,g) in set[:PA]],
# absorption or supply
        (haskey(A.lookup[1], (yr,r,g)) ? A[(yr,r,g)] : 1.0) * a0[r,g] 
        - ( 
# government demand (exogenous)       
        g0[r,g]*qvm[yr]
# demand for investment (exogenous)
        + i0[r,g]*qvm[yr]
# final demand        
        + C[yr,r] * CD[yr,r,g]
# intermediate demand        
        + sum((haskey(Y.lookup[1], (yr,r,s)) ? Y[(yr,r,s)] : 1.0) * id0[r,g,s] for s in set[:s] if (yr,r,s) in set[:Y])
        )
);

@mapping(cge,market_py[(yr,r,g) in set[:PY]],
# sectoral supply
        sum((haskey(Y.lookup[1], (yr,r,s)) ? Y[(yr,r,s)] : 1.0) *ys0[r,s,g] for s in set[:s])
# household production (exogenous)        
        + yh0[r,g]*qvm[yr]
        - 
# aggregate supply (akin to market demand)                
       (haskey(X.lookup[1], (yr,r,g)) ? X[(yr,r,g)] : 1.0) * s0[r,g]
);

@mapping(cge,market_pd[(yr,r,g) in set[:PD]],
# aggregate supply
        (haskey(X.lookup[1], (yr,r,g)) ? X[(yr,r,g)] : 1.0)  * AD[yr,r,g] 
        - ( 
# demand for local market          
        (haskey(A.lookup[1], (yr,r,g)) ? A[(yr,r,g)] : 1.0) * DD[yr,r,g]
# margin supply from local market
        + sum(MS[yr,r,m] * dm0[r,g,m] for m in set[:m] if (g in set[:gm] ) )  
        )
);

@mapping(cge,market_pn[yr in years,g in set[:g]],
# supply to the national market
        sum((haskey(X.lookup[1], (yr,r,g)) ? X[(yr,r,g)] : 1.0)  * AN[yr,r,g] for r in set[:r])
        - ( 
# demand from the national market 
        sum((haskey(A.lookup[1], (yr,r,g)) ? A[(yr,r,g)] : 1.0) * DN[yr,r,g] for r in set[:r])
# market supply to the national market        
        + sum(MS[yr,r,m] * nm0[r,g,m] for r in set[:r] for m in set[:m] if (g in set[:gm]) )
        )
);

@mapping(cge,market_pl[yr in years,r in set[:r]],
# supply of labor
        sum(ld0[r,s]*qvm[yr] for s in set[:s])
        - 
# demand for labor in all set[:s]        
       sum((haskey(Y.lookup[1], (yr,r,s)) ? Y[(yr,r,s)] : 1.0) * AL[yr,r,s] for s in set[:s])
);

@mapping(cge,market_pk[(yr,r,s) in set[:PK]],
# if first year, initial capital
# else investment plus previous year's decayed capital
        (yr==bmkyr ? kd0[r,s] : (haskey(I.lookup[1], (yr-1,r,s)) ? I[(yr-1,r,s)] : 0.0))
        +(1-dr) * (yr>bmkyr ? (haskey(K.lookup[1], (yr-1,r,s)) ? K[(yr-1,r,s)] : 0.0) : 0.0)
        - 
#current year's capital capital        
        (haskey(K.lookup[1], (yr,r,s)) ? K[(yr,r,s)] : 0.0)
);

@mapping(cge,market_rk[(yr,r,s) in set[:PK]],
        (haskey(K.lookup[1], (yr,r,s)) ? K[(yr,r,s)] : 0.0)
        -
        (haskey(Y.lookup[1], (yr,r,s)) ? Y[(yr,r,s)] : 1.0) * AK[yr,r,s]
);

@mapping(cge,market_pkt[(r,s) in set[:PKT]],
        (1-dr)*(haskey(K.lookup[1], (years_last,r,s)) ? K[(years_last,r,s)] : 0.0)
        + (haskey(I.lookup[1], (years_last,r,s)) ? I[(years_last,r,s)] : 0.0)
        - 
        (haskey(TK.lookup[1], (r,s)) ? TK[(r,s)] : 0.0)
);

@mapping(cge,termk[(r,s) in set[:PKT]],
        (haskey(I.lookup[1], (years_last,r,s)) ? I[(years_last,r,s)] : 0.0)
        / ((haskey(I.lookup[1], (years_last-1,r,s)) ? I[(years_last-1,r,s)] : 0.0))
        - 
        (haskey(Y.lookup[1], (years_last,r,s)) ? Y[(years_last,r,s)] : 1.0)
        / (haskey(Y.lookup[1], (years_last-1,r,s)) ? Y[(years_last-1,r,s)] : 1.0) 
);

@mapping(cge,market_pm[yr in years,r in set[:r], m in set[:m]],
# margin supply 
        MS[yr,r,m] * sum(md0[r,m,gm] for gm in set[:gm])
        - 
# margin demand        
        sum((haskey(A.lookup[1], (yr,r,g)) ? A[(yr,r,g)] : 1.0) * md0[r,m,g] for g in set[:g])
);

@mapping(cge,market_pfx[yr in years],
# balance of payments (exogenous)
        sum(bopdef0[r] for r in set[:r])*qvm[yr]
# supply of exports     
        + sum((haskey(X.lookup[1], (yr,r,g)) ? X[(yr,r,g)] : 1.0)  * AX[yr,r,g] for r in set[:r] for g in set[:g])
# supply of re-exports        
        + sum((haskey(A.lookup[1], (yr,r,g)) ? A[(yr,r,g)] : 1.0) * rx0[r,g] for r in set[:r] for g in set[:g] if (yr,r,g) in set[:A])
        - 
# import demand                
        sum((haskey(A.lookup[1], (yr,r,g)) ? A[(yr,r,g)] : 1.0) * MD[yr,r,g] for r in set[:r] for g in set[:g] if (yr,r,g) in set[:A])
);

@mapping(cge,market_pc[yr in years,r in set[:r]],
# a period's final demand
        C[yr,r] * c0[r]
        - 
# consumption / utiltiy        
        RA[yr,r] / PC[yr,r]
);

@mapping(cge,income_ra[yr in years,r in set[:r]],
# consumption/utility
        RA[yr,r]
        - 
        (
# labor income        
        PL[yr,r] * sum(ld0[r,s] for s in set[:s])*qvm[yr]
# provision of household supply          
        + sum( (haskey(PY.lookup[1], (yr,r,g)) ? PY[(yr,r,g)] : 1.0) * yh0[r,g]*qvm[yr] for g in set[:g])
# revenue or costs of foreign exchange including household adjustment   
        + PFX[yr] * (bopdef0[r] + hhadj[r])*qvm[yr]
# government and investment provision        
        - sum((haskey(PA.lookup[1], (yr,r,g)) ? PA[(yr,r,g)] : 1.0) * (g0[r,g] + i0[r,g])*qvm[yr] for g in set[:g])
# import taxes - assumes lumpsum recycling
        + sum((haskey(A.lookup[1], (yr,r,g)) ? A[(yr,r,g)] : 1.0) * MD[yr,r,g] * PFX[yr] * tm[r,g] for g in set[:g] if (yr,r,g) in set[:A])
# taxes on intermediate demand - assumes lumpsum recycling
        + sum((haskey(A.lookup[1], (yr,r,g)) ? A[(yr,r,g)] : 1.0) * a0[r,g]*(haskey(PA.lookup[1], (yr,r,g)) ? PA[(yr,r,g)] : 1.0)*ta[r,g] for g in set[:g] if (yr,r,g) in set[:A])
# production taxes - assumes lumpsum recycling  
        + sum( pvm[yr]*(haskey(Y.lookup[1], (yr,r,s)) ? Y[(yr,r,s)] : 1.0) * ys0[r,s,g] * ty[r,s] for s in set[:s], g in set[:g])
# capital income        
        + (1-bool_lastyear[yr]) * sum((haskey(PK.lookup[1], (yr,r,s)) ? PK[(yr,r,s)] : 1.0) * (haskey(K.lookup[1], (yr,r,s)) ? K[(yr,r,s)] : 0.0) for s in set[:s]) / (1+ir)
        + (bool_lastyear[yr]) * sum((haskey(PKT.lookup[1], (r,s)) ? PKT[(r,s)] : 1.0) * (haskey(TK.lookup[1], (r,s)) ? TK[(r,s)] : 0.0) for s in set[:s])
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
@complementarity(cge,market_pm,PM);
@complementarity(cge,market_pc,PC);
@complementarity(cge,market_pfx,PFX);
@complementarity(cge,income_ra,RA);
@complementarity(cge,market_pk,PK);
@complementarity(cge,market_rk,RK);
@complementarity(cge,market_pkt,PKT)
@complementarity(cge,termk,TK)
@complementarity(cge,profit_k,K)
@complementarity(cge,profit_i,I)


####################
# -- Model Solve --
####################

#set up the options for the path solver
#PATHSolver.options(convergence_tolerance=1e-6, output=:yes, time_limit=3600, cumulative_iteration_limit=0)
PATHSolver.options(convergence_tolerance=1e-6, output=:yes, time_limit=3600, cumulative_iteration_limit=0)

# solve the model
status = solveMCP(cge)

