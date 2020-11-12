####################################
#
# Extension of Canonical blueNOTE 
#    model to include dynamics
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
    (set[:PA], idx[:PA]) = (set[:A], idx[:A])
    (set[:PD], idx[:PA]) = nonzero_subset(d[:xd0])
    (set[:PK], idx[:PK]) = nonzero_subset(d[:kd0])
    (set[:PY], idx[:PY]) = (set[:PK], idx[:PK])
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

# -- Temporal setup --

#last year is the maximum of all years
years_last = maximum(years)
#years = [mod_year, 2018, 2020]

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


# -- Major Assumptions -- 
# rho = 0.04    # discount factor   
# i = 0.05      # interest rate         
# g = 0.0      # growth rate
# delta  = 0.02 # capital depreciation factor

# # present value multiplier
# pvm = Dict()

# # share of consumption in current period to value over time 
# alpha = Dict()
# for t in years
#         push!(pvm,t=>(1/(1+i))^(t-mod_year))
#         push!(alpha,t=>((1 + g) / (1 + i) ) ^(t-mod_year) )
# end

# t_alpha = sum(alpha[tt] for tt in years)

# for k in keys(alpha)
#         alpha[k] = alpha[k] / t_alpha
# end

# #steady state rental rate of capital is interest plus depreciation
# rk0 = i + delta



###############
# -- SETS --
###############

#Read sets from SLiDE build dictionary
regions = set[:r]
sectors = set[:s]
goods = set[:g]
margins = set[:m]
goods_margins = set[:gm]

set[:PKT] = filter(x -> sld[:kd0][x] != 0.0, permute(set[:r], set[:s]));

########## Model ##########
cge = MCPModel();

##############
# PARAMETERS
##############

#benchmark values
@NLparameter(cge, ys0[r in regions, s in sectors, g in goods] == sld[:ys0][r,s,g]); 
@NLparameter(cge, id0[r in regions, s in sectors, g in goods] == sld[:id0][r,s,g]);
@NLparameter(cge, ld0[r in regions, s in sectors] == sld[:ld0][r,s]);
@NLparameter(cge, kd0[r in regions, s in sectors] == sld[:kd0][r,s]);
@NLparameter(cge, ty0[r in regions, s in sectors] == sld[:ty0][r,s]);
@NLparameter(cge, ty[r in regions, s in sectors] == sld[:ty0][r,s]);
@NLparameter(cge, m0[r in regions, g in goods] == sld[:m0][r,g]);
@NLparameter(cge, x0[r in regions, g in goods] == sld[:x0][r,g]);
@NLparameter(cge, rx0[r in regions, g in goods] == sld[:rx0][r,g]);
@NLparameter(cge, md0[r in regions, m in margins, g in goods] == sld[:md0][r,m,g]);
@NLparameter(cge, nm0[r in regions, g in goods, m in margins] == sld[:nm0][r,g,m]);
@NLparameter(cge, dm0[r in regions, g in goods, m in margins] == sld[:dm0][r,g,m]);
@NLparameter(cge, s0[r in regions, g in goods] == sld[:s0][r,g]);
@NLparameter(cge, a0[r in regions, g in goods] == sld[:a0][r,g]);
@NLparameter(cge, ta0[r in regions, g in goods] == sld[:ta0][r,g]);
@NLparameter(cge, ta[r in regions, g in goods] == sld[:ta0][r,g]);
@NLparameter(cge, tm0[r in regions, g in goods] == sld[:tm0][r,g]);
@NLparameter(cge, tm[r in regions, g in goods] == sld[:tm0][r,g]);
@NLparameter(cge, cd0[r in regions, g in goods] == sld[:cd0][r,g]);
@NLparameter(cge, c0[r in regions] == sld[:c0][r]);
@NLparameter(cge, yh0[r in regions, g in goods] == sld[:yh0][r,g]);
@NLparameter(cge, bopdef0[r in regions] == sld[:bopdef0][r]);
@NLparameter(cge, hhadj[r in regions] == sld[:hhadj][r]);
@NLparameter(cge, g0[r in regions, g in goods] == sld[:g0][r,g]);
@NLparameter(cge, xn0[r in regions, g in goods] == sld[:xn0][r,g]);
@NLparameter(cge, xd0[r in regions, g in goods] == sld[:xd0][r,g]);
@NLparameter(cge, dd0[r in regions, g in goods] == sld[:dd0][r,g]);
@NLparameter(cge, nd0[r in regions, g in goods] == sld[:nd0][r,g]);
@NLparameter(cge, i0[r in regions, g in goods] == sld[:i0][r,g]);

# benchmark value share parameters
@NLparameter(cge, alpha_kl[r in regions, s in sectors] == ensurefinite(value(ld0[r,s]) / (value(ld0[r,s]) + value(kd0[r,s])))); 
@NLparameter(cge, alpha_x[r in regions, g in goods] == ensurefinite((value(x0[r,g]) - value(rx0[r,g])) / value(s0[r,g])));
@NLparameter(cge, alpha_d[r in regions, g in goods] == ensurefinite(value(xd0[r,g]) / value(s0[r,g])));
@NLparameter(cge, alpha_n[r in regions, g in goods] == ensurefinite(value(xn0[r,g]) / value(s0[r,g])));
@NLparameter(cge, theta_n[r in regions, g in goods] == ensurefinite(value(nd0[r,g]) / (value(nd0[r,g]) - value(dd0[r,g]))));
@NLparameter(cge, theta_m[r in regions, g in goods] == ensurefinite((1+value(tm0[r,g])) * value(m0[r,g]) / (value(nd0[r,g]) + value(dd0[r,g]) + (1 + value(tm0[r,g])) * value(m0[r,g]))));

#Substitution and transformation elasticities
@NLparameter(cge, es_va[r in regions, s in sectors] == SUB_ELAST[:va]); # value-added nest - substitution elasticity
@NLparameter(cge, es_y[r in regions, s in sectors]  == SUB_ELAST[:y]); # Top-level Y nest (VA,M) - substitution elasticity
@NLparameter(cge, es_m[r in regions, s in sectors]  == SUB_ELAST[:m]); # Materials nest - substitution elasticity
@NLparameter(cge, et_x[r in regions, g in goods]    == TRANS_ELAST[:x]); # Disposition, distribute regional supply to local, national, export - transformation elasticity
@NLparameter(cge, es_a[r in regions, g in goods]    == SUB_ELAST[:a]); # Top-level A nest for aggregate demand (Margins, goods) - substitution elasticity
@NLparameter(cge, es_mar[r in regions, g in goods]  == SUB_ELAST[:mar]); # Margin supply - substitution elasticity
@NLparameter(cge, es_d[r in regions, g in goods]    == SUB_ELAST[:d]); # Domestic demand aggregation nest (intranational) - substitution elasticity
@NLparameter(cge, es_f[r in regions, g in goods]    == SUB_ELAST[:f]); # Domestic and foreign demand aggregation nest (international) - substitution elasticity

# Temporal/Dynamic modifications
@NLparameter(cge, ir == 0.05); # Interest rate
@NLparameter(cge, gr == 0.0); # Growth rate
@NLparameter(cge, dr == 0.02); # Depreciation rate

@NLparameter(cge, pvm[yr in years] == (1/(1+value(ir)))^(yr-bmkyr)); # Reference price path - Present value multiplier
@NLparameter(cge, qvm[yr in years] == (1 + value(gr))^(yr-bmkyr)); # Reference quantity path multiplier

@NLparameter(cge, rk0 == value(ir) + value(dr)); # Initial return to capital 

# Initial capital earnings vk0
@NLparameter(cge, vk0[r in regions, s in sectors] == value(kd0[r,s]));
# Initial capital stock k0 
@NLparameter(cge, k0[r in regions, s in sectors] == value(vk0[r,s])/value(rk0));
# Initial investment inv0
@NLparameter(cge, inv0[r in regions, s in sectors] == (value(dr)+value(gr))*value(k0[r,s]));

##################
# -- VARIABLES -- 
##################

# small value that acts as a lower limit to variable values
# default is zero
lo = 0.00

# sectors
@variable(cge, Y[yr in years, r in regions, s in sectors] >= lo, start = 1); #
@variable(cge, X[(yr,r,g) in set[:X]] >= lo, start = 1); #
@variable(cge, A[(yr,r,g) in set[:A]] >= lo, start = 1); # 
@variable(cge, C[yr in years, r in regions] >= lo, start = 1); #
@variable(cge, MS[yr in years, r in regions, m in margins] >= lo, start = 1); #


# commodities
@variable(cge, PA[(yr,r,g) in set[:PA]] >= lo, start = value(pvm[yr])); # Regional market (input)
@variable(cge, PY[yr in years, r in regions, s in sectors] >= lo, start = value(pvm[yr])); # Regional market (output)
@variable(cge, PD[(yr,r,g) in set[:PD]] >= lo, start = value(pvm[yr])); # Local market price
@variable(cge, PN[yr in years, g in goods] >= lo, start = value(pvm[yr])); # National market
@variable(cge, PL[yr in years, r in regions] >= lo, start = value(pvm[yr])); # Wage rate
@variable(cge, PM[yr in years, r in regions, m in margins] >= lo, start = value(pvm[yr])); # Margin price
@variable(cge, PC[yr in years, r in regions] >= lo, start = value(pvm[yr])); # Consumer price index #####
@variable(cge, PFX[yr in years] >= lo, start = value(pvm[yr])); # Foreign exchange

@variable(cge, PK[yr in years, r in regions, s in sectors] >= lo, start = value(pvm[yr]) * (1 + value(ir))); # Price of capital
@variable(cge, RK[yr in years, r in regions, s in sectors] >= lo, start = value(pvm[yr])*value(rk0)); # Capital rental rate
@variable(cge, PKT[r in regions, s in sectors] >= lo, start = value(pvm[years_last])); # Terminal capital price

# @variable(cge, PK[(yr,r,s) in set[:PK]] >= lo, start = value(pvm[yr]) * (1 + value(ir))); # Price of capital
# @variable(cge, RK[(yr,r,s) in set[:PK]] >= lo, start = value(pvm[yr])*value(rk0)); # Capital rental rate
# @variable(cge, PKT[(r,s) in set[:PKT]] >= lo, start = value(pvm[years_last])); # Terminal capital price
#@variable(cge, PKT[(r,s) in set[:PKT]] >= lo, start = start_value(PK[years_last,r,s])/(1+value(ir)); # Terminal capital price

@variable(cge, K[yr in years, r in regions, s in sectors] >= lo, start = 1*value(kd0[r,s])); # Capital
@variable(cge, I[yr in years, r in regions, s in sectors] >= lo, start = 1*(value(dr)+0)*value(kd0[r,s])); #investment
@variable(cge, TK[r in regions, s in sectors] >= lo, start = value(kd0[r,s]) * (1 + 0)^(years_last-bmkyr)); # Terminal Capital

# @variable(cge, K[(yr,r,s) in set[:PK]] >= lo, start = value(qvm[yr])*value(kd0[r,s])); # Capital
# @variable(cge, I[(yr,r,s) in set[:PK]] >= lo, start = value(qvm[yr])*(value(dr)+value(gr))*value(kd0[r,s])); #investment
# @variable(cge, TK[(r,s) in set[:PKT]] >= lo, start = value(kd0[r,s]) * (1 + value(gr))^(years_last-bmkyr)); # Terminal Capital

# @variable(cge, K[(yr,r,s) in set[:PK]] >= lo, start = value(qvm[yr])*value(k0[r,s])); # Capital
# @variable(cge, I[(yr,r,s) in set[:PK]] >= lo, start = value(qvm[yr])*value(inv0[r,s])); #investment
# @variable(cge, TK[(r,s) in set[:PKT]] >= lo, start = value(k0[r,s]) * (1 + value(gr))^(years_last-bmkyr)); # Terminal Capital

# consumer
@variable(cge,RA[yr in years, r in regions]>=lo,start = value(pvm[yr])*value(c0[r])); #Representative Agent

#RK -> CVA(profit_y, market_pl), AK(profit_y, market_rk), profit_y, profit_k
#PK -> profit_k, profit_i, income_ra
#PKT -> profit_k, profit_i, income_ra
#K -> market_pk, market_rk, market_pkt, income_ra
#TK -> market_pkt, income_ra
#I -> market_pk, market_pkt, termk (TK)


# #sectors
# @variable(cge,Y[r in regions, s in sectors, t in years]>=sv,start=1)
# @variable(cge,X[r in regions, g in goods, t in years]>=sv,start=1)
# @variable(cge,A[r in regions, g in goods, t in years]>=sv,start=1)
# @variable(cge,C[r in regions, t in years]>=sv,start=1)
# @variable(cge,MS[r in regions, m in margins, t in years]>=sv,start=1)
# @variable(cge,K[r in regions, s in sectors, t in years]>=sv,start=blueNOTE[:kd0][r,s])
# @variable(cge,I[r in regions, s in sectors, t in years]>=sv,start=(delta * blueNOTE[:kd0][r,s]))

# #commodities:
# @variable(cge,PA[r in regions, g in goods, t in years]>=sv,start=pvm[t]) # Regional market (input)
# @variable(cge,PY[r in regions, g in goods, t in years]>=sv,start=pvm[t]) # Regional market (output)
# @variable(cge,PD[r in regions, g in goods, t in years]>=sv,start=pvm[t]) # Local market price
# @variable(cge,PN[g in goods, t in years]>=sv,start=pvm[t]) # National market
# @variable(cge,PL[r in regions, t in years]>=sv,start=pvm[t]) # Wage rate
# @variable(cge,PK[r in regions, s in sectors, t in years]>=sv,start=pvm[t] * (1+i)) # Rental rate of capital ###
# @variable(cge,RK[r in regions, s in sectors, t in years]>=sv,start=pvm[t] * rk0) # Capital return rate ###
# @variable(cge,TK[r in regions, s in sectors]>=sv,start=blueNOTE[:kd0][r,s]) ### Terminal capital amount
# @variable(cge,PKT[r in regions, s in sectors]>=sv,start=pvm[years_last]) # Terminal capital cost
# @variable(cge,PM[r in regions, m in margins, t in years]>=sv,start=pvm[t]) # Margin price
# @variable(cge,PC[r in regions, t in years]>=sv,start=pvm[t]) # Consumer price index #####
# @variable(cge,PFX[t in years]>=sv,start=pvm[t]) # Foreign exchange

# #consumer:
# #@variable(cge,RA[r in regions,t in years]>=sv,start=pvm[t] * blueNOTE[:c0][(r,)]) # Representative agent
# @variable(cge,RA[r in regions, t in years]>=sv,start = pvm[t] * blueNOTE[:c0][(r,)]) # Representative agent

# Values when zero or missing from set control
# For haskey variable filters
fixV=Dict()
fixV[:RK]=1.0
fixV[:PK]=1.0
fixV[:PA]=1.0
fixV[:PY]=1.0
fixV[:PD]=1.0
fixV[:Y]=1.0
fixV[:X]=1.0
fixV[:A]=1.0
fixV[:I]=0.0
fixV[:K]=0.0
fixV[:PKT]=1.0
fixV[:TK]=0.0

###############################
# -- PLACEHOLDER VARIABLES --
###############################

#cobb-douglas function for value added (VA)
@NLexpression(cge,CVA[yr in years,r in regions,s in sectors],
  PL[yr,r]^alpha_kl[r,s] * (RK[yr,r,s]/rk0)^ (1-alpha_kl[r,s]) );

#cobb-douglas function for value added (VA) ######
# @NLexpression(cge,CVA[r in regions,s in sectors,t in years],
#   PL[r,t]^alpha_kl[r,s] * (RK[r,s,t] / rk0) ^ (1-alpha_kl[r,s]) );

#demand for labor in VA
@NLexpression(cge,AL[yr in years, r in regions, s in sectors], ld0[r,s] * CVA[yr,r,s] / PL[yr,r] );

#demand for capital in VA
@NLexpression(cge,AK[yr in years, r in regions,s in sectors],
  kd0[r,s] * CVA[yr,r,s] / (RK[yr,r,s]/rk0));

#demand for labor in VA
# @NLexpression(cge,AL[r in regions, s in sectors, t in years],
#   blueNOTE[:ld0][r,s] * CVA[r,s,t] / PL[r,t] );

# #demand for capital in VA ######
# @NLexpression(cge,AK[r in regions,s in sectors, t in years],
#   blueNOTE[:kd0][r,s] * CVA[r,s,t] / (RK[r,s,t] / rk0) );

###

#CES function for output demand - including
# exports (absent of re-exports) times the price for foreign exchange, 
# region's supply to national market times the national market price
# regional supply to local market times domestic price

@NLexpression(cge,RX[yr in years,r in regions,g in goods],
  (alpha_x[r,g]*PFX[yr]^(1 + et_x[r,g])+alpha_n[r,g]*PN[yr,g]^(1 + et_x[r,g])+alpha_d[r,g]*(haskey(PD.lookup[1], (yr,r,g)) ? PD[(yr,r,g)] : 1.0)^(1 + et_x[r,g]))^(1/(1 + et_x[r,g])) );

#demand for exports via demand function
@NLexpression(cge,AX[yr in years,r in regions,g in goods], (x0[r,g] - rx0[r,g])*(PFX[yr]/RX[yr,r,g])^et_x[r,g] );

#demand for contribution to national market 
@NLexpression(cge,AN[yr in years,r in regions,g in goods], xn0[r,g]*(PN[yr,g]/(RX[yr,r,g]))^et_x[r,g] );

#demand for regionals supply to local market
@NLexpression(cge,AD[yr in years,r in regions,g in goods],
  xd0[r,g] * ((haskey(PD.lookup[1], (yr,r,g)) ? PD[(yr,r,g)] : 1.0) / (RX[yr,r,g]))^et_x[r,g] );


# @NLexpression(cge,RX[r in regions,g in goods, t in years],
#   (alpha_x[r,g]*PFX[t]^5+alpha_n[r,g]*PN[g,t]^5+alpha_d[r,g]*PD[r,g,t]^5)^(1/5) );

# #demand for exports via demand function
# @NLexpression(cge,AX[r in regions,g in goods, t in years],
#   (blueNOTE[:x0][r,g] - blueNOTE[:rx0][r,g])*(PFX[t]/RX[r,g,t])^4 );

# #demand for contribution to national market 
# @NLexpression(cge,AN[r in regions,g in goods, t in years],
#   blueNOTE[:xn0][r,g]*(PN[g,t]/(RX[r,g,t]))^4 );

# #demand for regionals supply to local market
# @NLexpression(cge,AD[r in regions,g in goods, t in years],
#   blueNOTE[:xd0][r,g] * (PD[r,g,t] / (RX[r,g,t]))^4 );

  ###

  # CES function for tradeoff between national and domestic market
@NLexpression(cge,CDN[yr in years,r in regions,g in goods],
(theta_n[r,g]*PN[yr,g]^(1-es_d[r,g])+(1-theta_n[r,g])*(haskey(PD.lookup[1], (yr,r,g)) ? PD[(yr,r,g)] : 1.0)^(1-es_d[r,g]))^(1/(1-es_d[r,g])) );

# CES function for tradeoff between domestic consumption and foreign exports
# recall tm in the import tariff thus tm / tm0 is the relative change in import tariff rates
@NLexpression(cge,CDM[yr in years,r in regions,g in goods],
((1-theta_m[r,g])*CDN[yr,r,g]^(1-es_f[r,g])+theta_m[r,g]*(PFX[yr]*(1+tm[r,g])/(1+tm0[r,g]))^(1-es_f[r,g]))^(1/(1-es_f[r,g])) );

# # CES function for tradeoff between national and domestic market
# @NLexpression(cge,CDN[r in regions,g in goods, t in years],
#   (theta_n[r,g]*PN[g,t]^(1-2)+(1-theta_n[r,g])*PD[r,g,t]^(1-2))^(1/(1-2)) );

# # CES function for tradeoff between domestic consumption and foreign exports
# # recall tm in the import tariff thus tm / tm0 is the relative change in import tariff rates
# @NLexpression(cge,CDM[r in regions,g in goods, t in years],
#   ((1-theta_m[r,g])*CDN[r,g,t]^(1-4)+theta_m[r,g]*
#   (PFX[t]*(1+blueNOTE[:tm][r,g])/(1+blueNOTE[:tm0][r,g]))^(1-4))^(1/(1-4)) 
#   );

  ###

# regions demand from the national market <- note nesting of CDN in CDM
@NLexpression(cge,DN[yr in years,r in regions,g in goods],
  nd0[r,g]*(CDN[yr,r,g]/PN[yr,g])^es_d[r,g]*(CDM[yr,r,g]/CDN[yr,r,g])^es_f[r,g] );

# region demand from local market <- note nesting of CDN in CDM
@NLexpression(cge,DD[yr in years,r in regions,g in goods],
  dd0[r,g]*(CDN[yr,r,g]/(haskey(PD.lookup[1], (yr,r,g)) ? PD[(yr,r,g)] : 1.0))^es_d[r,g]*(CDM[yr,r,g]/CDN[yr,r,g])^es_f[r,g] );

# import demand
@NLexpression(cge,MD[yr in years,r in regions,g in goods],
  m0[r,g]*(CDM[yr,r,g]*(1+tm[r,g])/(PFX[yr]*(1+tm0[r,g])))^es_f[r,g] );

# final demand
@NLexpression(cge,CD[yr in years,r in regions,g in goods],
  cd0[r,g]*PC[yr,r] / (haskey(PA.lookup[1], (yr,r,g)) ? PA[(yr,r,g)] : 1.0) );


# # regions demand from the national market <- note nesting of CDN in CDM
# @NLexpression(cge,DN[r in regions,g in goods, t in years],
#   blueNOTE[:nd0][r,g]*(CDN[r,g,t]/PN[g,t])^2*(CDM[r,g,t]/CDN[r,g,t])^4 );

# # region demand from local market <- note nesting of CDN in CDM
# @NLexpression(cge,DD[r in regions,g in goods, t in years],
#   blueNOTE[:dd0][r,g]*(CDN[r,g,t]/PD[r,g,t])^2*(CDM[r,g,t]/CDN[r,g,t])^4 );

# # import demand
# @NLexpression(cge,MD[r in regions,g in goods, t in years],
#   blueNOTE[:m0][r,g]*(CDM[r,g,t]*(1+blueNOTE[:tm][r,g])/(PFX[t]*(1+blueNOTE[:tm0][r,g])))^4 );

# # final demand
# @NLexpression(cge,CD[r in regions,g in goods, t in years],
#   blueNOTE[:cd0][r,g]*PC[r,t] / PA[r,g,t] );


###############################
# -- Zero Profit Conditions --
###############################

@mapping(cge,profit_y[yr in years, r in regions, s in sectors],
# cost of intermediate demand
        sum((haskey(PA.lookup[1], (yr,r,g)) ? PA[(yr,r,g)] : 1.0) * id0[r,g,s] for g in goods) 
# cost of labor inputs
        + PL[yr,r] * AL[yr,r,s]
# cost of capital inputs 
        + (RK[yr,r,s]/rk0)* AK[yr,r,s]
        - 
# revenue from sectoral supply (take note of r/s/g indices on ys0)                
        sum(PY[yr,r,s]  * ys0[r,s,g] for g in goods) * (1-ty[r,s])
);

# @mapping(cge,profit_y[r in regions,s in sectors, t in years],
# # cost of intermediate demand
#         sum(PA[r,g,t] * blueNOTE[:id0][r,g,s] for g in goods) 
# # cost of labor inputs
#         + PL[r,t] * AL[r,s,t]
# # cost of capital inputs 
#         + (RK[r,s,t] / rk0) * AK[r,s,t]
#         - 
# # revenue from sectoral supply (take note of r/s/g indices on ys0)                
#         sum(PY[r,g,t] * blueNOTE[:ys0][r,s,g] for g in goods) * (1-blueNOTE[:ty][r,s])
# );

@mapping(cge,profit_x[(yr,r,g) in set[:X]],
# output 'cost' from aggregate supply
         PY[yr,r,g] * s0[r,g] 
        - (
# revenues from foreign exchange
        PFX[yr] * AX[yr,r,g]
# revenues from national market                  
        + PN[yr,g] * AN[yr,r,g]
# revenues from domestic market
        + (haskey(PD.lookup[1], (yr,r,g)) ? PD[(yr,r,g)] : 1.0) * AD[yr,r,g]
        )
);

# @mapping(cge,profit_x[r in regions,g in goods, t in years],
# # output 'cost' from aggregate supply
#         PY[r,g,t] * blueNOTE[:s0][r,g] 
#         - (
# # revenues from foreign exchange
#         PFX[t] * AX[r,g,t]
# # revenues from national market                  
#         + PN[g,t] * AN[r,g,t]
# # revenues from domestic market
#         + PD[r,g,t] * AD[r,g,t]
#         )
# );

@mapping(cge,profit_a[(yr,r,g) in set[:A]],
# costs from national market
        PN[yr,g] * DN[yr,r,g] 
# costs from domestic market                  
        + (haskey(PD.lookup[1], (yr,r,g)) ? PD[(yr,r,g)] : 1.0) * DD[yr,r,g] 
# costs from imports, including import tariff
        + PFX[yr] * (1+tm[r,g]) * MD[yr,r,g]
# costs of margin demand                
        + sum(PM[yr,r,m] * md0[r,m,g] for m in margins)
        - ( 
# revenues from regional market based on armington supply               
        (haskey(PA.lookup[1], (yr,r,g)) ? PA[(yr,r,g)] : 1.0) * (1-ta[r,g]) * a0[r,g] 
# revenues from re-exports                   
        + PFX[yr] * rx0[r,g]
        )
);


# @mapping(cge,profit_a[r in regions,g in goods, t in years],
# # costs from national market
#         PN[g,t] * DN[r,g,t] 
# # costs from domestic market                  
#         + PD[r,g,t] * DD[r,g,t] 
# # costs from imports, including import tariff
#         + PFX[t] * (1+blueNOTE[:tm][r,g]) * MD[r,g,t]
# # costs of margin demand                
#         + sum(PM[r,m,t] * blueNOTE[:md0][r,m,g] for m in margins)
#         - ( 
# # revenues from regional market based on armington supply               
#         PA[r,g,t] * (1-blueNOTE[:ta][r,g]) * blueNOTE[:a0][r,g] 
# # revenues from re-exports                   
#         + PFX[t] * blueNOTE[:rx0][r,g]
#         )
# );

@mapping(cge, profit_c[yr in years,r in regions],
# costs of inputs - computed as final demand times regional market prices
        sum((haskey(PA.lookup[1], (yr,r,g)) ? PA[(yr,r,g)] : 1.0) * CD[yr,r,g] for g in goods)
        - 
# revenues/benefit computed as CPI * reference consumption                  
        PC[yr,r] * c0[r]
);


# @mapping(cge,profit_c[r in regions, t in years],
# # costs of inputs - computed as final demand times regional market prices
#         sum(PA[r,g,t] * CD[r,g,t] for g in goods)
#         - 
# # revenues/benefit computed as CPI * reference consumption                  
#         PC[r,t] * blueNOTE[:c0][(r,)]
# );

#Could there be a problem with the filtering of PK and PKT for yr+1?
@mapping(cge,profit_k[yr in years, r in regions, s in sectors],
        PK[yr,r,s]
        - (
            RK[yr,r,s]
            + (1-dr) * (yr!=years_last ? PK[yr+1,r,s] : PKT[r,s])
            # + (1-bool_lastyear[yr])*(1-dr)*PK[yr+1,r,s]
            # + (bool_lastyear[yr])*(1-dr)*PKT[r,s]
#            + (bool_lastyear[yr])*(1-dr)*(haskey(PKT.lookup[1], (r,s)) ? PKT[(r,s)] : 1.0)
#+ (1-delta) * (yr!=years_last ? (haskey(PK.lookup[1], (yr+1,r,s)) ? PK[(yr+1,r,s)] : 1.0) : (haskey(PKT.lookup[1], (r,s)) ? PKT[(r,s)] : 1.0))
        )
);

#!!! might need to switch signs here...
# @mapping(cge,profit_k[r in regions, s in sectors, t in years],
#         PK[r,s,t] 
#         - (
#         RK[r,s,t]
#         + (1-delta) * (t!=years_last ? PK[r,s,t+1] : PKT[r,s])
#         )
# );

@mapping(cge,profit_i[yr in years, r in regions, s in sectors],
        PY[yr,r,s]
        - (
            (yr!=years_last ? PK[yr+1,r,s] : PKT[r,s])
            # (1-bool_lastyear[yr])*PK[yr+1,r,s]
            # + (bool_lastyear[yr])*PKT[r,s]
#            + (bool_lastyear[yr])*(haskey(PKT.lookup[1], (r,s)) ? PKT[(r,s)] : 1.0)
        )
#        (t!=years_last ? PK[r,s,t+1] : PKT[r,s])
);


# @mapping(cge,profit_i[r in regions, s in sectors, t in years],
#         PY[r,s,t] 
#         - 
#         (t!=years_last ? PK[r,s,t+1] : PKT[r,s])
# );

@mapping(cge,profit_ms[yr in years,r in regions,m in margins],
# provision of margins to national market
        sum(PN[yr,gm]   * nm0[r,gm,m] for gm in goods_margins)
# provision of margins to domestic market    
        + sum((haskey(PD.lookup[1], (yr,r,gm)) ? PD[(yr,r,gm)] : 1.0) * dm0[r,gm,m] for gm in goods_margins)
        - 
# total margin demand    
        PM[yr,r,m] * sum(md0[r,m,gm] for gm in goods_margins)
);


# @mapping(cge,profit_ms[r in regions, m in margins, t in years],
# # provision of margins to national market
#         sum(PN[gm,t]   * blueNOTE[:nm0][r,gm,m] for gm in goods_margins)
# # provision of margins to domestic market    
#         + sum(PD[r,gm,t] * blueNOTE[:dm0][r,gm,m] for gm in goods_margins)
#         - 
# # total margin demand    
#         PM[r,m,t] * sum(blueNOTE[:md0][r,m,gm] for gm in goods_margins)
# );


###################################
# -- Market Clearing Conditions -- 
###################################

@mapping(cge,market_pa[(yr,r,g) in set[:PA]],
# absorption or supply
        (haskey(A.lookup[1], (yr,r,g)) ? A[(yr,r,g)] : 1.0) * a0[r,g] 
        - ( 
# government demand (exogenous)       
        g0[r,g] 
# demand for investment (exogenous)
        + i0[r,g]
# final demand        
        + C[yr,r] * CD[yr,r,g]
# intermediate demand        
        + sum(Y[yr,r,s] * id0[r,g,s] for s in sectors if (sum(sld[:ys0][r,s,g] for g in goods) != 0))
        )
);



# @mapping(cge,market_pa[r in regions, g in goods, t in years],
# # absorption or supply
#         A[r,g,t] * blueNOTE[:a0][r,g] 
#         - ( 
# # government demand (exogenous)       
#         blueNOTE[:g0][r,g] 
# # demand for investment (exogenous)
#         + blueNOTE[:i0][r,g]
# # final demand        
#         + C[r,t] * CD[r,g,t]
# # intermediate demand        
#         + sum(Y[r,s,t] * blueNOTE[:id0][r,g,s] for s in sectors if (y_check[r,s] > 0))
#         )
# );

@mapping(cge,market_py[yr in years, r in regions, g in goods],
# sectoral supply
        sum(Y[yr,r,s]*ys0[r,s,g] for s in sectors)
# household production (exogenous)        
        + yh0[r,g]
        - 
# aggregate supply (akin to market demand)                
       (haskey(X.lookup[1], (yr,r,g)) ? X[(yr,r,g)] : 1.0) * s0[r,g]
);


# @mapping(cge,market_py[r in regions, g in goods, t in years],
# # sectoral supply
#         sum(Y[r,s,t] * blueNOTE[:ys0][r,s,g] for s in sectors)
# # household production (exogenous)        
#         + blueNOTE[:yh0][r,g]
#         - 
# # aggregate supply (akin to market demand)                
#         X[r,g,t] * blueNOTE[:s0][r,g]
# );

@mapping(cge,market_pd[(yr,r,g) in set[:PD]],
# aggregate supply
        (haskey(X.lookup[1], (yr,r,g)) ? X[(yr,r,g)] : 1.0)  * AD[yr,r,g] 
        - ( 
# demand for local market          
        (haskey(A.lookup[1], (yr,r,g)) ? A[(yr,r,g)] : 1.0) * DD[yr,r,g]
# margin supply from local market
        + sum(MS[yr,r,m] * dm0[r,g,m] for m in margins if (g in goods_margins ) )  
        )
);


# @mapping(cge,market_pd[r in regions, g in goods, t in years],
# # aggregate supply
#         X[r,g,t] * AD[r,g,t] 
#         - ( 
# # demand for local market          
#         A[r,g,t] * DD[r,g,t]
# # margin supply from local market
#         + sum(MS[r,m,t] * blueNOTE[:dm0][r,g,m] for m in margins if (g in goods_margins ) )  
#         )
# );

@mapping(cge,market_pn[yr in years,g in goods],
# supply to the national market
        sum((haskey(X.lookup[1], (yr,r,g)) ? X[(yr,r,g)] : 1.0)  * AN[yr,r,g] for r in regions)
        - ( 
# demand from the national market 
        sum((haskey(A.lookup[1], (yr,r,g)) ? A[(yr,r,g)] : 1.0) * DN[yr,r,g] for r in regions)
# market supply to the national market        
        + sum(MS[yr,r,m] * nm0[r,g,m] for r in regions for m in margins if (g in goods_margins) )
        )
);


# @mapping(cge,market_pn[g in goods, t in years],
# # supply to the national market
#         sum(X[r,g,t] * AN[r,g,t] for r in regions)
#         - ( 
# # demand from the national market 
#         sum(A[r,g,t] * DN[r,g,t] for r in regions)
# # market supply to the national market        
#         + sum(MS[r,m,t] * blueNOTE[:nm0][r,g,m] for r in regions for m in margins if (g in goods_margins) )
#         )
# );

@mapping(cge,market_pl[yr in years,r in regions],
# supply of labor
        sum(ld0[r,s] for s in sectors)
        - 
# demand for labor in all sectors        
        sum(Y[yr,r,s]* AL[yr,r,s] for s in sectors)
);


# @mapping(cge,market_pl[r in regions, t in years],
# # supply of labor
#         sum(blueNOTE[:ld0][r,s] for s in sectors)
#         - 
# # demand for labor in all sectors        
#         sum(Y[r,s,t] * AL[r,s,t] for s in sectors)
# );

#Again, could there be issues filtering I and K for yr-1?
@mapping(cge,market_pk[yr in years, r in regions, s in sectors],
# if first year, initial capital
# else investment plus previous year's decayed capital
         (
             (yr==bmkyr ? kd0[r,s] : I[yr-1,r,s])
            #  (bool_firstyear[yr])*kd0[r,s]
            #  +(1-bool_firstyear[yr])*I[yr-1,r,s]
#             +(1-bool_firstyear[yr])*(haskey(I.lookup[1], (yr-1,r,s)) ? I[(yr-1,r,s)] : 0.0)
         )
         + (1-dr) * (yr>bmkyr ? K[yr-1,r,s] : 0)
#         +(1-dr) * (1-bool_firstyear[yr]) * K[yr-1,r,s]
         - 
#current year's capital capital        
         K[yr,r,s]
);


# @mapping(cge,market_pk[r in regions, s in sectors, t in years],
# # if first year, initial capital
# # else investment plus previous year's decayed capital
#         (t==mod_year ? blueNOTE[:kd0][r,s] : I[r,s,t-1])
#         + (1-delta) * (t>mod_year ? K[r,s,t-1] : 0)
#         - 
# #current year's capital capital        
#         K[r,s,t]
# );

@mapping(cge,market_rk[yr in years, r in regions, s in sectors],
        K[yr,r,s]
        -
        Y[yr,r,s]* AK[yr,r,s]
);

# @mapping(cge,market_rk[r in regions, s in sectors, t in years],
#         K[r,s,t]
#         -
#         Y[r,s,t] * blueNOTE[:kd0][r,s] * CVA[r,s,t] / (RK[r,s,t] / rk0)
# );

# Maybe try without equation filtering as a test for these? 
#- maybe drop filter on PKT and TK, as well as PK, I and K?
#terminal investment constraint
#@mapping(cge,market_pkt[(r,s) in set[:PKT]],
@mapping(cge,market_pkt[r in regions, s in sectors],
        (1-dr)*K[years_last,r,s]
        + I[years_last,r,s]
#        + (haskey(I.lookup[1], (years_last,r,s)) ? I[(years_last,r,s)] : 0.0)
        - 
        TK[r,s]
#        (haskey(TK.lookup[1], (r,s)) ? TK[(r,s)] : 0.0)
);

#@mapping(cge,termk[(r,s) in set[:PKT]],
@mapping(cge,termk[r in regions, s in sectors],
         I[years_last,r,s]
         / (I[years_last-1,r,s] + (sld[:kd0][r,s]==0 && + 1e-6))
        - 
         Y[years_last,r,s]
         / Y[years_last-1,r,s]
);


# #terminal investment constraint
# @mapping(cge,market_pkt[r in regions, s in sectors],
#         (1-delta) * K[r,s,years_last] 
#         + I[r,s,years_last] 
#         - 
#         TK[r,s]
# );

# @mapping(cge,termk[r in regions, s in sectors],
#         I[r,s,years_last] / (I[r,s,years_last-1] + (blueNOTE[:kd0][r,s]==0 && + 1e-6))
#         - 
#         Y[r,s,years_last] / Y[r,s,years_last-1]
# );

@mapping(cge,market_pm[yr in years,r in regions, m in margins],
# margin supply 
        MS[yr,r,m] * sum(md0[r,m,gm] for gm in goods_margins)
        - 
# margin demand        
        sum((haskey(A.lookup[1], (yr,r,g)) ? A[(yr,r,g)] : 1.0) * md0[r,m,g] for g in goods)
);


# @mapping(cge,market_pm[r in regions, m in margins, t in years],
# # margin supply 
#         MS[r,m,t] * sum(blueNOTE[:md0][r,m,gm] for gm in goods_margins)
#         - 
# # margin demand        
#         sum(A[r,g,t] * blueNOTE[:md0][r,m,g] for g in goods)
# );

@mapping(cge,market_pfx[yr in years],
# balance of payments (exogenous)
        sum(bopdef0[r] for r in regions)
# supply of exports     
        + sum((haskey(X.lookup[1], (yr,r,g)) ? X[(yr,r,g)] : 1.0)  * AX[yr,r,g] for r in regions for g in goods)
# supply of re-exports        
        + sum((haskey(A.lookup[1], (yr,r,g)) ? A[(yr,r,g)] : 1.0) * rx0[r,g] for r in regions for g in goods if (yr,r,g) in set[:A])
        - 
# import demand                
        sum((haskey(A.lookup[1], (yr,r,g)) ? A[(yr,r,g)] : 1.0) * MD[yr,r,g] for r in regions for g in goods if (yr,r,g) in set[:A])
);

# @mapping(cge,market_pfx[t in years],
# # balance of payments (exogenous)
#         sum(blueNOTE[:bopdef0][(r,)] for r in regions)
# # supply of exports     
#         + sum(X[r,g,t] * AX[r,g,t] for r in regions for g in goods)
# # supply of re-exports        
#         + sum(A[r,g,t] * blueNOTE[:rx0][r,g] for r in regions for g in goods if (a_set[r,g] != 0))
#         - 
# # import demand                
#         sum(A[r,g,t] * MD[r,g,t] for r in regions for g in goods if (a_set[r,g] != 0))
# );

@mapping(cge,market_pc[yr in years,r in regions],
# a period's final demand
        C[yr,r] * c0[r]
        - 
# consumption / utiltiy        
        RA[yr,r] / PC[yr,r]
);

#######
# @mapping(cge,market_pc[r in regions, t in years],
# # a period's final demand
#         C[r,t] * blueNOTE[:c0][(r,)]
#         - 
# # consumption / utiltiy        
#         RA[r,t] / PC[r,t]
# );


@mapping(cge,income_ra[yr in years,r in regions],
# consumption/utility
        RA[yr,r] 
        - 
        (
# labor income        
        PL[yr,r] * sum(ld0[r,s] for s in sectors)
# provision of household supply          
        + sum( PY[yr,r,g] * yh0[r,g] for g in goods)
# revenue or costs of foreign exchange including household adjustment   
        + PFX[yr] * (bopdef0[r] + hhadj[r])
# government and investment provision        
        - sum((haskey(PA.lookup[1], (yr,r,g)) ? PA[(yr,r,g)] : 1.0) * (g0[r,g] + i0[r,g]) for g in goods)
# import taxes - assumes lumpsum recycling
        + sum((haskey(A.lookup[1], (yr,r,g)) ? A[(yr,r,g)] : 1.0) * MD[yr,r,g] * PFX[yr] * tm[r,g] for g in goods if ((sld[:a0][r,g] + sld[:rx0][r,g])!=0))
# taxes on intermediate demand - assumes lumpsum recycling
        + sum((haskey(A.lookup[1], (yr,r,g)) ? A[(yr,r,g)] : 1.0) * a0[r,g]*(haskey(PA.lookup[1], (yr,r,g)) ? PA[(yr,r,g)] : 1.0)*ta[r,g] for g in goods if ((sld[:a0][r,g] + sld[:rx0][r,g])!=0))
# production taxes - assumes lumpsum recycling  
        + sum( pvm[yr]*Y[yr,r,s] * ys0[r,s,g] * ty[r,s] for s in sectors, g in goods)
# capital income        
        + (1-bool_lastyear[yr]) * sum(PK[yr,r,s]* K[yr,r,s] for s in sectors) / (1+ir)
        + (bool_lastyear[yr]) * sum(PKT[r,s] * TK[r,s] for s in sectors)
#        + (bool_lastyear[yr]) * sum((haskey(PKT.lookup[1], (r,s)) ? PKT[(r,s)] : 1.0) * (haskey(TK.lookup[1], (r,s)) ? TK[(r,s)] : 0.0) for s in sectors)
        )
);


# #@mapping(cge,income_ra[r in regions],
# @mapping(cge,income_ra[r in regions, t in years],
# # consumption/utility
#         RA[r,t] 
#         - 
#         (
# # labor income        
#         PL[r,t] * sum(blueNOTE[:ld0][r,s] for s in sectors)
# # provision of household supply          
#         + sum(PY[r,g,t]*blueNOTE[:yh0][r,g] for g in goods)
# # revenue or costs of foreign exchange including household adjustment   
#         + PFX[t] * (blueNOTE[:bopdef0][(r,)] + blueNOTE[:hhadj][(r,)])
# # government and investment provision        
#         - sum(PA[r,g,t] * (blueNOTE[:g0][r,g] + blueNOTE[:i0][r,g]) for g in goods)
# # import taxes - assumes lumpsum recycling
#         + sum(A[r,g,t] * MD[r,g,t]* PFX[t] * blueNOTE[:tm][r,g] for g in goods if (a_set[r,g] != 0))
# # taxes on intermediate demand - assumes lumpsum recycling
#         + sum(A[r,g,t] * blueNOTE[:a0][r,g]*PA[r,g,t]*blueNOTE[:ta][r,g] for g in goods if (a_set[r,g] != 0) )
# # production taxes - assumes lumpsum recycling  
#         + sum(pvm[t] * Y[r,s,t] * blueNOTE[:ys0][r,s,g] * blueNOTE[:ty][r,s] for s in sectors for g in goods)
# # income from capital
#         + (1-bool_lastyear[t]) * sum(PK[r,s,t] * K[r,s,t] for s in sectors) / (1+i)
# #cost of terminal year investment
#         + bool_lastyear[t] * sum(PKT[r,s] * TK[r,s] for s in sectors)
#         )
# );


####################################
# -- Complementarity Conditions --
####################################

# equations with conditions cannot be paired 
# see workaround here: https://github.com/chkwon/Complementarity.jl/issues/37
# [fix(PK[r,s,t],1;force=true) for r in regions for s in sectors for t in years if !(blueNOTE[:kd0][r,s] > 0)]
# [fix(RK[r,s,t],1;force=true) for r in regions for s in sectors for t in years if !(blueNOTE[:kd0][r,s] > 0)]
# [fix(PY[r,g,t],1,force=true) for r in regions for g in goods for t in years if !(y_check[r,g]>0)]
# [fix(PA[r,g,t],1,force=true) for r in regions for g in goods for t in years if !(blueNOTE[:a0][r,g]>0)]
# [fix(PD[r,g,t],1,force=true) for r in regions for g in goods for t in years if (blueNOTE[:xd0][r,g] == 0)]
# [fix(Y[r,s,t],1,force=true) for r in regions for s in sectors for t in years if !(y_check[r,s] > 0)]
# [fix(X[r,g,t],1,force=true) for r in regions for g in goods for t in years if !(blueNOTE[:s0][r,g] > 0)]
# [fix(A[r,g,t],1,force=true) for r in regions for g in goods for t in years if (a_set[r,g] == 0)]
# [fix(K[r,s,t],0;force=true) for r in regions for s in sectors for t in years if !(blueNOTE[:kd0][r,s] > 0)]
[fix(I[yr,r,s],1e-5;force=true) for yr in years for r in regions for s in sectors if !(sld[:kd0][r,s] > 0)]
[fix(K[yr,r,s],0;force=true) for yr in years for r in regions for s in sectors if !(sld[:kd0][r,s] > 0)]
[fix(PK[yr,r,s],1;force=true) for yr in years for r in regions for s in sectors if !(sld[:kd0][r,s] > 0)]
[fix(RK[yr,r,s],1;force=true) for yr in years for r in regions for s in sectors if !(sld[:kd0][r,s] > 0)]
[fix(Y[yr,r,s],1;force=true) for yr in years for r in regions for s in sectors if !(sum(sld[:ys0][r,s,g] for g in goods) > 0)]
[fix(PY[yr,r,s],1;force=true) for yr in years for r in regions for s in sectors if !(sum(sld[:ys0][r,s,g] for g in goods) > 0)]


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
#PATHSolver.options(convergence_tolerance=1e-8, output=:yes, time_limit=3600)
#PATHSolver.options(convergence_tolerance=1e-8, output=:yes, time_limit=0)
PATHSolver.options(convergence_tolerance=1e-6, output=:yes, time_limit=3600, cumulative_iteration_limit=0)

# export the path license string to the environment
# this is now done in the SLiDE initiation steps 
ENV["PATH_LICENSE_STRING"]="2617827524&Courtesy&&&USR&64785&11_12_2017&1000&PATH&GEN&31_12_2020&0_0_0&5000&0_0"

# solve the model
status = solveMCP(cge)
