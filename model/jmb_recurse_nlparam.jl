
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

function df_to_dict(::Type{Dict}, df::DataFrame; drop_cols = [], value_col::Symbol = :Float)
        # Find and save the column containing values and that/those containing keys.
        # If no value column indicator is specified, find the first DataFrame column of floats.
        value_col == :Float && (value_col = find_oftype(df, AbstractFloat)[1])
        key_cols = setdiff(propertynames(df), convert_type.(Symbol, ensurearray(drop_cols)), [value_col])
    
        d = Dict((row[key_cols]...,) => row[value_col]
            for row in eachrow(df))
        return d
end


function combvec(set_a...)
    return vec(collect(Iterators.product(set_a...)))
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
    :ys0 => df_to_dict(Dict, read_data_temp("ys0",mod_year,data_temp_dir,"Sectoral supply"); drop_cols = [:yr], value_col = :Val),
    :id0 => df_to_dict(Dict, read_data_temp("id0",mod_year,data_temp_dir,"Intermediate demand"); drop_cols = [:yr], value_col = :Val),
    :ld0 => df_to_dict(Dict, read_data_temp("ld0",mod_year,data_temp_dir,"Labor demand"); drop_cols = [:yr], value_col = :Val),
    :kd0 => df_to_dict(Dict, read_data_temp("kd0",mod_year,data_temp_dir,"Capital demand"); drop_cols = [:yr], value_col = :Val),
    :ty0 => df_to_dict(Dict, read_data_temp("ty0",mod_year,data_temp_dir,"Production tax"); drop_cols = [:yr], value_col = :Val),
    :m0 => df_to_dict(Dict, read_data_temp("m0",mod_year,data_temp_dir,"Imports"); drop_cols = [:yr], value_col = :Val),
    :x0 => df_to_dict(Dict, read_data_temp("x0",mod_year,data_temp_dir,"Exports of goods and services"); drop_cols = [:yr], value_col = :Val),
    :rx0 => df_to_dict(Dict, read_data_temp("rx0",mod_year,data_temp_dir,"Re-exports of goods and services"); drop_cols = [:yr], value_col = :Val),
    :md0 => df_to_dict(Dict, read_data_temp("md0",mod_year,data_temp_dir,"Total margin demand"); drop_cols = [:yr], value_col = :Val),
    :nm0 => df_to_dict(Dict, read_data_temp("nm0",mod_year,data_temp_dir,"Margin demand from national market"); drop_cols = [:yr], value_col = :Val),
    :dm0 => df_to_dict(Dict, read_data_temp("dm0",mod_year,data_temp_dir,"Margin supply from local market"); drop_cols = [:yr], value_col = :Val),
    :s0 => df_to_dict(Dict, read_data_temp("s0",mod_year,data_temp_dir,"Aggregate supply"); drop_cols = [:yr], value_col = :Val),
    :a0 => df_to_dict(Dict, read_data_temp("a0",mod_year,data_temp_dir,"Armington supply"); drop_cols = [:yr], value_col = :Val),
    :ta0 => df_to_dict(Dict, read_data_temp("ta0",mod_year,data_temp_dir,"Tax net subsidy rate on intermediate demand"); drop_cols = [:yr], value_col = :Val),
    :tm0 => df_to_dict(Dict, read_data_temp("tm0",mod_year,data_temp_dir,"Import tariff"); drop_cols = [:yr], value_col = :Val),
    :cd0 => df_to_dict(Dict, read_data_temp("cd0",mod_year,data_temp_dir,"Final demand"); drop_cols = [:yr], value_col = :Val),
    :c0 => df_to_dict(Dict, read_data_temp("c0",mod_year,data_temp_dir,"Aggregate final demand"); drop_cols = [:yr], value_col = :Val),
    :yh0 => df_to_dict(Dict, read_data_temp("yh0",mod_year,data_temp_dir,"Household production"); drop_cols = [:yr], value_col = :Val),
    :bopdef0 => df_to_dict(Dict, read_data_temp("bopdef0",mod_year,data_temp_dir,"Balance of payments"); drop_cols = [:yr], value_col = :Val),
    :hhadj => df_to_dict(Dict, read_data_temp("hhadj",mod_year,data_temp_dir,"Household adjustment"); drop_cols = [:yr], value_col = :Val),
    :g0 => df_to_dict(Dict, read_data_temp("g0",mod_year,data_temp_dir,"Government demand"); drop_cols = [:yr], value_col = :Val),
    :i0 => df_to_dict(Dict, read_data_temp("i0",mod_year,data_temp_dir,"Investment demand"); drop_cols = [:yr], value_col = :Val),
    :xn0 => df_to_dict(Dict, read_data_temp("xn0",mod_year,data_temp_dir,"Regional supply to national market"); drop_cols = [:yr], value_col = :Val),
    :xd0 => df_to_dict(Dict, read_data_temp("xd0",mod_year,data_temp_dir,"Regional supply to local market"); drop_cols = [:yr], value_col = :Val),
    :dd0 => df_to_dict(Dict, read_data_temp("dd0",mod_year,data_temp_dir,"Regional demand from local  market"); drop_cols = [:yr], value_col = :Val),
    :nd0 => df_to_dict(Dict, read_data_temp("nd0",mod_year,data_temp_dir,"Regional demand from national market"); drop_cols = [:yr], value_col = :Val)
)


## Creating copy without zeros
ys0 = deepcopy(blueNOTE[:ys0])
id0 = deepcopy(blueNOTE[:id0])
ld0 = deepcopy(blueNOTE[:ld0])
kd0 = deepcopy(blueNOTE[:kd0])
ty0 = deepcopy(blueNOTE[:ty0])
m0 = deepcopy(blueNOTE[:m0])
x0 = deepcopy(blueNOTE[:x0])
rx0 = deepcopy(blueNOTE[:rx0])
md0 = deepcopy(blueNOTE[:md0])
nm0 = deepcopy(blueNOTE[:nm0])
dm0 = deepcopy(blueNOTE[:dm0])
s0 = deepcopy(blueNOTE[:s0])
a0 = deepcopy(blueNOTE[:a0])
ta0 =deepcopy( blueNOTE[:ta0])
tm0 = deepcopy(blueNOTE[:tm0])
cd0 = deepcopy(blueNOTE[:cd0])
c0 = deepcopy(blueNOTE[:c0])
yh0 = deepcopy(blueNOTE[:yh0])
bopdef0 = deepcopy(blueNOTE[:bopdef0])
hhadj = deepcopy(blueNOTE[:hhadj])
g0 = deepcopy(blueNOTE[:g0])
i0 = deepcopy(blueNOTE[:i0])
xn0 = deepcopy(blueNOTE[:xn0])
xd0 = deepcopy(blueNOTE[:xd0])
dd0 = deepcopy(blueNOTE[:dd0])
nd0 = deepcopy(blueNOTE[:nd0])
tm = deepcopy(tm0)
ta = deepcopy(ta0)
ty = deepcopy(ty0)

###############
# -- SETS --
###############

# read sets from their dumped CSVs
# these are converted to a vector of strings such that we can use them to populate variable indices
# and to use them as as conditionals (e.g. see the use of goods_margins)
#regions = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_r.csv"),descriptor="region set"))[!,:Dim1]);
#sectors = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_s.csv"),descriptor="sector set"))[!,:Dim1]);
#goods = sectors;
#margins = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_m.csv"),descriptor="margin set"))[!,:Dim1]);
#goods_margins = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_gm.csv"),descriptor="goods with margins set"))[!,:g]);

regions = convert(Vector{String},CSV.read(string(data_temp_dir,"/set_r.csv"))[!,:Dim1])
sectors = convert(Vector{String},CSV.read(string(data_temp_dir,"/set_s.csv"))[!,:Dim1])
goods = sectors;
margins = convert(Vector{String},CSV.read(string(data_temp_dir,"/set_m.csv"))[!,:Dim1])
goods_margins = convert(Vector{String},CSV.read(string(data_temp_dir,"/set_gm.csv"))[!,:g])

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
# the a_set restricits the A variables indices to those
# with positive armington supply or re-exports
a_set = Dict()
[a_set[r,g] = blueNOTE[:a0][r,g] + blueNOTE[:rx0][r,g] for r in regions for g in goods]

# y_check is used to make sure the r/s combination 
# has a reference amount of sectoral supply
y_check = Dict()
[y_check[r,s] = sum(blueNOTE[:ys0][r,s,g] for g in goods) for r in regions for s in sectors]

########## Model ##########
cge = MCPModel();

##############
# PARAMETERS
##############
@NLparameter(cge, ys0_p[r in regions, s in sectors, g in goods] == get(ys0, (r, s, g), 0.0));
@NLparameter(cge, id0_p[r in regions, s in sectors, g in goods] == get(id0, (r, s, g), 0.0));
@NLparameter(cge, ld0_p[r in regions, s in sectors] == get(ld0, (r, s), 0.0));
@NLparameter(cge, kd0_p[r in regions, s in sectors] == get(kd0, (r, s), 0.0));
@NLparameter(cge, ty0_p[r in regions, s in sectors] == get(ty0, (r, s), 0.0));
@NLparameter(cge, ty_p[r in regions, s in sectors] == get(ty, (r, s), 0.0));
@NLparameter(cge, m0_p[r in regions, g in goods] == get(m0, (r, g), 0.0));
@NLparameter(cge, x0_p[r in regions, g in goods] == get(x0, (r, g), 0.0));
@NLparameter(cge, rx0_p[r in regions, g in goods] == get(rx0, (r, g), 0.0));
@NLparameter(cge, md0_p[r in regions, m in margins, g in goods] == get(md0, (r, m, g), 0.0));
@NLparameter(cge, nm0_p[r in regions, g in goods, m in margins] == get(nm0, (r, g, m), 0.0));
@NLparameter(cge, dm0_p[r in regions, g in goods, m in margins] == get(dm0, (r, g, m), 0.0));
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


#--- Recursive Dynamic Setup ---
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

@NLparameter(cge, rho == 0.05); # interest rate
@NLparameter(cge, eta == 0.02); # growth rate --- try sector and regions specific
@NLparameter(cge, delta == 0.07); # capital depreciation rate
@NLparameter(cge, thetax == 0.75); # extant production share
@NLparameter(cge, beta[t in years] == (1/(1 + value(rho)))^(t-mod_year)); #discount factor or present value multiplier

#new capital endowment
@NLparameter(cge, ks_n[r in regions, s in sectors] ==
             value(kd0_p[r, s])  * (value(delta)+value(eta)) / (1 + value(eta)) );


# mutable old capital endowment
@NLparameter(cge, ks_s[r in regions, s in sectors] ==
             value(kd0_p[r, s]) * (1 - value(thetax)) - value(ks_n[r,s]) );


# Extant capital endowment
@NLparameter(cge, ks_x[r in regions, s in sectors] ==
             value(kd0_p[r, s]) * value(thetax) );

# Labor endowment
@NLparameter(cge, le0[r in regions, s in sectors] == value(ld0_p[r,s]));




# --- end recursive dynamic preproc ---

@NLparameter(cge, alpha_kl[r in regions, s in sectors] == value(ld0_p[r, s]) / (value(ld0_p[r, s]) + value(kd0_p[r, s])));
@NLparameter(cge, alpha_x[r in regions, g in goods] == (value(x0_p[r, g]) - value(rx0_p[r, g])) / value(s0_p[r, g]));
@NLparameter(cge, alpha_d[r in regions, g in goods] == value(xd0_p[r, g]) / value(s0_p[r, g]));
@NLparameter(cge, alpha_n[r in regions, g in goods] == value(xn0_p[r, g]) / value(s0_p[r, g]));
@NLparameter(cge, theta_n[r in regions, g in goods] == value(nd0_p[r, g]) / (value(nd0_p[r, g]) + value(dd0_p[r, g])));
@NLparameter(cge, theta_m[r in regions, g in goods] == (1+value(tm0_p[r, g])) * value(m0_p[r, g])
             / (value(nd0_p[r, g]) + value(dd0_p[r, g]) + (1 + value(tm0_p[r, g])) * value(m0_p[r, g])));

replace_nan_inf(alpha_kl)
replace_nan_inf(alpha_x)
replace_nan_inf(alpha_d)
replace_nan_inf(alpha_n)
replace_nan_inf(theta_n)
replace_nan_inf(theta_m)


################
# VARIABLES
################

sv = 0.001
sub_set_y = filter(x -> y_check[x] != 0.0, combvec(regions, sectors));
sub_set_x = filter(x -> haskey(s0, x), combvec(regions, goods));
sub_set_a = filter(x -> a_set[x[1], x[2]] != 0.0, combvec(regions, goods));
sub_set_pa = 
    filter(x -> haskey(a0, (x[1], x[2])), combvec(regions, goods));
sub_set_pd =
    filter(x -> haskey(xd0, (x[1], x[2])), combvec(regions, goods));
sub_set_pk =
    filter(x -> haskey(kd0, (x[1], x[2])), combvec(regions, sectors));
sub_set_py = filter(x -> y_check[x[1], x[2]] >= 0, combvec(regions, goods));

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
@variable(cge,RA[r in regions]>=sv,start = blueNOTE[:c0][(r,)]) ;


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
              ld0_p[r,s] * CVAym[r,s] / PL[r]
              );

#demand for capital in VA
@NLexpression(cge,AKym[r in regions,s in sectors],
              kd0_p[r,s] * CVAym[r,s] / (haskey(RK.lookup[1], (r, s)) ? RK[(r,s)] : 1.0)
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
@NLexpression(cge,AX[r in regions,g in goods], (x0_p[r,g] - rx0_p[r,g])*(PFX/RX[r,g])^4 );

#demand for contribution to national market 
@NLexpression(cge,AN[r in regions,g in goods], xn0_p[r,g]*(PN[g]/(RX[r,g]))^4 );

#demand for regionals supply to local market
@NLexpression(cge,AD[r in regions,g in goods],
  xd0_p[r,g] * ((haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0) / (RX[r,g]))^4 );

  ###

# CES function for tradeoff between national and domestic market
@NLexpression(cge,CDN[r in regions,g in goods],
  (theta_n[r,g]*PN[g]^(1-2)+(1-theta_n[r,g])*(haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0)^(1-2))^(1/(1-2)) );

# CES function for tradeoff between domestic consumption and foreign exports
# recall tm in the import tariff thus tm / tm0 is the relative change in import tariff rates
@NLexpression(cge,CDM[r in regions,g in goods],
  ((1-theta_m[r,g])*CDN[r,g]^(1-4)+theta_m[r,g]*(PFX*(1+tm_p[r,g])/(1+tm0_p[r,g]))^(1-4))^(1/(1-4)) );

# regions demand from the national market <- note nesting of CDN in CDM
@NLexpression(cge,DN[r in regions,g in goods],
  nd0_p[r,g]*(CDN[r,g]/PN[g])^2*(CDM[r,g]/CDN[r,g])^4 );

# region demand from local market <- note nesting of CDN in CDM
@NLexpression(cge,DD[r in regions,g in goods],
  dd0_p[r,g]*(CDN[r,g]/(haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0))^2*(CDM[r,g]/CDN[r,g])^4 );

# import demand
@NLexpression(cge,MD[r in regions,g in goods],
  m0_p[r,g]*(CDM[r,g]*(1+tm_p[r,g])/(PFX*(1+tm0_p[r,g])))^4 );

# final demand
@NLexpression(cge,CD[r in regions,g in goods],
  cd0_p[r,g]*PC[r] / (haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) );


###############################
# -- Zero Profit Conditions --
###############################

#----------
#Recursive  --- update to Y
@mapping(cge,profit_ym[(r, s) in sub_set_y],
# cost of intermediate demand
        sum((haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * id0_p[r,g,s] for g in goods) 
# cost of labor inputs
        + PL[r] * ALym[r,s]
# cost of capital inputs 
        + (haskey(RK.lookup[1], (r, s)) ? RK[(r,s)] : 1.0) * AKym[r,s]
        - 
# revenue from sectoral supply (take note of r/s/g indices on ys0)                
        sum((haskey(PY.lookup[1], (r, g)) ? PY[(r, g)] : 1.0)  * ys0_p[r,s,g] for g in goods) * (1-ty_p[r,s])
);

@mapping(cge,profit_yx[(r, s) in sub_set_y],
# cost of intermediate demand
        sum((haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * id0_p[r,g,s] for g in goods) 
# cost of labor inputs
        + PL[r] * ld0_p[r,s]
# cost of capital inputs 
        + (haskey(RKX.lookup[1], (r, s)) ? RKX[(r,s)] : 1.0) * kd0_p[r,s]
        - 
# revenue from sectoral supply (take note of r/s/g indices on ys0)                
        sum((haskey(PY.lookup[1], (r, g)) ? PY[(r, g)] : 1.0)  * ys0_p[r,s,g] for g in goods) * (1-ty_p[r,s])
);

#----------

# @mapping(cge,profit_y[(r, s) in sub_set_y],
# # cost of intermediate demand
#         sum((haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * id0_p[r,g,s] for g in goods) 
# # cost of labor inputs
#         + PL[r] * AL[r,s]
# # cost of capital inputs 
#         + (haskey(PK.lookup[1], (r, s)) ? PK[(r, s)] : 1.0)* AK[r,s]
#         - 
# # revenue from sectoral supply (take note of r/s/g indices on ys0)                
#         sum((haskey(PY.lookup[1], (r, g)) ? PY[(r, g)] : 1.0)  * ys0_p[r,s,g] for g in goods) * (1-ty_p[r,s])
# );



@mapping(cge,profit_x[(r, g) in sub_set_x],
# output 'cost' from aggregate supply
         (haskey(PY.lookup[1], (r, g)) ? PY[(r, g)] : 1.0) * s0_p[r,g] 
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
        + PFX * (1+tm_p[r,g]) * MD[r,g]
# costs of margin demand                
        + sum(PM[r,m] * md0_p[r,m,g] for m in margins)
        - ( 
# revenues from regional market based on armington supply               
        (haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * (1-ta_p[r,g]) * a0_p[r,g] 
# revenues from re-exports                   
        + PFX * rx0_p[r,g]
        )
);

@mapping(cge, profit_c[r in regions],
# costs of inputs - computed as final demand times regional market prices
        sum((haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * CD[r,g] for g in goods)
        - 
# revenues/benefit computed as CPI * reference consumption                  
        PC[r] * c0_p[r]
);


@mapping(cge,profit_ms[r in regions, m in margins],
# provision of margins to national market
        sum(PN[gm]   * nm0_p[r,gm,m] for gm in goods_margins)
# provision of margins to domestic market    
        + sum((haskey(PD.lookup[1], (r, gm)) ? PD[(r, gm)] : 1.0) * dm0_p[r,gm,m] for gm in goods_margins)
        - 
# total margin demand    
        PM[r,m] * sum(md0_p[r,m,gm] for gm in goods_margins)
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
       (haskey(YX.lookup[1], (r, s)) ? YX[(r, s)] : 1.) * kd0_p[r,s]
);
         

@mapping(cge,market_pa[(r, g) in sub_set_pa],
# absorption or supply
        (haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.) * a0_p[r,g] 
        - ( 
# government demand (exogenous)       
        g0_p[r,g] 
# demand for investment (exogenous)
        + i0_p[r,g]
# final demand        
        + C[r] * CD[r,g]
# intermediate demand        
#            + sum((haskey(Y.lookup[1], (r, s)) ? Y[(r, s)] : 1) * id0_p[r,g,s] for s in sectors if (y_check[r,s] > 0))
            + sum((haskey(YM.lookup[1], (r, s)) ? YM[(r, s)] : 1) * id0_p[r,g,s] for s in sectors if (y_check[r,s] > 0))
            + sum((haskey(YX.lookup[1], (r, s)) ? YX[(r, s)] : 1) * id0_p[r,g,s] for s in sectors if (y_check[r,s] > 0))
        )
);

@mapping(cge,market_py[(r, g) in sub_set_py],
# sectoral supply
#        sum((haskey(Y.lookup[1], (r, s)) ? Y[(r, s)] : 1) *ys0_p[r,s,g] for s in sectors)
         sum((haskey(YM.lookup[1], (r, s)) ? YM[(r, s)] : 1) *ys0_p[r,s,g] for s in sectors)
         + sum((haskey(YX.lookup[1], (r, s)) ? YX[(r, s)] : 1) *ys0_p[r,s,g] for s in sectors)
# household production (exogenous)        
        + yh0_p[r,g]
        - 
# aggregate supply (akin to market demand)                
       (haskey(X.lookup[1], (r, g)) ? X[(r, g)] : 1) * s0_p[r,g]
);

@mapping(cge,market_pl[r in regions],
# supply of labor
        sum(ld0_p[r,s] for s in sectors)
        - 
# demand for labor in all sectors        
#        sum((haskey(Y.lookup[1], (r, s)) ? Y[(r, s)] : 1) * AL[r,s] for s in sectors)
        ( 
                sum((haskey(YM.lookup[1], (r, s)) ? YM[(r, s)] : 1) * ALym[r,s] for s in sectors)
                + sum((haskey(YX.lookup[1], (r, s)) ? YX[(r, s)] : 1) * ld0_p[r,s] for s in sectors)
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
        + sum(MS[r,m] * dm0_p[r,g,m] for m in margins if (g in goods_margins ) )  
        )
);

@mapping(cge,market_pn[g in goods],
# supply to the national market
        sum((haskey(X.lookup[1], (r, g)) ? X[(r, g)] : 1)  * AN[r,g] for r in regions)
        - ( 
# demand from the national market 
        sum((haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.) * DN[r,g] for r in regions)
# market supply to the national market        
        + sum(MS[r,m] * nm0_p[r,g,m] for r in regions for m in margins if (g in goods_margins) )
        )
);


@mapping(cge,market_pm[r in regions, m in margins],
# margin supply 
        MS[r,m] * sum(md0_p[r,m,gm] for gm in goods_margins)
        - 
# margin demand        
        sum((haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.0) * md0_p[r,m,g] for g in goods)
);

@mapping(cge,market_pc[r in regions],
# a period's final demand
        C[r] * c0_p[r]
        - 
# consumption / utiltiy        
        RA[r] / PC[r]
);


@mapping(cge,market_pfx,
# balance of payments (exogenous)
        sum(bopdef0_p[r] for r in regions)
# supply of exports     
        + sum((haskey(X.lookup[1], (r, g)) ? X[(r, g)] : 1.0)  * AX[r,g] for r in regions for g in goods)
# supply of re-exports        
        + sum((haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.0) * rx0_p[r,g] for r in regions for g in goods if (a_set[r,g] != 0))
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
        #+ sum((haskey(PK.lookup[1], (r, s)) ? PK[(r,s)] : 1.0) * kd0_p[r,s] for s in sectors)
# provision of household supply          
        + sum( (haskey(PY.lookup[1], (r, g)) ? PY[(r, g)] : 1.0) * yh0_p[r,g] for g in goods)
# revenue or costs of foreign exchange including household adjustment   
        + PFX * (bopdef0_p[r] + hhadj_p[r])
# government and investment provision        
        - sum((haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * (g0_p[r,g] + i0_p[r,g]) for g in goods)
# import taxes - assumes lumpsum recycling
        + sum((haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.) * MD[r,g] * PFX * tm_p[r,g] for g in goods if (a_set[r,g] != 0))
# taxes on intermediate demand - assumes lumpsum recycling
        + sum((haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.) * a0_p[r,g]*(haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0)*ta_p[r,g] for g in goods if (a_set[r,g] != 0) )
# production taxes - assumes lumpsum recycling  
            + sum( (haskey(YM.lookup[1], (r, s)) ? YM[(r, s)] : 1) * ys0_p[r,s,g] * ty_p[r,s] for s in sectors, g in goods)
            + sum( (haskey(YX.lookup[1], (r, s)) ? YX[(r, s)] : 1) * ys0_p[r,s,g] * ty_p[r,s] for s in sectors, g in goods)
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


#Save for later when making investment better
#scale(r,s,t) = (1-delta)*(ks_n(r,s,"%bmkyr%")+ks_s(r,s,"%bmkyr%")+ks_x(r,s,"%bmkyr%")) / (i0(r,s)*(rho+delta));
#ks_n(r,s,t) = scale(r,s,t)*i0(r,s))*I.l(r,s)*(rho+delta);
#total_cap = ks_n+ks_s+ks_x

total_cap = Dict()
[total_cap[r,s]=value(ks_n[r,s])+value(ks_s[r,s])+value(ks_x[r,s]) for r in regions, s in sectors]

scalecap=Dict()
[scalecap[r,s]=(value(delta))*total_cap[r,s]/(value(i0_p[r,s])*(value(rho)+value(delta))) for r in regions, s in sectors]
# get(scalecap, (r,s), 0.0)

# Update parameters for next period
for r in regions, s in sectors
#update capital endowments
    set_value(ks_s[r,s], (1-value(delta)) * (value(ks_s[r,s]) + value(ks_n[r,s])));
    set_value(ks_x[r,s], (1-value(delta)) * value(ks_x[r,s]));
#    set_value(ks_n[r,s], (value(rho) + value(delta)) * value(i0_p[r,s]) );
    set_value(ks_n[r,s], value(delta)*get(total_cap,(r,s),0.0));
end

#steady-state investment assumption test
testk=Dict()
[testk[r,s]=value(kd0_p[r,s])-(value(ks_n[r,s])+value(ks_s[r,s])+value(ks_x[r,s])) for r in regions, s in sectors]

for r in regions, s in sectors
#update labor endowments --- I think I need separate parameters for labor endowments versus demand
    set_value(le0[r,s], (1 + value(eta)) * value(le0[r,s]));
end

for r in regions
    set_value(bopdef0_p[r], (1 + value(eta)) * value(bopdef0_p[r]));
end

for r in regions, g in goods
    set_value(g0_p[r,g], (1 + value(eta)) * value(g0_p[r,g]));
    set_value(i0_p[r,g], (1 + value(eta)) * value(i0_p[r,g]));
end

set_start_value.(all_variables(cge), result_value.(all_variables(cge)));

for r in regions
    set_start_value(C[r], result_value(C[r])*(1+value(eta)));
end

for (r,g) in sub_set_x
    set_start_value(X[(r,g)], result_value(X[(r,g)])*(1+value(eta)));
end

for (r,g) in sub_set_a    
    set_start_value(A[(r,g)], result_value(A[(r,g)])*(1+value(eta)));
end

for r in regions, m in margins
    set_start_value(MS[r,m], result_value(MS[r,m])*(1+value(eta)));
end

for (r,s) in sub_set_y
    set_start_value(YX[(r,s)], result_value(YX[(r,s)])*(1-value(delta)));
    set_start_value(YM[(r,s)], result_value(YM[(r,s)])*(1+value(eta)));
end


for r in regions, s in sectors
#update value shares
    set_value(alpha_kl[r,s], value(ld0_p[r,s])/(value(ld0_p[r,s]) + value(kd0_p[r,s])));
end

for r in regions, g in goods
#update value shares
    set_value(alpha_x[r,g], (value(x0_p[r, g]) - value(rx0_p[r, g])) / value(s0_p[r, g]));
    set_value(alpha_d[r,g], (value(xd0_p[r,g])) / value(s0_p[r, g]));
    set_value(alpha_n[r,g], value(xn0_p[r,g]) / (value(s0_p[r, g])));
    set_value(theta_n[r,g], value(nd0_p[r, g]) / (value(nd0_p[r, g]) + value(dd0_p[r, g])));
    set_value(theta_m[r,g], (1+value(tm0_p[r, g])) * value(m0_p[r, g]) / (value(nd0_p[r, g]) + value(dd0_p[r, g]) + (1 + value(tm0_p[r, g])) * value(m0_p[r, g])));
end

replace_nan_inf(alpha_kl)
replace_nan_inf(alpha_x)
replace_nan_inf(alpha_d)
replace_nan_inf(alpha_n)
replace_nan_inf(theta_n)
replace_nan_inf(theta_m)






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
