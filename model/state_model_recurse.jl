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
#endyr = 2018

#Define range of years in time horizon
#years = bmkyr:endyr

#Load slide data and time horizon to produce model data and appropriate time-indexed subsets
(sld, set, idx) = _model_input(bmkyr, d, set)

#last year is the maximum of all years
# years_last = maximum(years)

#Create boolean indicators of first and last year of time horizon
# bool_firstyear = Dict()
# bool_lastyear = Dict()
# for t in years
#         if t!=years_last
#                 push!(bool_lastyear,t=>0)
#         else
#                 push!(bool_lastyear,t=>1)
#         end

#         if t!=bmkyr
#                 push!(bool_firstyear,t=>0)
#         else
#                 push!(bool_firstyear,t=>1)
#         end
# end

###############
# -- SETS --
###############

regions = set[:r]
sectors = set[:s]
goods = set[:g]
margins = set[:m]
goods_margins = set[:gm]

#following subsets are used to limit the size of the model
# the a_set restricits the A variables indices to those
# with positive armington supply or re-exports
a_set = Dict()
[a_set[r,g] = sld[:a0][r,g] + sld[:rx0][r,g] for r in regions for g in goods]

# y_check is used to make sure the r/s combination 
# has a reference amount of sectoral supply
y_check = Dict()
[y_check[r,s] = sum(sld[:ys0][r,s,g] for g in goods) for r in regions for s in sectors]


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


# -- Major Assumptions -- 
# Temporal/Dynamic modifications
# @NLparameter(cge, ir == 0.05); # Interest rate
# #model only solves with zero growth rate currently
# @NLparameter(cge, gr == 0.0); # Growth rate
# @NLparameter(cge, dr == 0.02); # Depreciation rate

@NLparameter(cge, rho == 0.05); # interest rate
@NLparameter(cge, eta == 0.02); # growth rate --- try sector and regions specific
@NLparameter(cge, delta == 0.07); # capital depreciation rate
@NLparameter(cge, thetax == 0.75); # extant production share
#@NLparameter(cge, beta[t in years] == (1/(1 + value(rho)))^(t-mod_year)); #discount factor or present value multiplier

# etars_d = Dict()
# [etars_d[r,s]=0.0 for r in regions, s in sectors]

#@NLparameter(cge, etars[r in regions, s in sectors] == get(etars_d,(r,s),0.0));
@NLparameter(cge, etars[r in regions, s in sectors] == 0.0);
# set_value(etars["ca","uti"], 0.03);

#new capital endowment
@NLparameter(cge, ks_n[r in regions, s in sectors] ==
             value(kd0[r, s])  * (value(delta)+value(eta)+value(etars[r,s])) / (1 + value(eta)) );

# mutable old capital endowment
@NLparameter(cge, ks_s[r in regions, s in sectors] ==
             value(kd0[r, s]) * (1 - value(thetax)) - value(ks_n[r,s]) );


# Extant capital endowment
@NLparameter(cge, ks_x[r in regions, s in sectors] ==
             value(kd0[r, s]) * value(thetax) );

# Labor endowment
@NLparameter(cge, le0[r in regions, s in sectors] == value(ld0[r,s]));


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

sv = 0.001
# sub_set_y = filter(x -> y_check[x] != 0.0, combvec(regions, sectors));
# sub_set_x = filter(x -> haskey(s0, x), combvec(regions, goods));
# sub_set_a = filter(x -> a_set[x[1], x[2]] != 0.0, combvec(regions, goods));
# sub_set_pa = 
#     filter(x -> haskey(a0, (x[1], x[2])), combvec(regions, goods));
# sub_set_pd =
#     filter(x -> haskey(xd0, (x[1], x[2])), combvec(regions, goods));
# sub_set_pk =
#     filter(x -> haskey(kd0, (x[1], x[2])), combvec(regions, sectors));
# sub_set_py = filter(x -> y_check[x[1], x[2]] >= 0, combvec(regions, goods));

sub_set_y = set[:Y]
sub_set_x = set[:X]
sub_set_a = set[:A]
sub_set_pa = set[:PA]
sub_set_pd = set[:PD]
sub_set_pk = set[:PK]
sub_set_py = set[:PY]

#sectors
#@variable(cge, Y[(r, s) in sub_set_y] >= sv, start = 1);
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
#@variable(cge, PK[(r, s) in sub_set_pk] >= sv, start =1); # Rental rate of capital ###
@variable(cge, PM[r in regions, m in margins] >= sv, start =1); # Margin price
@variable(cge, PC[r in regions] >= sv, start = 1); # Consumer price index #####
@variable(cge, PFX >= sv, start = 1); # Foreign exchange

#consumer:
@variable(cge,RA[r in regions]>=sv,start = value(c0[r])) ;


#--- recursive dynamic variable declaration ---
@variable(cge,YM[(r,s) in sub_set_y] >= sv, start = (1-value(thetax))); #Mutable production index - replaces Y
@variable(cge,YX[(r,s) in sub_set_y] >= sv, start = value(thetax)); #Extant production index

@variable(cge,RKX[(r,s) in sub_set_pk] >= sv, start = 1); # Return to extant capital
@variable(cge,RK[(r,s) in sub_set_pk] >= sv, start = 1); #Return to regional capital


###############################
# -- PLACEHOLDER VARIABLES --
###############################

#----------
### Recursive Model expressions

#Cobb-douglas for mutable/new
@NLexpression(cge, CVAym[r in regions, s in sectors],
              PL[r]^alpha_kl[r,s] * (haskey(RK.lookup[1], (r, s)) ? RK[(r,s)] : 1.0) ^(1-alpha_kl[r,s])
              );

#demand for labor in VA
@NLexpression(cge,ALym[r in regions, s in sectors],
              ld0[r,s] * CVAym[r,s] / PL[r]
              );

#demand for capital in VA
@NLexpression(cge,AKym[r in regions,s in sectors],
              kd0[r,s] * CVAym[r,s] / (haskey(RK.lookup[1], (r, s)) ? RK[(r,s)] : 1.0)
              );

###
#----------

#CES function for output demand - including
# exports (absent of re-exports) times the price for foreign exchange, 
# region's supply to national market times the national market price
# regional supply to local market times domestic price
@NLexpression(cge,RX[r in regions,g in goods],
  (alpha_x[r,g]*PFX^5+alpha_n[r,g]*PN[g]^5+alpha_d[r,g]*(haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0)^5)^(1/5) );

#demand for exports via demand function
@NLexpression(cge,AX[r in regions,g in goods], (x0[r,g] - rx0[r,g])*(PFX/RX[r,g])^4 );

#demand for contribution to national market 
@NLexpression(cge,AN[r in regions,g in goods], xn0[r,g]*(PN[g]/(RX[r,g]))^4 );

#demand for regionals supply to local market
@NLexpression(cge,AD[r in regions,g in goods],
  xd0[r,g] * ((haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0) / (RX[r,g]))^4 );

  ###

# CES function for tradeoff between national and domestic market
@NLexpression(cge,CDN[r in regions,g in goods],
  (theta_n[r,g]*PN[g]^(1-2)+(1-theta_n[r,g])*(haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0)^(1-2))^(1/(1-2)) );

# CES function for tradeoff between domestic consumption and foreign exports
# recall tm in the import tariff thus tm / tm0 is the relative change in import tariff rates
@NLexpression(cge,CDM[r in regions,g in goods],
  ((1-theta_m[r,g])*CDN[r,g]^(1-4)+theta_m[r,g]*(PFX*(1+tm[r,g])/(1+tm0[r,g]))^(1-4))^(1/(1-4)) );

# regions demand from the national market <- note nesting of CDN in CDM
@NLexpression(cge,DN[r in regions,g in goods],
  nd0[r,g]*(CDN[r,g]/PN[g])^2*(CDM[r,g]/CDN[r,g])^4 );

# region demand from local market <- note nesting of CDN in CDM
@NLexpression(cge,DD[r in regions,g in goods],
  dd0[r,g]*(CDN[r,g]/(haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0))^2*(CDM[r,g]/CDN[r,g])^4 );

# import demand
@NLexpression(cge,MD[r in regions,g in goods],
  m0[r,g]*(CDM[r,g]*(1+tm[r,g])/(PFX*(1+tm0[r,g])))^4 );

# final demand
@NLexpression(cge,CD[r in regions,g in goods],
  cd0[r,g]*PC[r] / (haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) );


###############################
# -- Zero Profit Conditions --
###############################

#----------
#Recursive  --- update to Y
@mapping(cge,profit_ym[(r, s) in sub_set_y],
# cost of intermediate demand
        sum((haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * id0[r,g,s] for g in goods) 
# cost of labor inputs
        + PL[r] * ALym[r,s]
# cost of capital inputs 
        + (haskey(RK.lookup[1], (r, s)) ? RK[(r,s)] : 1.0) * AKym[r,s]
        - 
# revenue from sectoral supply (take note of r/s/g indices on ys0)                
        sum((haskey(PY.lookup[1], (r, g)) ? PY[(r, g)] : 1.0)  * ys0[r,s,g] for g in goods) * (1-ty[r,s])
);

@mapping(cge,profit_yx[(r, s) in sub_set_y],
# cost of intermediate demand
        sum((haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * id0[r,g,s] for g in goods) 
# cost of labor inputs
        + PL[r] * ld0[r,s]
# cost of capital inputs 
        + (haskey(RKX.lookup[1], (r, s)) ? RKX[(r,s)] : 1.0) * kd0[r,s]
        - 
# revenue from sectoral supply (take note of r/s/g indices on ys0)                
        sum((haskey(PY.lookup[1], (r, g)) ? PY[(r, g)] : 1.0)  * ys0[r,s,g] for g in goods) * (1-ty[r,s])
);

#----------

# @mapping(cge,profit_y[(r, s) in sub_set_y],
# # cost of intermediate demand
#         sum((haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * id0[r,g,s] for g in goods) 
# # cost of labor inputs
#         + PL[r] * AL[r,s]
# # cost of capital inputs 
#         + (haskey(PK.lookup[1], (r, s)) ? PK[(r, s)] : 1.0)* AK[r,s]
#         - 
# # revenue from sectoral supply (take note of r/s/g indices on ys0)                
#         sum((haskey(PY.lookup[1], (r, g)) ? PY[(r, g)] : 1.0)  * ys0[r,s,g] for g in goods) * (1-ty[r,s])
# );



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

#----------
#Recursive dynamics mkt clearance

@mapping(cge,market_rk[(r, s) in sub_set_pk],
        (ks_n[r,s] + ks_s[r,s])
        - 
#current year's capital 
       (haskey(YM.lookup[1], (r, s)) ? YM[(r, s)] : 1.) * AKym[r,s]
);

@mapping(cge,market_rkx[(r, s) in sub_set_pk],
         (ks_x[r,s])
         -
       (haskey(YX.lookup[1], (r, s)) ? YX[(r, s)] : 1.) * kd0[r,s]
);
         

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
#            + sum((haskey(Y.lookup[1], (r, s)) ? Y[(r, s)] : 1) * id0[r,g,s] for s in sectors if (y_check[r,s] > 0))
            + sum((haskey(YM.lookup[1], (r, s)) ? YM[(r, s)] : 1) * id0[r,g,s] for s in sectors if (y_check[r,s] > 0))
            + sum((haskey(YX.lookup[1], (r, s)) ? YX[(r, s)] : 1) * id0[r,g,s] for s in sectors if (y_check[r,s] > 0))
        )
);

@mapping(cge,market_py[(r, g) in sub_set_py],
# sectoral supply
#        sum((haskey(Y.lookup[1], (r, s)) ? Y[(r, s)] : 1) *ys0[r,s,g] for s in sectors)
         sum((haskey(YM.lookup[1], (r, s)) ? YM[(r, s)] : 1) *ys0[r,s,g] for s in sectors)
         + sum((haskey(YX.lookup[1], (r, s)) ? YX[(r, s)] : 1) *ys0[r,s,g] for s in sectors)
# household production (exogenous)        
        + yh0[r,g]
        - 
# aggregate supply (akin to market demand)                
       (haskey(X.lookup[1], (r, g)) ? X[(r, g)] : 1) * s0[r,g]
);

@mapping(cge,market_pl[r in regions],
# supply of labor
        sum(le0[r,s] for s in sectors)
        - 
# demand for labor in all sectors        
#        sum((haskey(Y.lookup[1], (r, s)) ? Y[(r, s)] : 1) * AL[r,s] for s in sectors)
        ( 
                sum((haskey(YM.lookup[1], (r, s)) ? YM[(r, s)] : 1) * ALym[r,s] for s in sectors)
                + sum((haskey(YX.lookup[1], (r, s)) ? YX[(r, s)] : 1) * ld0[r,s] for s in sectors)
        )
);
#----------


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


@mapping(cge,market_pm[r in regions, m in margins],
# margin supply 
        MS[r,m] * sum(md0[r,m,gm] for gm in goods_margins)
        - 
# margin demand        
        sum((haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.0) * md0[r,m,g] for g in goods)
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
        + sum((haskey(X.lookup[1], (r, g)) ? X[(r, g)] : 1.0)  * AX[r,g] for r in regions for g in goods)
# supply of re-exports        
        + sum((haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.0) * rx0[r,g] for r in regions for g in goods if (a_set[r,g] != 0))
        - 
# import demand                
        sum((haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.0) * MD[r,g] for r in regions for g in goods if (a_set[r,g] != 0))
);


#----------
#Income balance update for recursive dynamics
@mapping(cge,income_ra[r in regions],
# consumption/utility
        RA[r] 
        - 
        (
# labor income        
        PL[r] * sum(le0[r,s] for s in sectors)
# capital income        
            +sum((haskey(RK.lookup[1], (r, s)) ? RK[(r,s)] : 1.0) * (ks_n[r,s]+ks_s[r,s]) for s in sectors)
            +sum((haskey(RKX.lookup[1], (r, s)) ? RKX[(r,s)] : 1.0) * ks_x[r,s] for s in sectors)
        #+ sum((haskey(PK.lookup[1], (r, s)) ? PK[(r,s)] : 1.0) * kd0[r,s] for s in sectors)
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
            + sum( (haskey(YM.lookup[1], (r, s)) ? YM[(r, s)] : 1) * ys0[r,s,g] * ty[r,s] for s in sectors, g in goods)
            + sum( (haskey(YX.lookup[1], (r, s)) ? YX[(r, s)] : 1) * ys0[r,s,g] * ty[r,s] for s in sectors, g in goods)
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

# export the path license string to the environment
# this is now done in the SLiDE initiation steps 
ENV["PATH_LICENSE_STRING"]="2617827524&Courtesy&&&USR&64785&11_12_2017&1000&PATH&GEN&31_12_2020&0_0_0&5000&0_0"

# solve the model

status = solveMCP(cge)

for t in 1:2

#Save for later when making investment better
#scale(r,s,t) = (1-delta)*(ks_n(r,s,"%bmkyr%")+ks_s(r,s,"%bmkyr%")+ks_x(r,s,"%bmkyr%")) / (i0(r,s)*(rho+delta));
#ks_n(r,s,t) = scale(r,s,t)*i0(r,s))*I.l(r,s)*(rho+delta);
#total_cap = ks_n+ks_s+ks_x

total_cap = Dict()
[total_cap[r,s]=value(ks_n[r,s])+value(ks_s[r,s])+value(ks_x[r,s]) for r in regions, s in sectors]

scalecap=Dict()
[scalecap[r,s]=(value(delta))*total_cap[r,s]/(value(i0[r,s])*(value(rho)+value(delta))) for r in regions, s in sectors]
# get(scalecap, (r,s), 0.0)

# Update parameters for next period
for r in regions, s in sectors
#update capital endowments
    set_value(ks_s[r,s], (1-value(delta)) * (value(ks_s[r,s]) + value(ks_n[r,s])));
    set_value(ks_x[r,s], (1-value(delta)) * value(ks_x[r,s]));
#    set_value(ks_n[r,s], (value(rho) + value(delta)) * value(i0[r,s]) );
    set_value(ks_n[r,s], value(delta)*(1 + value(eta) + value(etars[r,s]))*get(total_cap,(r,s),0.0));
#    set_value(ks_n[r,s], value(delta)*get(total_cap,(r,s),0.0));
end

#steady-state investment assumption test
testk=Dict()
[testk[r,s]=value(kd0[r,s])-(value(ks_n[r,s])+value(ks_s[r,s])+value(ks_x[r,s])) for r in regions, s in sectors]

for r in regions, s in sectors
#update labor endowments --- I think I need separate parameters for labor endowments versus demand
    set_value(le0[r,s], (1 + value(eta)+value(etars[r,s])) * value(le0[r,s]));
end

for r in regions
    set_value(bopdef0[r], (1 + value(eta)) * value(bopdef0[r]));
end

for r in regions, g in goods
    set_value(g0[r,g], (1 + value(eta)+value(etars[r,g])) * value(g0[r,g]));
    set_value(i0[r,g], (1 + value(eta)+value(etars[r,g])) * value(i0[r,g]));
end

set_start_value.(all_variables(cge), result_value.(all_variables(cge)));

for r in regions
    set_start_value(C[r], result_value(C[r])*(1+value(eta)));
end

for (r,g) in sub_set_x
    set_start_value(X[(r,g)], result_value(X[(r,g)])*(1+value(eta)+value(etars[r,g])));
end


for (r,g) in sub_set_a    
    set_start_value(A[(r,g)], result_value(A[(r,g)])*(1+value(eta)+value(etars[r,g])));
end

for r in regions, m in margins
    set_start_value(MS[r,m], result_value(MS[r,m])*(1+value(eta)));
end

for (r,s) in sub_set_y
    set_start_value(YX[(r,s)], result_value(YX[(r,s)])*(1-value(delta)));
    set_start_value(YM[(r,s)], result_value(YM[(r,s)])*(1+value(eta)+value(etars[r,s])));
end


for r in regions, s in sectors
#update value shares
    set_value(alpha_kl[r,s], ensurefinite(value(ld0[r,s])/(value(ld0[r,s]) + value(kd0[r,s]))));
end

for r in regions, g in goods
#update value shares
    set_value(alpha_x[r,g], ensurefinite((value(x0[r, g]) - value(rx0[r, g])) / value(s0[r, g])));
    set_value(alpha_d[r,g], ensurefinite((value(xd0[r,g])) / value(s0[r, g])));
    set_value(alpha_n[r,g], ensurefinite(value(xn0[r,g]) / (value(s0[r, g]))));
    set_value(theta_n[r,g], ensurefinite(value(nd0[r, g]) / (value(nd0[r, g]) + value(dd0[r, g]))));
    set_value(theta_m[r,g], ensurefinite((1+value(tm0[r, g])) * value(m0[r, g]) / (value(nd0[r, g]) + value(dd0[r, g]) + (1 + value(tm0[r, g])) * value(m0[r, g]))));
end

# ensurefinite(alpha_kl)
# ensurefinite(alpha_x)
# ensurefinite(alpha_d)
# ensurefinite(alpha_n)
# ensurefinite(theta_n)
# ensurefinite(theta_m)



#set up the options for the path solver
PATHSolver.options(convergence_tolerance=1e-6, output=:yes, time_limit=3600, cumulative_iteration_limit=100000)
#=,
crash_iteration_limit=50, merit_function=:fischer, crash_method=:pnewton, crash_minimum_dimension=1, crash_nbchange_limit=1,
crash_perturb=1, crash_searchtype=:line, minor_iteration_limit=1000, nms=1, nms_searchtype=:line, nms_maximimum_watchdogs=5,
preprocess=1, proximal_perturbation=0, chen_lambda=0.8, factorization_method=:lusol, gradient_searchtype=:arc, gradient_step_limit=10,
interrupt_limit=10, lemke_rank_deficiency_iterations=10, lemke_start=:automatic, lemke_start_type=:slack)
=#

# export the path license string to the environment
# this is now done in the SLiDE initiation steps 
ENV["PATH_LICENSE_STRING"]="2617827524&Courtesy&&&USR&64785&11_12_2017&1000&PATH&GEN&31_12_2020&0_0_0&5000&0_0"

# solve next period
status = solveMCP(cge)
end