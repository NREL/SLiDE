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

# -- Temporal setup --

# mod_year is the first year modeled,
# the year read from the blueNOTE dataset,
# and thus the benchmark year
mod_year = 2016

# last year modeled
end_year = 2018

# index used in the model is the set of years modeled here
years = mod_year:end_year

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

        if t!=mod_year
                push!(bool_firstyear,t=>0)
        else
                push!(bool_firstyear,t=>1)
        end
end


# -- Major Assumptions -- 
rho = 0.04    # discount factor   
i = 0.05      # interest rate         
g = 0.0      # growth rate
delta  = 0.02 # capital depreciation factor

# present value multiplier
pvm = Dict()

# share of consumption in current period to value over time 
alpha = Dict()
for t in years
        push!(pvm,t=>(1/(1+i))^(t-mod_year))
        push!(alpha,t=>((1 + g) / (1 + i) ) ^(t-mod_year) )
end

t_alpha = sum(alpha[tt] for tt in years)

for k in keys(alpha)
        alpha[k] = alpha[k] / t_alpha
end

#steady state rental rate of capital is interest plus depreciation
rk0 = i + delta


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
        return (d, set, idx)
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

bmkyr = 2016
(sld, set, idx) = _model_input(years, d, set)



###############
# -- SETS --
###############

#Read sets from SLiDE build dictionary
regions = set[:r]
sectors = set[:s]
goods = set[:g]
margins = set[:m]
goods_margins = set[:gm]


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


##################
# -- VARIABLES -- 
##################

# small value that acts as a lower limit to variable values
# default is zero
sv = 0.00

@variable(cge, Y[(r,s) in set[:Y], t in years] >= sv, start = 1);

#sectors
@variable(cge,Y[r in regions, s in sectors, t in years]>=sv,start=1)
@variable(cge,X[r in regions, g in goods, t in years]>=sv,start=1)
@variable(cge,A[r in regions, g in goods, t in years]>=sv,start=1)
@variable(cge,C[r in regions, t in years]>=sv,start=1)
@variable(cge,MS[r in regions, m in margins, t in years]>=sv,start=1)
@variable(cge,K[r in regions, s in sectors, t in years]>=sv,start=blueNOTE[:kd0][r,s])
@variable(cge,I[r in regions, s in sectors, t in years]>=sv,start=(delta * blueNOTE[:kd0][r,s]))

#commodities:
@variable(cge,PA[r in regions, g in goods, t in years]>=sv,start=pvm[t]) # Regional market (input)
@variable(cge,PY[r in regions, g in goods, t in years]>=sv,start=pvm[t]) # Regional market (output)
@variable(cge,PD[r in regions, g in goods, t in years]>=sv,start=pvm[t]) # Local market price
@variable(cge,PN[g in goods, t in years]>=sv,start=pvm[t]) # National market
@variable(cge,PL[r in regions, t in years]>=sv,start=pvm[t]) # Wage rate
@variable(cge,PK[r in regions, s in sectors, t in years]>=sv,start=pvm[t] * (1+i)) # Rental rate of capital ###
@variable(cge,RK[r in regions, s in sectors, t in years]>=sv,start=pvm[t] * rk0) # Capital return rate ###
@variable(cge,TK[r in regions, s in sectors]>=sv,start=blueNOTE[:kd0][r,s]) ### Terminal capital amount
@variable(cge,PKT[r in regions, s in sectors]>=sv,start=pvm[years_last]) # Terminal capital cost
@variable(cge,PM[r in regions, m in margins, t in years]>=sv,start=pvm[t]) # Margin price
@variable(cge,PC[r in regions, t in years]>=sv,start=pvm[t]) # Consumer price index #####
@variable(cge,PFX[t in years]>=sv,start=pvm[t]) # Foreign exchange

#consumer:
#@variable(cge,RA[r in regions,t in years]>=sv,start=pvm[t] * blueNOTE[:c0][(r,)]) # Representative agent
@variable(cge,RA[r in regions, t in years]>=sv,start = pvm[t] * blueNOTE[:c0][(r,)]) # Representative agent


###############################
# -- PLACEHOLDER VARIABLES --
###############################

#cobb-douglas function for value added (VA) ######
@NLexpression(cge,CVA[r in regions,s in sectors,t in years],
  PL[r,t]^alpha_kl[r,s] * (RK[r,s,t] / rk0) ^ (1-alpha_kl[r,s]) );

#demand for labor in VA
@NLexpression(cge,AL[r in regions, s in sectors, t in years],
  blueNOTE[:ld0][r,s] * CVA[r,s,t] / PL[r,t] );

#demand for capital in VA ######
@NLexpression(cge,AK[r in regions,s in sectors, t in years],
  blueNOTE[:kd0][r,s] * CVA[r,s,t] / (RK[r,s,t] / rk0) );

###

#CES function for output demand - including
# exports (absent of re-exports) times the price for foreign exchange, 
# region's supply to national market times the national market price
# regional supply to local market times domestic price
@NLexpression(cge,RX[r in regions,g in goods, t in years],
  (alpha_x[r,g]*PFX[t]^5+alpha_n[r,g]*PN[g,t]^5+alpha_d[r,g]*PD[r,g,t]^5)^(1/5) );

#demand for exports via demand function
@NLexpression(cge,AX[r in regions,g in goods, t in years],
  (blueNOTE[:x0][r,g] - blueNOTE[:rx0][r,g])*(PFX[t]/RX[r,g,t])^4 );

#demand for contribution to national market 
@NLexpression(cge,AN[r in regions,g in goods, t in years],
  blueNOTE[:xn0][r,g]*(PN[g,t]/(RX[r,g,t]))^4 );

#demand for regionals supply to local market
@NLexpression(cge,AD[r in regions,g in goods, t in years],
  blueNOTE[:xd0][r,g] * (PD[r,g,t] / (RX[r,g,t]))^4 );

  ###

# CES function for tradeoff between national and domestic market
@NLexpression(cge,CDN[r in regions,g in goods, t in years],
  (theta_n[r,g]*PN[g,t]^(1-2)+(1-theta_n[r,g])*PD[r,g,t]^(1-2))^(1/(1-2)) );

# CES function for tradeoff between domestic consumption and foreign exports
# recall tm in the import tariff thus tm / tm0 is the relative change in import tariff rates
@NLexpression(cge,CDM[r in regions,g in goods, t in years],
  ((1-theta_m[r,g])*CDN[r,g,t]^(1-4)+theta_m[r,g]*
  (PFX[t]*(1+blueNOTE[:tm][r,g])/(1+blueNOTE[:tm0][r,g]))^(1-4))^(1/(1-4)) 
  );

  ###

# regions demand from the national market <- note nesting of CDN in CDM
@NLexpression(cge,DN[r in regions,g in goods, t in years],
  blueNOTE[:nd0][r,g]*(CDN[r,g,t]/PN[g,t])^2*(CDM[r,g,t]/CDN[r,g,t])^4 );

# region demand from local market <- note nesting of CDN in CDM
@NLexpression(cge,DD[r in regions,g in goods, t in years],
  blueNOTE[:dd0][r,g]*(CDN[r,g,t]/PD[r,g,t])^2*(CDM[r,g,t]/CDN[r,g,t])^4 );

# import demand
@NLexpression(cge,MD[r in regions,g in goods, t in years],
  blueNOTE[:m0][r,g]*(CDM[r,g,t]*(1+blueNOTE[:tm][r,g])/(PFX[t]*(1+blueNOTE[:tm0][r,g])))^4 );

# final demand
@NLexpression(cge,CD[r in regions,g in goods, t in years],
  blueNOTE[:cd0][r,g]*PC[r,t] / PA[r,g,t] );


###############################
# -- Zero Profit Conditions --
###############################

@mapping(cge,profit_y[r in regions,s in sectors, t in years],
# cost of intermediate demand
        sum(PA[r,g,t] * blueNOTE[:id0][r,g,s] for g in goods) 
# cost of labor inputs
        + PL[r,t] * AL[r,s,t]
# cost of capital inputs 
        + (RK[r,s,t] / rk0) * AK[r,s,t]
        - 
# revenue from sectoral supply (take note of r/s/g indices on ys0)                
        sum(PY[r,g,t] * blueNOTE[:ys0][r,s,g] for g in goods) * (1-blueNOTE[:ty][r,s])
);

@mapping(cge,profit_x[r in regions,g in goods, t in years],
# output 'cost' from aggregate supply
        PY[r,g,t] * blueNOTE[:s0][r,g] 
        - (
# revenues from foreign exchange
        PFX[t] * AX[r,g,t]
# revenues from national market                  
        + PN[g,t] * AN[r,g,t]
# revenues from domestic market
        + PD[r,g,t] * AD[r,g,t]
        )
);


@mapping(cge,profit_a[r in regions,g in goods, t in years],
# costs from national market
        PN[g,t] * DN[r,g,t] 
# costs from domestic market                  
        + PD[r,g,t] * DD[r,g,t] 
# costs from imports, including import tariff
        + PFX[t] * (1+blueNOTE[:tm][r,g]) * MD[r,g,t]
# costs of margin demand                
        + sum(PM[r,m,t] * blueNOTE[:md0][r,m,g] for m in margins)
        - ( 
# revenues from regional market based on armington supply               
        PA[r,g,t] * (1-blueNOTE[:ta][r,g]) * blueNOTE[:a0][r,g] 
# revenues from re-exports                   
        + PFX[t] * blueNOTE[:rx0][r,g]
        )
);

@mapping(cge,profit_c[r in regions, t in years],
# costs of inputs - computed as final demand times regional market prices
        sum(PA[r,g,t] * CD[r,g,t] for g in goods)
        - 
# revenues/benefit computed as CPI * reference consumption                  
        PC[r,t] * blueNOTE[:c0][(r,)]
);

#!!! might need to switch signs here...
@mapping(cge,profit_k[r in regions, s in sectors, t in years],
        PK[r,s,t] 
        - (
        RK[r,s,t]
        + (1-delta) * (t!=years_last ? PK[r,s,t+1] : PKT[r,s])
        )
);

@mapping(cge,profit_i[r in regions, s in sectors, t in years],
        PY[r,s,t] 
        - 
        (t!=years_last ? PK[r,s,t+1] : PKT[r,s])
);

@mapping(cge,profit_ms[r in regions, m in margins, t in years],
# provision of margins to national market
        sum(PN[gm,t]   * blueNOTE[:nm0][r,gm,m] for gm in goods_margins)
# provision of margins to domestic market    
        + sum(PD[r,gm,t] * blueNOTE[:dm0][r,gm,m] for gm in goods_margins)
        - 
# total margin demand    
        PM[r,m,t] * sum(blueNOTE[:md0][r,m,gm] for gm in goods_margins)
);


###################################
# -- Market Clearing Conditions -- 
###################################

@mapping(cge,market_pa[r in regions, g in goods, t in years],
# absorption or supply
        A[r,g,t] * blueNOTE[:a0][r,g] 
        - ( 
# government demand (exogenous)       
        blueNOTE[:g0][r,g] 
# demand for investment (exogenous)
        + blueNOTE[:i0][r,g]
# final demand        
        + C[r,t] * CD[r,g,t]
# intermediate demand        
        + sum(Y[r,s,t] * blueNOTE[:id0][r,g,s] for s in sectors if (y_check[r,s] > 0))
        )
);

@mapping(cge,market_py[r in regions, g in goods, t in years],
# sectoral supply
        sum(Y[r,s,t] * blueNOTE[:ys0][r,s,g] for s in sectors)
# household production (exogenous)        
        + blueNOTE[:yh0][r,g]
        - 
# aggregate supply (akin to market demand)                
        X[r,g,t] * blueNOTE[:s0][r,g]
);


@mapping(cge,market_pd[r in regions, g in goods, t in years],
# aggregate supply
        X[r,g,t] * AD[r,g,t] 
        - ( 
# demand for local market          
        A[r,g,t] * DD[r,g,t]
# margin supply from local market
        + sum(MS[r,m,t] * blueNOTE[:dm0][r,g,m] for m in margins if (g in goods_margins ) )  
        )
);

@mapping(cge,market_pn[g in goods, t in years],
# supply to the national market
        sum(X[r,g,t] * AN[r,g,t] for r in regions)
        - ( 
# demand from the national market 
        sum(A[r,g,t] * DN[r,g,t] for r in regions)
# market supply to the national market        
        + sum(MS[r,m,t] * blueNOTE[:nm0][r,g,m] for r in regions for m in margins if (g in goods_margins) )
        )
);

@mapping(cge,market_pl[r in regions, t in years],
# supply of labor
        sum(blueNOTE[:ld0][r,s] for s in sectors)
        - 
# demand for labor in all sectors        
        sum(Y[r,s,t] * AL[r,s,t] for s in sectors)
);

@mapping(cge,market_pk[r in regions, s in sectors, t in years],
# if first year, initial capital
# else investment plus previous year's decayed capital
        (t==mod_year ? blueNOTE[:kd0][r,s] : I[r,s,t-1])
        + (1-delta) * (t>mod_year ? K[r,s,t-1] : 0)
        - 
#current year's capital capital        
        K[r,s,t]
);

@mapping(cge,market_rk[r in regions, s in sectors, t in years],
        K[r,s,t]
        -
        Y[r,s,t] * blueNOTE[:kd0][r,s] * CVA[r,s,t] / (RK[r,s,t] / rk0)
);

#terminal investment constraint
@mapping(cge,market_pkt[r in regions, s in sectors],
        (1-delta) * K[r,s,years_last] 
        + I[r,s,years_last] 
        - 
        TK[r,s]
);

@mapping(cge,termk[r in regions, s in sectors],
        I[r,s,years_last] / (I[r,s,years_last-1] + (blueNOTE[:kd0][r,s]==0 && + 1e-6))
        - 
        Y[r,s,years_last] / Y[r,s,years_last-1]
);

@mapping(cge,market_pm[r in regions, m in margins, t in years],
# margin supply 
        MS[r,m,t] * sum(blueNOTE[:md0][r,m,gm] for gm in goods_margins)
        - 
# margin demand        
        sum(A[r,g,t] * blueNOTE[:md0][r,m,g] for g in goods)
);

@mapping(cge,market_pfx[t in years],
# balance of payments (exogenous)
        sum(blueNOTE[:bopdef0][(r,)] for r in regions)
# supply of exports     
        + sum(X[r,g,t] * AX[r,g,t] for r in regions for g in goods)
# supply of re-exports        
        + sum(A[r,g,t] * blueNOTE[:rx0][r,g] for r in regions for g in goods if (a_set[r,g] != 0))
        - 
# import demand                
        sum(A[r,g,t] * MD[r,g,t] for r in regions for g in goods if (a_set[r,g] != 0))
);

#######
@mapping(cge,market_pc[r in regions, t in years],
# a period's final demand
        C[r,t] * blueNOTE[:c0][(r,)]
        - 
# consumption / utiltiy        
        RA[r,t] / PC[r,t]
);

#@mapping(cge,income_ra[r in regions],
@mapping(cge,income_ra[r in regions, t in years],
# consumption/utility
        RA[r,t] 
        - 
        (
# labor income        
        PL[r,t] * sum(blueNOTE[:ld0][r,s] for s in sectors)
# provision of household supply          
        + sum(PY[r,g,t]*blueNOTE[:yh0][r,g] for g in goods)
# revenue or costs of foreign exchange including household adjustment   
        + PFX[t] * (blueNOTE[:bopdef0][(r,)] + blueNOTE[:hhadj][(r,)])
# government and investment provision        
        - sum(PA[r,g,t] * (blueNOTE[:g0][r,g] + blueNOTE[:i0][r,g]) for g in goods)
# import taxes - assumes lumpsum recycling
        + sum(A[r,g,t] * MD[r,g,t]* PFX[t] * blueNOTE[:tm][r,g] for g in goods if (a_set[r,g] != 0))
# taxes on intermediate demand - assumes lumpsum recycling
        + sum(A[r,g,t] * blueNOTE[:a0][r,g]*PA[r,g,t]*blueNOTE[:ta][r,g] for g in goods if (a_set[r,g] != 0) )
# production taxes - assumes lumpsum recycling  
        + sum(pvm[t] * Y[r,s,t] * blueNOTE[:ys0][r,s,g] * blueNOTE[:ty][r,s] for s in sectors for g in goods)
# income from capital
        + (1-bool_lastyear[t]) * sum(PK[r,s,t] * K[r,s,t] for s in sectors) / (1+i)
#cost of terminal year investment
        + bool_lastyear[t] * sum(PKT[r,s] * TK[r,s] for s in sectors)
        )
);


####################################
# -- Complementarity Conditions --
####################################

# equations with conditions cannot be paired 
# see workaround here: https://github.com/chkwon/Complementarity.jl/issues/37
[fix(PK[r,s,t],1;force=true) for r in regions for s in sectors for t in years if !(blueNOTE[:kd0][r,s] > 0)]
[fix(RK[r,s,t],1;force=true) for r in regions for s in sectors for t in years if !(blueNOTE[:kd0][r,s] > 0)]
[fix(PY[r,g,t],1,force=true) for r in regions for g in goods for t in years if !(y_check[r,g]>0)]
[fix(PA[r,g,t],1,force=true) for r in regions for g in goods for t in years if !(blueNOTE[:a0][r,g]>0)]
[fix(PD[r,g,t],1,force=true) for r in regions for g in goods for t in years if (blueNOTE[:xd0][r,g] == 0)]
[fix(Y[r,s,t],1,force=true) for r in regions for s in sectors for t in years if !(y_check[r,s] > 0)]
[fix(X[r,g,t],1,force=true) for r in regions for g in goods for t in years if !(blueNOTE[:s0][r,g] > 0)]
[fix(A[r,g,t],1,force=true) for r in regions for g in goods for t in years if (a_set[r,g] == 0)]
[fix(K[r,s,t],0;force=true) for r in regions for s in sectors for t in years if !(blueNOTE[:kd0][r,s] > 0)]
[fix(I[r,s,t],1e-5;force=true) for r in regions for s in sectors for t in years if !(blueNOTE[:kd0][r,s] > 0)]

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
PATHSolver.options(convergence_tolerance=1e-8, output=:yes, time_limit=0)

# export the path license string to the environment
# this is now done in the SLiDE initiation steps 
ENV["PATH_LICENSE_STRING"]="2617827524&Courtesy&&&USR&64785&11_12_2017&1000&PATH&GEN&31_12_2020&0_0_0&5000&0_0"

# solve the model
status = solveMCP(cge)