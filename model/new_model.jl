####################################
#
# Extension of Canonical blueNOTE 
#    model to include dynamics
#
####################################

using SLiDE
using CSV
using JuMP
using Complementarity
using DataFrames

# Note - using the comlementarity package until the native JuMP implementation 
#        of complementarity constraints allows for exponents neq 0/1/2
#               --- most recently tested on May 11, 2020 --- 

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

##################
# -- FUNCTIONS --
##################

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

function combvec(set_a...)
    return vec(collect(Iterators.product(set_a...)))
end

############
# LOAD DATA
############

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
ys0 = blueNOTE[:ys0]
id0 = blueNOTE[:id0]
ld0 = blueNOTE[:ld0]
kd0 = blueNOTE[:kd0]
ty0 = blueNOTE[:ty0]
m0 = blueNOTE[:m0]
x0 = blueNOTE[:x0]
rx0 = blueNOTE[:rx0]
md0 = blueNOTE[:md0]
nm0 = blueNOTE[:nm0]
dm0 = blueNOTE[:dm0]
s0 = blueNOTE[:s0]
a0 = blueNOTE[:a0]
ta0 = blueNOTE[:ta0]
tm0 = blueNOTE[:tm0]
cd0 = blueNOTE[:cd0]
c0 = blueNOTE[:c0]
yh0 = blueNOTE[:yh0]
bopdef0 = blueNOTE[:bopdef0]
hhadj = blueNOTE[:hhadj]
g0 = blueNOTE[:g0]
i0 = blueNOTE[:i0]
xn0 = blueNOTE[:xn0]
xd0 = blueNOTE[:xd0]
dd0 = blueNOTE[:dd0]
nd0 = blueNOTE[:nd0]
tm = tm0
ta = ta0
ty = ty0
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
blueNOTE[:ty] = blueNOTE[:ty0]


#following subsets are used to limit the size of the model
# the a_set restricts the A and PA variables indices to those
# with positive armington supply or re-exports
a_set = Dict()
[a_set[r,g] = blueNOTE[:a0][r,g] + blueNOTE[:rx0][r,g] for r in regions for g in goods]

# y_check is used to make sure the r/s combination 
# has a reference amount of sectoral supply
y_check = Dict()
[y_check[r,s] = sum(blueNOTE[:ys0][r,s,g] for g in goods) for r in regions for s in sectors];

########## Model ##########
cge = MCPModel();

##############
# PARAMETERS
##############
@NLparameter(
    cge,
    ys0_p[r in regions, s in sectors, g in goods] == get(ys0, (r, s, g), 0.0)
);
@NLparameter(
    cge,
    id0_p[r in regions, s in sectors, g in goods] == get(id0, (r, s, g), 0.0)
);
@NLparameter(cge, ld0_p[r in regions, s in sectors] == get(ld0, (r, s), 0.0));
@NLparameter(cge, kd0_p[r in regions, s in sectors] == get(kd0, (r, s), 0.0));
@NLparameter(cge, ty0_p[r in regions, s in sectors] == get(ty0, (r, s), 0.0));
@NLparameter(cge, ty_p[r in regions, s in sectors] == get(ty, (r, s), 0.0));
@NLparameter(cge, m0_p[r in regions, g in goods] == get(m0, (r, g), 0.0));
@NLparameter(cge, x0_p[r in regions, g in goods] == get(x0, (r, g), 0.0));
@NLparameter(cge, rx0_p[r in regions, g in goods] == get(rx0, (r, g), 0.0));
@NLparameter(
    cge,
    md0_p[r in regions, m in margins, g in goods] == get(md0, (r, m, g), 0.0)
);
@NLparameter(
    cge,
    nm0_p[r in regions, g in goods, m in margins] == get(nm0, (r, g, m), 0.0)
);
@NLparameter(
    cge,
    dm0_p[r in regions, g in goods, m in margins] == get(dm0, (r, g, m), 0.0)
);
@NLparameter(cge, s0_p[r in regions, g in goods] == get(s0, (r, g), 0.0));
@NLparameter(cge, a0_p[r in regions, g in goods] == get(a0, (r, g), 0.0));
@NLparameter(cge, ta0_p[r in regions, g in goods] == get(ta0, (r, g), 0.0));
@NLparameter(cge, ta_p[r in regions, g in goods] == get(ta, (r, g), 0.0));
@NLparameter(cge, tm0_p[r in regions, g in goods] == get(tm0, (r, g), 0.0));
@NLparameter(cge, tm_p[r in regions, g in goods] == get(tm, (r, g), 0.0));
@NLparameter(cge, cd0_p[r in regions, g in goods] == get(cd0, (r, g), 0.0));
@NLparameter(cge, c0_p[r in regions] == get(c0, (r,), 0.0));
@NLparameter(cge, yh0_p[r in regions, g in goods] == get(yh0, (r, g), 0.0));
@NLparameter(cge, bopdef0_p[r in regions] == get(bopdef0, (r,), 0.0));
@NLparameter(cge, hhadj_p[r in regions] == get(hhadj, (r,), 0.0));
@NLparameter(cge, g0_p[r in regions, g in goods] == get(g0, (r, g), 0.0));
@NLparameter(cge, xn0_p[r in regions, g in goods] == get(xn0, (r, g), 0.0));
@NLparameter(cge, xd0_p[r in regions, g in goods] == get(xd0, (r, g), 0.0));
@NLparameter(cge, dd0_p[r in regions, g in goods] == get(dd0, (r, g), 0.0));
@NLparameter(cge, nd0_p[r in regions, g in goods] == get(nd0, (r, g), 0.0));
@NLparameter(cge, i0_p[r in regions, g in goods] == get(i0, (r, g), 0.0));

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

@NLparameter(
    cge,
    alpha_kl[r in regions, s in sectors] ==
    (value(ld0[r, s]) + value(kd0[r, s])) / value(ld0[r, s])
);
@NLparameter(
    cge,
    alpha_x[r in regions, g in goods] ==
    (value(x0[r, g]) - value(rx0[r, g])) / value(s0[r, g])
);
@NLparameter(cge, alpha_d[r in regions, g in goods] == value(xd0[r, g]) / value(s0[r, g]));
@NLparameter(cge, alpha_n[r in regions, g in goods] == value(xn0[r, g]) / value(s0[r, g]));
@NLparameter(
    cge,
    theta_n[r in regions, g in goods] ==
    value(nd0[r, g]) / (value(nd0[r, g]) - value(dd0[r, g]))
);
@NLparameter(
    cge,
    theta_m[r in regions, g in goods] ==
    value(tm0[r, g]) * value(m0[r, g]) /
    (value(nd0[r, g]) + value(dd0[r, g]) + (1 + value(tm0[r, g]) * value(m0[r, g])))
);

replace_nan_inf(alpha_kl)
replace_nan_inf(alpha_x)
replace_nan_inf(alpha_d)
replace_nan_inf(alpha_n)
replace_nan_inf(theta_n)
replace_nan_inf(theta_m)

##################
# -- VARIABLES -- 
##################

sv = 0.00

sub_set_rst =
    filter(x -> haskey(kd0, (x[1], x[2])), combvec(regions, sectors, years));
sub_set_rs = filter(x -> haskey(kd0, (x[1], x[2])), combvec(regions, sectors));
sub_set_py = filter(x -> y_check[x[1], x[2]] >= 0, combvec(regions, goods, years));
sub_set_pa = # change :a0 => :s0
    filter(x -> haskey(a0, (x[1], x[2])), combvec(regions, goods, years));
sub_set_pd =
    filter(x -> haskey(xd0, (x[1], x[2])), combvec(regions, goods, years));
sub_set_y = filter(x -> y_check[x[1], x[2]] != 0.0, combvec(regions, sectors, years));
sub_set_x = filter(x -> haskey(s0, (x[1], x[2])), combvec(regions, goods, years));
sub_set_a = filter(x -> a_set[x[1], x[2]] != 0.0, combvec(regions, goods, years));
#sectors
@variable(cge, Y[(r, s, t) in sub_set_y] >= sv, start = 1);
@variable(cge, X[(r, g, t) in sub_set_x] >= sv, start = 1);
@variable(cge, A[(r, g, t) in sub_set_a] >= sv, start = 1);
@variable(cge, C[r in regions, t in years] >= sv, start = 1);
@variable(cge, MS[r in regions, m in margins, t in years] >= sv, start = 1);
@variable(cge, K[(r, s, t) in sub_set_rst] >= sv, start = kd0[r, s]);
@variable(cge, I[(r, s, t) in sub_set_rst] >= sv, start = (delta * kd0[r, s]));

#commodities:
@variable(cge, PA[(r, g, t) in sub_set_pa] >= sv, start = pvm[t]); # Regional market (input)
@variable(cge,PY[r in regions, g in goods, t in years]>=sv,start=pvm[t]) 
# @variable(cge, PY[(r, g, t) in sub_set_py] >= sv, start = pvm[t]); # Regional market (output)
@variable(cge, PD[(r, g, t) in sub_set_pd] >= sv, start = pvm[t]); # Local market price
@variable(cge, PN[g in goods, t in years] >= sv, start = pvm[t]); # National market
@variable(cge, PL[r in regions, t in years] >= sv, start = pvm[t]); # Wage rate
@variable(cge, PK[(r, s, t) in sub_set_rst] >= sv, start = pvm[t] * (1 + i)); # Rental rate of capital ###
@variable(cge, RK[(r, s, t) in sub_set_rst] >= sv, start = pvm[t] * rk0); # Capital return rate ###
# @variable(cge, TK[(r, s) in sub_set_rs] >= sv, start = kd0[r, s]); ### Terminal capital amount
@variable(cge,TK[r in regions, s in sectors]>=sv,start=blueNOTE[:kd0][r,s])
@variable(cge, PKT[r in regions, s in sectors] >= sv, start = pvm[years_last]); # Terminal capital cost
@variable(cge, PM[r in regions, m in margins, t in years] >= sv, start = pvm[t]); # Margin price
@variable(cge, PC[r in regions, t in years] >= sv, start = pvm[t]); # Consumer price index #####
@variable(cge, PFX[t in years] >= sv, start = pvm[t]); # Foreign exchange
@variable(cge,RA[r in regions, t in years]>=sv,start = pvm[t] * blueNOTE[:c0][(r,)]) 

###############################
# -- PLACEHOLDER VARIABLES --
###############################

#cobb-douglas function for value added (VA) ######
@NLexpression(cge,CVA[r in regions,s in sectors,t in years],
  PL[r,t]^alpha_kl[r,s] * ((haskey(RK.lookup[1], (r, s, t)) ? RK[(r, s, t)] : 1.0) / rk0) ^ (1-alpha_kl[r,s]) );

#demand for labor in VA
@NLexpression(cge,AL[r in regions, s in sectors, t in years],
  ld0_p[r,s] * CVA[r,s,t] / PL[r,t] );

#demand for capital in VA ######
@NLexpression(cge,AK[r in regions,s in sectors, t in years],
  kd0_p[r,s] * CVA[r,s,t] / ((haskey(RK.lookup[1], (r, s, t)) ? RK[(r, s, t)] : 1.0) / rk0) );

###

#CES function for output demand - including
# exports (absent of re-exports) times the price for foreign exchange, 
# region's supply to national market times the national market price
# regional supply to local market times domestic price
@NLexpression(cge,RX[r in regions,g in goods, t in years],
  (alpha_x[r,g]*PFX[t]^5+alpha_n[r,g]*PN[g,t]^5+alpha_d[r,g]*(haskey(PD.lookup[1], (r, g, t)) ? PD[(r, g, t)] : 1.0)^5)^(1/5) );

#demand for exports via demand function
@NLexpression(cge,AX[r in regions,g in goods, t in years],
  (x0_p[r,g] - rx0_p[r,g])*(PFX[t]/RX[r,g,t])^4 );

#demand for contribution to national market 
@NLexpression(cge,AN[r in regions,g in goods, t in years],
  xn0_p[r,g]*(PN[g,t]/(RX[r,g,t]))^4 );

#demand for regionals supply to local market
@NLexpression(cge,AD[r in regions,g in goods, t in years],
  xd0_p[r,g] * ((haskey(PD.lookup[1], (r, g, t)) ? PD[(r, g, t)] : 1.0) / (RX[r,g,t]))^4 );

  ###

# CES function for tradeoff between national and domestic market
@NLexpression(cge,CDN[r in regions,g in goods, t in years],
  (theta_n[r,g]*PN[g,t]^(1-2)+(1-theta_n[r,g])*(haskey(PD.lookup[1], (r, g, t)) ? PD[(r, g, t)] : 1.0)^(1-2))^(1/(1-2)) );

# CES function for tradeoff between domestic consumption and foreign exports
# recall tm in the import tariff thus tm / tm0 is the relative change in import tariff rates
@NLexpression(cge,CDM[r in regions,g in goods, t in years],
  ((1-theta_m[r,g])*CDN[r,g,t]^(1-4)+theta_m[r,g]*
  (PFX[t]*(1+tm_p[r,g])/(1+tm0_p[r,g]))^(1-4))^(1/(1-4)) 
  );

  ###

# regions demand from the national market <- note nesting of CDN in CDM
@NLexpression(cge,DN[r in regions,g in goods, t in years],
  nd0_p[r,g]*(CDN[r,g,t]/PN[g,t])^2*(CDM[r,g,t]/CDN[r,g,t])^4 );

# region demand from local market <- note nesting of CDN in CDM
@NLexpression(cge,DD[r in regions,g in goods, t in years],
  dd0_p[r,g]*(CDN[r,g,t]/(haskey(PD.lookup[1], (r, g, t)) ? PD[(r, g, t)] : 1.0))^2*(CDM[r,g,t]/CDN[r,g,t])^4 );

# import demand
@NLexpression(cge,MD[r in regions,g in goods, t in years],
  m0_p[r,g]*(CDM[r,g,t]*(1+tm_p[r,g])/(PFX[t]*(1+tm0_p[r,g])))^4 );

# final demand
@NLexpression(cge,CD[r in regions,g in goods, t in years],
  cd0_p[r,g]*PC[r,t] / (haskey(PA.lookup[1], (r, g, t)) ? PA[(r, g, t)] : 1.0) );


###############################
# -- Zero Profit Conditions --
###############################

@mapping(cge,profit_y[(r, s, t) in sub_set_y],
# cost of intermediate demand
        sum((haskey(PA.lookup[1], (r, g, t)) ? PA[(r, g, t)] : 1.0) * id0_p[r,g,s] for g in goods) 
# cost of labor inputs
        + PL[r,t] * AL[r,s,t]
# cost of capital inputs 
        + ((haskey(RK.lookup[1], (r, s, t)) ? RK[(r, s, t)] : 1.0) / rk0) * AK[r,s,t]
        - 
# revenue from sectoral supply (take note of r/s/g indices on ys0)                
        sum(PY[r, g, t]  * ys0_p[r,s,g] for g in goods) * (1-ty_p[r,s])
);

@mapping(cge,profit_x[(r, g, t) in sub_set_x],
# output 'cost' from aggregate supply
         PY[r, g, t] * s0_p[r,g] 
        - (
# revenues from foreign exchange
        PFX[t] * AX[r,g,t]
# revenues from national market                  
        + PN[g,t] * AN[r,g,t]
# revenues from domestic market
        + (haskey(PD.lookup[1], (r, g, t)) ? PD[(r, g, t)] : 1.0) * AD[r,g,t]
        )
);


@mapping(cge,profit_a[(r, g, t) in sub_set_a],
# costs from national market
        PN[g,t] * DN[r,g,t] 
# costs from domestic market                  
        + (haskey(PD.lookup[1], (r, g, t)) ? PD[(r, g, t)] : 1.0) * DD[r,g,t] 
# costs from imports, including import tariff
        + PFX[t] * (1+tm_p[r,g]) * MD[r,g,t]
# costs of margin demand                
        + sum(PM[r,m,t] * md0_p[r,m,g] for m in margins)
        - ( 
# revenues from regional market based on armington supply               
        (haskey(PA.lookup[1], (r, g, t)) ? PA[(r, g, t)] : 1.0) * (1-ta_p[r,g]) * a0_p[r,g] 
# revenues from re-exports                   
        + PFX[t] * rx0_p[r,g]
        )
);

@mapping(cge,profit_c[r in regions, t in years],
# costs of inputs - computed as final demand times regional market prices
        sum((haskey(PA.lookup[1], (r, g, t)) ? PA[(r, g, t)] : 1.0) * CD[r,g,t] for g in goods)
        - 
# revenues/benefit computed as CPI * reference consumption                  
        PC[r,t] * c0_p[r]
);

#!!! might need to switch signs here...
@mapping(cge,profit_k[(r, s, t) in sub_set_rst],
        (haskey(PK.lookup[1], (r, s, t)) ? PK[(r, s, t)] : 1.0) 
        - (
        (haskey(RK.lookup[1], (r, s, t)) ? RK[(r, s, t)] : 1.0)
        + (1-delta) * (t!=years_last ? (haskey(PK.lookup[1], (r, s, t+1)) ? PK[(r, s, t+1)] : 1.0) : PKT[r,s])
        )
);

@mapping(cge,profit_i[(r, s, t) in sub_set_rst],
         PY[r, s, t] 
        - 
        (t!=years_last ? (haskey(PK.lookup[1], (r, s, t+1)) ? PK[(r, s, t+1)] : 1.0) : PKT[r,s])
);

@mapping(cge,profit_ms[r in regions, m in margins, t in years],
# provision of margins to national market
        sum(PN[gm,t]   * nm0_p[r,gm,m] for gm in goods_margins)
# provision of margins to domestic market    
        + sum((haskey(PD.lookup[1], (r, gm, t)) ? PD[(r, gm, t)] : 1.0) * dm0_p[r,gm,m] for gm in goods_margins)
        - 
# total margin demand    
        PM[r,m,t] * sum(md0_p[r,m,gm] for gm in goods_margins)
);


###################################
# -- Market Clearing Conditions -- 
###################################

@mapping(cge,market_pa[(r, g, t) in sub_set_pa],
# absorption or supply
        (haskey(A.lookup[1], (r, g, t)) ? A[(r, g, t)] : 1.) * a0_p[r,g] 
        - ( 
# government demand (exogenous)       
        g0_p[r,g] 
# demand for investment (exogenous)
        + i0_p[r,g]
# final demand        
        + C[r,t] * CD[r,g,t]
# intermediate demand        
        + sum((haskey(Y.lookup[1], (r, s, t)) ? Y[(r, s, t)] : 1) * id0_p[r,g,s] for s in sectors if (y_check[r,s] > 0))
        )
);

@mapping(cge,market_py[r in regions, g in goods, t in years],
# sectoral supply
        sum((haskey(Y.lookup[1], (r, s, t)) ? Y[(r, s, t)] : 1) *ys0_p[r,s,g] for s in sectors)
# household production (exogenous)        
        + yh0_p[r,g]
        - 
# aggregate supply (akin to market demand)                
       (haskey(X.lookup[1], (r, g, t)) ? X[(r, g, t)] : 1) * s0_p[r,g]
);


@mapping(cge,market_pd[(r, g, t) in sub_set_pd],
# aggregate supply
        (haskey(X.lookup[1], (r, g, t)) ? X[(r, g, t)] : 1)  * AD[r,g,t] 
        - ( 
# demand for local market          
        (haskey(A.lookup[1], (r, g, t)) ? A[(r, g, t)] : 1.) * DD[r,g,t]
# margin supply from local market
        + sum(MS[r,m,t] * dm0_p[r,g,m] for m in margins if (g in goods_margins ) )  
        )
);

@mapping(cge,market_pn[g in goods, t in years],
# supply to the national market
        sum((haskey(X.lookup[1], (r, g, t)) ? X[(r, g, t)] : 1)  * AN[r,g,t] for r in regions)
        - ( 
# demand from the national market 
        sum((haskey(A.lookup[1], (r, g, t)) ? A[(r, g, t)] : 1.) * DN[r,g,t] for r in regions)
# market supply to the national market        
        + sum(MS[r,m,t] * nm0_p[r,g,m] for r in regions for m in margins if (g in goods_margins) )
        )
);

@mapping(cge,market_pl[r in regions, t in years],
# supply of labor
        sum(ld0_p[r,s] for s in sectors)
        - 
# demand for labor in all sectors        
        sum((haskey(Y.lookup[1], (r, s, t)) ? Y[(r, s, t)] : 1) * AL[r,s,t] for s in sectors)
);

@mapping(cge,market_pk[(r, s, t) in sub_set_rst],
# if first year, initial capital
# else investment plus previous year's decayed capital
        (t==mod_year ? kd0_p[r,s] : (haskey(I.lookup[1], (r, s, t - 1)) ? I[(r, s, t - 1)] : 0.))
        + (1-delta) * (t>mod_year ? (haskey(K.lookup[1], (r, s, t)) ? K[(r, s, t)] : 0.) : 0)
        - 
#current year's capital capital        
       (haskey(K.lookup[1], (r, s, t)) ? K[(r, s, t)] : 0.)
);

@mapping(cge,market_rk[(r, s, t) in sub_set_rst],
        (haskey(K.lookup[1], (r, s, t)) ? K[(r, s, t)] : 0.)
        -
        (haskey(Y.lookup[1], (r, s, t)) ? Y[(r, s, t)] : 1) * kd0_p[r,s] * CVA[r,s,t] / ((haskey(RK.lookup[1], (r, s, t)) ? RK[(r, s, t)] : 1.0) / rk0)
);

#terminal investment constraint
@mapping(cge,market_pkt[r in regions, s in sectors],
        (1-delta) * (haskey(K.lookup[1], (r, s, years_last)) ? K[(r, s, years_last)] : 0.)
        + (haskey(I.lookup[1], (r, s, years_last)) ? I[(r, s, years_last)] : 0) 
        - 
        TK[r, s]
);

@mapping(cge,termk[r in regions, s in sectors],
        (haskey(I.lookup[1], (r, s, years_last)) ? I[(r, s, years_last)] : 0) / ((haskey(I.lookup[1], (r, s, years_last-1)) ? I[(r, s, years_last-1)] : 0) + (kd0_p[r,s]==0 && + 1e-6))
        - 
        (haskey(Y.lookup[1], (r, s, years_last)) ? Y[(r, s, years_last)] : 1) 
        / (haskey(Y.lookup[1], (r, s, years_last-1)) ? Y[(r, s, years_last-1)] : 1)
);

@mapping(cge,market_pm[r in regions, m in margins, t in years],
# margin supply 
        MS[r,m,t] * sum(md0_p[r,m,gm] for gm in goods_margins)
        - 
# margin demand        
        sum((haskey(A.lookup[1], (r, g, t)) ? A[(r, g, t)] : 1.) * md0_p[r,m,g] for g in goods)
);

@mapping(cge,market_pfx[t in years],
# balance of payments (exogenous)
        sum(bopdef0_p[r] for r in regions)
# supply of exports     
        + sum((haskey(X.lookup[1], (r, g, t)) ? X[(r, g, t)] : 1)  * AX[r,g,t] for r in regions for g in goods)
# supply of re-exports        
        + sum((haskey(A.lookup[1], (r, g, t)) ? A[(r, g, t)] : 1.) * rx0_p[r,g] for r in regions for g in goods if (a_set[r,g] != 0))
        - 
# import demand                
        sum((haskey(A.lookup[1], (r, g, t)) ? A[(r, g, t)] : 1.) * MD[r,g,t] for r in regions for g in goods if (a_set[r,g] != 0))
);

#######
@mapping(cge,market_pc[r in regions, t in years],
# a period's final demand
        C[r,t] * c0_p[r]
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
        PL[r,t] * sum(ld0_p[r,s] for s in sectors)
# provision of household supply          
        + sum( PY[r, g, t] *yh0_p[r,g] for g in goods)
# revenue or costs of foreign exchange including household adjustment   
        + PFX[t] * (bopdef0_p[r] + hhadj_p[r])
# government and investment provision        
        - sum((haskey(PA.lookup[1], (r, g, t)) ? PA[(r, g, t)] : 1.0) * (g0_p[r,g] + i0_p[r,g]) for g in goods)
# import taxes - assumes lumpsum recycling
        + sum((haskey(A.lookup[1], (r, g, t)) ? A[(r, g, t)] : 1.) * MD[r,g,t]* PFX[t] * tm_p[r,g] for g in goods if (a_set[r,g] != 0))
# taxes on intermediate demand - assumes lumpsum recycling
        + sum((haskey(A.lookup[1], (r, g, t)) ? A[(r, g, t)] : 1.) * a0_p[r,g]*(haskey(PA.lookup[1], (r, g, t)) ? PA[(r, g, t)] : 1.0)*ta_p[r,g] for g in goods if (a_set[r,g] != 0) )
# production taxes - assumes lumpsum recycling  
        + sum(pvm[t] * (haskey(Y.lookup[1], (r, s, t)) ? Y[(r, s, t)] : 1) * ys0_p[r,s,g] * ty_p[r,s] for s in sectors for g in goods)
# income from capital
        + (1-bool_lastyear[t]) * sum((haskey(PK.lookup[1], (r, s, t)) ? PK[(r, s, t)] : 1.0) * (haskey(K.lookup[1], (r, s, t)) ? K[(r, s, t)] : 0.) for s in sectors) / (1+i)
#cost of terminal year investment
        + bool_lastyear[t] * sum(PKT[r,s] * TK[r, s] for s in sectors)
        )
);


####################################
# -- Complementarity Conditions --
####################################

# For some reason I still need this 
[fix(PY[r,g,t],1,force=true) for r in regions for g in goods for t in years if !(y_check[r,g]>0)]


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


# f = open("state_model.lp", "w")
# print(f, cge)
# close(f)
