
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

##########
# FUNCTIONS
##########

#replace here with "collect"
function key_to_vec(d::Dict,index_num::Int64)
  return [k[index_num] for k in keys(d)]
end

function fill_zero(source::Dict,tofill::Dict)
  for k in keys(source)
      if !haskey(tofill,k)
          push!(tofill,k=>0)
      end
  end
end

function fill_zero(source::Tuple, tofill::Dict)
# Assume all possible permutations of keys should be present
# and determine which are missing.
  allkeys = vcat(collect(Base.Iterators.product(source...))...)
  missingkeys = setdiff(allkeys, collect(keys(tofill)))

# Add
  [push!(tofill, fill=>0) for fill in missingkeys]
  return tofill
end

#function here simplifies the loading and subsequent subsetting of the dataframes
function read_data_temp(file::String,year::Int64,dir::String,desc::String)
  df = SLiDE.read_file(dir,CSVInput(name=string(file,".csv"),descriptor=desc))
  df = df[df[!,:yr].==year,:]
  return df
end

function df_to_dict(df::DataFrame,remove_columns::Vector{Symbol},value_column::Symbol)
  colnames = setdiff(names(df),[remove_columns; value_column])
  return Dict(tuple(row[colnames]...)=>row[:Val] for row in eachrow(df))
end


############
# LOAD DATA
############

# year for the model to be based off of
mod_year = 2016

#specify the path where the dumped csv files are stored
data_temp_dir = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "model", "data_temp"))

#blueNOTE contains a dictionary of the parameters needed to specify the model
blueNOTE = Dict(
    :ys0 => df_to_dict(read_data_temp("ys0",mod_year,data_temp_dir,"Sectoral supply"),[:yr],:Val),
    :id0 => df_to_dict(read_data_temp("id0",mod_year,data_temp_dir,"Intermediate demand"),[:yr],:Val),
    :ld0 => df_to_dict(read_data_temp("ld0",mod_year,data_temp_dir,"Labor demand"),[:yr],:Val),
    :kd0 => df_to_dict(read_data_temp("kd0",mod_year,data_temp_dir,"Capital demand"),[:yr],:Val),
    :ty0 => df_to_dict(read_data_temp("ty0",mod_year,data_temp_dir,"Production tax"),[:yr],:Val),
    :m0 => df_to_dict(read_data_temp("m0",mod_year,data_temp_dir,"Imports"),[:yr],:Val),
    :x0 => df_to_dict(read_data_temp("x0",mod_year,data_temp_dir,"Exports of goods and services"),[:yr],:Val),
    :rx0 => df_to_dict(read_data_temp("rx0",mod_year,data_temp_dir,"Re-exports of goods and services"),[:yr],:Val),
    :md0 => df_to_dict(read_data_temp("md0",mod_year,data_temp_dir,"Total margin demand"),[:yr],:Val),
    :nm0 => df_to_dict(read_data_temp("nm0",mod_year,data_temp_dir,"Margin demand from national market"),[:yr],:Val),
    :dm0 => df_to_dict(read_data_temp("dm0",mod_year,data_temp_dir,"Margin supply from local market"),[:yr],:Val),
    :s0 => df_to_dict(read_data_temp("s0",mod_year,data_temp_dir,"Aggregate supply"),[:yr],:Val),
    :a0 => df_to_dict(read_data_temp("a0",mod_year,data_temp_dir,"Armington supply"),[:yr],:Val),
    :ta0 => df_to_dict(read_data_temp("ta0",mod_year,data_temp_dir,"Tax net subsidy rate on intermediate demand"),[:yr],:Val),
    :tm0 => df_to_dict(read_data_temp("tm0",mod_year,data_temp_dir,"Import tariff"),[:yr],:Val),
    :cd0 => df_to_dict(read_data_temp("cd0",mod_year,data_temp_dir,"Final demand"),[:yr],:Val),
    :c0 => df_to_dict(read_data_temp("c0",mod_year,data_temp_dir,"Aggregate final demand"),[:yr],:Val),
    :yh0 => df_to_dict(read_data_temp("yh0",mod_year,data_temp_dir,"Household production"),[:yr],:Val),
    :bopdef0 => df_to_dict(read_data_temp("bopdef0",mod_year,data_temp_dir,"Balance of payments"),[:yr],:Val),
    :hhadj => df_to_dict(read_data_temp("hhadj",mod_year,data_temp_dir,"Household adjustment"),[:yr],:Val),
    :g0 => df_to_dict(read_data_temp("g0",mod_year,data_temp_dir,"Government demand"),[:yr],:Val),
    :i0 => df_to_dict(read_data_temp("i0",mod_year,data_temp_dir,"Investment demand"),[:yr],:Val),
    :xn0 => df_to_dict(read_data_temp("xn0",mod_year,data_temp_dir,"Regional supply to national market"),[:yr],:Val),
    :xd0 => df_to_dict(read_data_temp("xd0",mod_year,data_temp_dir,"Regional supply to local market"),[:yr],:Val),
    :dd0 => df_to_dict(read_data_temp("dd0",mod_year,data_temp_dir,"Regional demand from local  market"),[:yr],:Val),
    :nd0 => df_to_dict(read_data_temp("nd0",mod_year,data_temp_dir,"Regional demand from national market"),[:yr],:Val)
)


###############
# -- SETS --
###############

# read sets from their dumped CSVs
# these are converted to a vector of strings such that we can use them to populate variable indices
# and to use them as as conditionals (e.g. see the use of goods_margins)
regions = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_r.csv"),descriptor="region set"))[!,:Dim1]);
sectors = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_s.csv"),descriptor="sector set"))[!,:Dim1]);
goods = sectors;
margins = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_m.csv"),descriptor="margin set"))[!,:Dim1]);
goods_margins = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_gm.csv"),descriptor="goods with margins set"))[!,:g]);

# need to fill in zeros to avoid missing keys
fill_zero(tuple(regions,sectors,goods),blueNOTE[:ys0])
fill_zero(tuple(regions,goods,sectors),blueNOTE[:id0])
fill_zero(tuple(regions,sectors),blueNOTE[:ld0])
fill_zero(tuple(regions,sectors),blueNOTE[:kd0])
fill_zero(tuple(regions,sectors),blueNOTE[:ty0])
fill_zero(tuple(regions,goods),blueNOTE[:m0])
fill_zero(tuple(regions,goods),blueNOTE[:x0])
fill_zero(tuple(regions,goods),blueNOTE[:rx0])
fill_zero(tuple(regions,margins,goods),blueNOTE[:md0])
fill_zero(tuple(regions,goods,margins),blueNOTE[:nm0])
fill_zero(tuple(regions,goods,margins),blueNOTE[:dm0])
fill_zero(tuple(regions,goods),blueNOTE[:s0])
fill_zero(tuple(regions,goods),blueNOTE[:a0])
fill_zero(tuple(regions,goods),blueNOTE[:ta0])
fill_zero(tuple(regions,goods),blueNOTE[:tm0])
fill_zero(tuple(regions,goods),blueNOTE[:cd0])
fill_zero(tuple(regions),blueNOTE[:c0])
fill_zero(tuple(regions,goods),blueNOTE[:yh0])
fill_zero(tuple(regions),blueNOTE[:bopdef0])
fill_zero(tuple(regions),blueNOTE[:hhadj])
fill_zero(tuple(regions,goods),blueNOTE[:g0])
fill_zero(tuple(regions,goods),blueNOTE[:i0])
fill_zero(tuple(regions,goods),blueNOTE[:xn0])
fill_zero(tuple(regions,goods),blueNOTE[:xd0])
fill_zero(tuple(regions,goods),blueNOTE[:dd0])
fill_zero(tuple(regions,goods),blueNOTE[:nd0])

#need to have both benchmark and counterfactual tax rates
#more important here is the distinction between tm and tm0
#since the ratio of the two is used in the calculation of 
#the value share - good to be clear on ta as well though
blueNOTE[:tm] = blueNOTE[:tm0]
blueNOTE[:ta] = blueNOTE[:ta0]

#following subsets are used to limit the size of the model
#similar to conditionals within GAMS
a_set = Dict()
[a_set[r,g] = blueNOTE[:a0][r,g] + blueNOTE[:rx0][r,g] for r in regions for g in goods]
# y_check is used to make sure the r/s combination is a valid output
y_check = Dict()
[y_check[r,s] = sum(blueNOTE[:ys0][r,s,g] for g in goods) for r in regions for s in sectors]


##############
# PARAMETERS
##############

alpha_kl = Dict() #value share of labor in the K/L nest for regions and sectors
alpha_x  = Dict() #export value share
alpha_d  = Dict() #local/domestic supply share
alpha_n  = Dict() #national supply share
theta_n  = Dict() #national share of domestic Absorption
theta_m  = Dict() #domestic share of absorption

for k in keys(blueNOTE[:ld0])
    val = blueNOTE[:ld0][k] / (blueNOTE[:kd0][k] + blueNOTE[:ld0][k])
    push!(alpha_kl,k=>val)
end

for k in keys(blueNOTE[:x0])
    val = (blueNOTE[:x0][k] - blueNOTE[:rx0][k]) / blueNOTE[:s0][k]   
    push!(alpha_x,k=>val)
end

for k in keys(blueNOTE[:xd0])
    val = blueNOTE[:xd0][k] / blueNOTE[:s0][k]
    push!(alpha_d,k=>val)
end

for k in keys(blueNOTE[:xn0])
    val = blueNOTE[:xn0][k] / blueNOTE[:s0][k]
    push!(alpha_n,k=>val)
end

for k in keys(blueNOTE[:nd0])
    val = blueNOTE[:nd0][k] / (blueNOTE[:nd0][k] + blueNOTE[:dd0][k])
    push!(theta_n,k=>val)
end

for k in keys(blueNOTE[:tm0])
    val = (1+blueNOTE[:tm0][k]) * blueNOTE[:m0][k] / (blueNOTE[:nd0][k]+blueNOTE[:dd0][k]+(1+blueNOTE[:tm0][k]) * blueNOTE[:m0][k])
    push!(theta_m,k=>val)
end


################
# VARIABLES
################

cge = MCPModel();

# small value that acts as a lower limit to variable values
# default is zero
sv = 0.00

#sectors
@variable(cge,Y[r in regions,s in sectors]>=sv,start=1)
@variable(cge,X[r in regions,g in goods]>=sv,start=1)
@variable(cge,A[r in regions,g in goods]>=sv,start=1)
@variable(cge,C[r in regions]>=sv,start=1)
@variable(cge,MS[r in regions,m in margins]>=sv,start=1)

#commodities:
@variable(cge,PA[r in regions,g in goods]>=sv,start=1) # Regional market (input)
@variable(cge,PY[r in regions,g in goods]>=sv,start=1) # Regional market (output)
@variable(cge,PD[r in regions,g in goods]>=sv,start=1) # Local market price
@variable(cge,PN[g in goods]>=sv,start=1) # National market
@variable(cge,PL[r in regions]>=sv,start=1) # Wage rate
@variable(cge,PK[r in regions,s in sectors]>=sv,start=1) # Rental rate of capital
@variable(cge,PM[r in regions,m in margins]>=sv,start=1) # Margin price
@variable(cge,PC[r in regions]>=sv,start=1) # Consumer price index
@variable(cge,PFX>=sv,start=1) # Foreign exchange

#consumer:
@variable(cge,RA[r in regions]>=sv,start=blueNOTE[:c0][(r,)]) # Representative agent

###############################
# -- PLACEHOLDER VARIABLES --
###############################

@NLexpression(cge,CVA[r in regions,s in sectors],
  PL[r]^alpha_kl[r,s] * PK[r,s] ^(1-alpha_kl[r,s]) );

@NLexpression(cge,AL[r in regions, s in sectors],
  blueNOTE[:ld0][r,s] * CVA[r,s] / PL[r] );

@NLexpression(cge,AK[r in regions,s in sectors],
  blueNOTE[:kd0][r,s] * CVA[r,s] / PK[r,s] );

  ###

@NLexpression(cge,RX[r in regions,g in goods],
  (alpha_x[r,g]*PFX^5+alpha_n[r,g]*PN[g]^5+alpha_d[r,g]*PD[r,g]^5)^(1/5) );

@NLexpression(cge,AX[r in regions,g in goods],
  (blueNOTE[:x0][r,g] - blueNOTE[:rx0][r,g])*(PFX/RX[r,g])^4 );

@NLexpression(cge,AN[r in regions,g in goods],
  blueNOTE[:xn0][r,g]*(PN[g]/(RX[r,g]))^4 );

@NLexpression(cge,AD[r in regions,g in goods],
  blueNOTE[:xd0][r,g] * (PD[r,g] / (RX[r,g]))^4 );

  ###

@NLexpression(cge,CDN[r in regions,g in goods],
  (theta_n[r,g]*PN[g]^(1-2)+(1-theta_n[r,g])*PD[r,g]^(1-2))^(1/(1-2)) );

#!!!! here replaced first :tm with :tm0
@NLexpression(cge,CDM[r in regions,g in goods],
  ((1-theta_m[r,g])*CDN[r,g]^(1-4)+theta_m[r,g]*
  (PFX*(1+blueNOTE[:tm][r,g])/(1+blueNOTE[:tm0][r,g]))^(1-4))^(1/(1-4)) 
  );

  ###

@NLexpression(cge,DN[r in regions,g in goods],
  blueNOTE[:nd0][r,g]*(CDN[r,g]/PN[g])^2*(CDM[r,g]/CDN[r,g])^4 );

@NLexpression(cge,DD[r in regions,g in goods],
  blueNOTE[:dd0][r,g]*(CDN[r,g]/PD[r,g])^2*(CDM[r,g]/CDN[r,g])^4 );

@NLexpression(cge,MD[r in regions,g in goods],
  blueNOTE[:m0][r,g]*(CDM[r,g]*(1+blueNOTE[:tm][r,g])/(PFX*(1+blueNOTE[:tm0][r,g])))^4 );

@NLexpression(cge,CD[r in regions,g in goods],
  blueNOTE[:cd0][r,g]*PC[r] / PA[r,g] );


###############################
# -- Zero Profit Conditions --
###############################

@mapping(cge,profit_y[r in regions,s in sectors],
                sum(PA[r,g] * blueNOTE[:id0][r,g,s] for g in goods) 
                + PL[r] * AL[r,s]
                + PK[r,s] * AK[r,s]
                - 
                sum(PY[r,g] * blueNOTE[:ys0][r,s,g] for g in goods) * (1-blueNOTE[:ty0][r,s])
);


@mapping(cge,profit_x[r in regions,g in goods],
                  PY[r,g] * blueNOTE[:s0][r,g] 
                  - 
                  (PFX * AX[r,g]
                + PN[g] * AN[r,g]
                + PD[r,g] * AD[r,g])
);


@mapping(cge,profit_a[r in regions,g in goods],
                  PN[g] * DN[r,g] 
                + PD[r,g] * DD[r,g] 
                + PFX * (1+blueNOTE[:tm0][r,g]) * MD[r,g]
                + sum(PM[r,m] * blueNOTE[:md0][r,m,g] for m in margins)
                  - ( 
                  PA[r,g] * (1-blueNOTE[:ta][r,g]) * blueNOTE[:a0][r,g] 
                + PFX * blueNOTE[:rx0][r,g]
));

@mapping(cge,profit_c[r in regions],
                  sum(PA[r,g] * CD[r,g] for g in goods)
                  - 
                  PC[r] * blueNOTE[:c0][(r,)]
);


@mapping(cge,profit_ms[r in regions, m in margins],
    sum(PN[gm]   * blueNOTE[:nm0][r,gm,m] for gm in goods_margins)
  + sum(PD[r,gm] * blueNOTE[:dm0][r,gm,m] for gm in goods_margins)
    - 
    PM[r,m] * sum(blueNOTE[:md0][r,m,gm] for gm in goods_margins)
);


###################################
# -- Market Clearing Conditions -- 
###################################


@mapping(cge,market_pa[r in regions, g in goods],
        A[r,g] * blueNOTE[:a0][r,g] 
        - ( 
        blueNOTE[:g0][r,g] 
        + blueNOTE[:i0][r,g]
        + C[r] * CD[r,g]
        + sum(Y[r,s] * blueNOTE[:id0][r,g,s] for s in sectors if (y_check[r,s] > 0))
        )
);


@mapping(cge,market_py[r in regions, g in goods],
        sum(Y[r,s] * blueNOTE[:ys0][r,s,g] for s in sectors)
      + blueNOTE[:yh0][r,g]
        - 
        X[r,g] * blueNOTE[:s0][r,g]
);


@mapping(cge,market_pd[r in regions, g in goods],
        X[r,g] * AD[r,g] 
        - ( 
        A[r,g] * DD[r,g]
        + sum(MS[r,m] * blueNOTE[:dm0][r,g,m] for m in margins if (g in goods_margins ) )  
        )
);

@mapping(cge,market_pn[g in goods],
        sum(X[r,g] * AN[r,g] for r in regions)
        - ( 
        sum(A[r,g] * DN[r,g] for r in regions)
        + sum(MS[r,m] * blueNOTE[:nm0][r,g,m] for r in regions for m in margins if (g in goods_margins) )
));

@mapping(cge,market_pl[r in regions],
        sum(blueNOTE[:ld0][r,s] for s in sectors)
        - 
        sum(Y[r,s] * AL[r,s] for s in sectors)
);


@mapping(cge,market_pk[r in regions, s in sectors],
        blueNOTE[:kd0][r,s]
        - Y[r,s] * AK[r,s]
);

@mapping(cge,market_pm[r in regions, m in margins],
        MS[r,m] * sum(blueNOTE[:md0][r,m,gm] for gm in goods_margins)
        - (
        sum(A[r,g] * blueNOTE[:md0][r,m,g] for g in goods)
));

@mapping(cge,market_pc[r in regions],
        C[r] * blueNOTE[:c0][(r,)] - ( RA[r] / PC[r]
));


@mapping(cge,market_pfx,
        sum(blueNOTE[:bopdef0][(r,)] for r in regions)
        + sum(X[r,g] * AX[r,g] for r in regions for g in goods)
# add a set here        
        + sum(A[r,g] * blueNOTE[:rx0][r,g] for r in regions for g in goods if (a_set[r,g] != 0))
#need a_set here        
        - sum(A[r,g] * MD[r,g] for r in regions for g in goods)
);

@mapping(cge,income_ra[r in regions],
        RA[r] - ( 
        sum(PY[r,g]*blueNOTE[:yh0][r,g] for g in goods)
#will fix reference here...        
        + PFX * (blueNOTE[:bopdef0][(r,)] + blueNOTE[:hhadj][(r,)])
        - sum(PA[r,g] * (blueNOTE[:g0][r,g] + blueNOTE[:i0][r,g]) for g in goods)
        + PL[r] * sum(blueNOTE[:ld0][r,s] for s in sectors)
        + sum(PK[r,s] * blueNOTE[:kd0][r,s] for s in sectors)
#changed tm to tm0 here...        
        + sum(A[r,g] * MD[r,g]* PFX * blueNOTE[:tm0][r,g] for g in goods if (a_set[r,g] != 0))
#change ta to ta0 here
        + sum(A[r,g] * blueNOTE[:a0][r,g]*PA[r,g]*blueNOTE[:ta][r,g] for g in goods if (a_set[r,g] != 0) )
        + sum(Y[r,s] * blueNOTE[:ys0][r,s,g] * blueNOTE[:ty0][r,s] for s in sectors for g in goods)
));


####################################
# -- Complementarity Conditions --
####################################

# equations with conditions cannot be paired 
# see workaround here: https://github.com/chkwon/Complementarity.jl/issues/37
[fix(PK[r,s],1;force=true) for r in regions for s in sectors if !(blueNOTE[:kd0][r,s] > 0)]
[fix(PA[r,g],1,force=true) for r in regions for g in goods if !(blueNOTE[:a0][r,g]>0)]
[fix(PY[r,g],1,force=true) for r in regions for g in goods if !(y_check[r,g]>0)]


[fix(Y[r,s],1,force=true) for r in regions for s in sectors if !(y_check[r,s] > 0)]
[fix(X[r,g],1,force=true) for r in regions for g in goods if !(blueNOTE[:s0][r,g] > 0)]

# following lines are used in the GAMS version but not here 
# and result in a non-zero residual for the benchmark
#a_fix = Dict()
#[a_fix[r,g] = blueNOTE[:a0][r,g] + blueNOTE[:rx0][r,g] for r in regions for g in goods]
#[fix(PD[r,g],0,force=true) for r in regions for g in goods if !(blueNOTE[:xd0][r,g] != 0)]
#[fix(A[r,g],0,force=true) for r in regions for g in goods if !(a_fix[r,g] != 0)]

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
PATHSolver.options(convergence_tolerance=1e-8, output=:yes, time_limit=3600)

# export the path license string to the environment
# this is now done in the SLiDE initiation steps 
ENV["PATH_LICENSE_STRING"]="2617827524&Courtesy&&&USR&64785&11_12_2017&1000&PATH&GEN&31_12_2020&0_0_0&5000&0_0"

# solve the model
status = solveMCP(cge)



