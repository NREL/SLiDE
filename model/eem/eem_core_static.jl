##################################################
#
# Replication of windc-3.0 core in julia with counterfactual testing
#
##################################################

# update packages in correct order
# - could skip the downgrade of PATHSolver/Complementarity and just do JuMP
# - new complementarity requires changes to way options/solve statement passed

# import Pkg
# Pkg.add(Pkg.PackageSpec(name = "DataFrames", version = v"0.21.8"))
# Pkg.add(Pkg.PackageSpec(name = "PATHSolver", version = v"0.6.2"))
# Pkg.add(Pkg.PackageSpec(name = "JuMP", version = v"0.21.4"))

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

function read_data_temp(file::String,dir::String,desc::String)
  df = SLiDE.read_file(dir,CSVInput(name=string(file,".csv"),descriptor=desc))
#  df = df[df[!,:yr].==year,:]
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

# year for the model to be based off of
mod_year = 2017
dataset_r = "bmk_data_state"

#specify the path where the dumped csv files are stored
data_temp_dir = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "model","eem", dataset_r))

sld = Dict(
    :ys0 => df_to_dict(Dict, read_data_temp("ys0",data_temp_dir,"Sectoral supply"); drop_cols = [], value_col = :Val),
    :id0 => df_to_dict(Dict, read_data_temp("id0",data_temp_dir,"Intermediate demand"); drop_cols = [], value_col = :Val),
    :ld0 => df_to_dict(Dict, read_data_temp("ld0",data_temp_dir,"Labor demand"); drop_cols = [], value_col = :Val),
    :kd0 => df_to_dict(Dict, read_data_temp("kd0",data_temp_dir,"Capital demand"); drop_cols = [], value_col = :Val),
    :ty0 => df_to_dict(Dict, read_data_temp("ty0",data_temp_dir,"Production tax"); drop_cols = [], value_col = :Val),
    :m0 => df_to_dict(Dict, read_data_temp("m0",data_temp_dir,"Imports"); drop_cols = [], value_col = :Val),
    :x0 => df_to_dict(Dict, read_data_temp("x0",data_temp_dir,"Exports of goods and services"); drop_cols = [], value_col = :Val),
    :rx0 => df_to_dict(Dict, read_data_temp("rx0",data_temp_dir,"Re-exports of goods and services"); drop_cols = [], value_col = :Val),
    :md0 => df_to_dict(Dict, read_data_temp("md0",data_temp_dir,"Total margin demand"); drop_cols = [], value_col = :Val),
    :nm0 => df_to_dict(Dict, read_data_temp("nm0",data_temp_dir,"Margin demand from national market"); drop_cols = [], value_col = :Val),
    :dm0 => df_to_dict(Dict, read_data_temp("dm0",data_temp_dir,"Margin supply from local market"); drop_cols = [], value_col = :Val),
    :s0 => df_to_dict(Dict, read_data_temp("s0",data_temp_dir,"Aggregate supply"); drop_cols = [], value_col = :Val),
    :a0 => df_to_dict(Dict, read_data_temp("a0",data_temp_dir,"Armington supply"); drop_cols = [], value_col = :Val),
    :ta0 => df_to_dict(Dict, read_data_temp("ta0",data_temp_dir,"Tax net subsidy rate on intermediate demand"); drop_cols = [], value_col = :Val),
    :tm0 => df_to_dict(Dict, read_data_temp("tm0",data_temp_dir,"Import tariff"); drop_cols = [], value_col = :Val),
    :cd0 => df_to_dict(Dict, read_data_temp("cd0",data_temp_dir,"Final demand"); drop_cols = [], value_col = :Val),
    :c0 => df_to_dict(Dict, read_data_temp("c0",data_temp_dir,"Aggregate final demand"); drop_cols = [], value_col = :Val),
#    :yh0 => df_to_dict(Dict, read_data_temp("yh0",data_temp_dir,"Household production"); drop_cols = [], value_col = :Val),
    :bopdef0 => df_to_dict(Dict, read_data_temp("bopdef0",data_temp_dir,"Balance of payments"); drop_cols = [], value_col = :Val),
    :hhadj => df_to_dict(Dict, read_data_temp("hhadj",data_temp_dir,"Household adjustment"); drop_cols = [], value_col = :Val),
    :g0 => df_to_dict(Dict, read_data_temp("g0",data_temp_dir,"Government demand"); drop_cols = [], value_col = :Val),
    :i0 => df_to_dict(Dict, read_data_temp("i0",data_temp_dir,"Investment demand"); drop_cols = [], value_col = :Val),
    :xn0 => df_to_dict(Dict, read_data_temp("xn0",data_temp_dir,"Regional supply to national market"); drop_cols = [], value_col = :Val),
    :xd0 => df_to_dict(Dict, read_data_temp("xd0",data_temp_dir,"Regional supply to local market"); drop_cols = [], value_col = :Val),
    :dd0 => df_to_dict(Dict, read_data_temp("dd0",data_temp_dir,"Regional demand from local  market"); drop_cols = [], value_col = :Val),
    :nd0 => df_to_dict(Dict, read_data_temp("nd0",data_temp_dir,"Regional demand from national market"); drop_cols = [], value_col = :Val)
)

sld[:tk0] = df_to_dict(Dict, read_data_temp("tk0",data_temp_dir,"capital tax rate"); drop_cols = [], value_col = :Val)

regions = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_r.csv"),descriptor="region set"))[!,:Dim1]);
sectors = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_s.csv"),descriptor="sector set"))[!,:Dim1]);
goods = sectors;
margins = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_m.csv"),descriptor="margin set"))[!,:Dim1]);

# * define margin goods
# gm(g) = yes$(sum((r,m), nm0(r,g,m) + dm0(r,g,m)) or sum((r,m), md0(r,m,g)));
# goods_margins = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_gm.csv"),descriptor="goods with margins set"))[!,:g]);


set = Dict(
    :r => regions,
    :s => sectors,
    :g => goods,
    :m => margins,
#    :gm => goods_margins
)

sld[:yh0] = Dict((r,g) => 0.0 for r in set[:r],g in set[:g])

# need to fill in zeros to avoid missing keys
fill_zero(tuple(regions,sectors,goods),sld[:ys0])
fill_zero(tuple(regions,goods,sectors),sld[:id0])
fill_zero(tuple(regions,sectors),sld[:ld0])
fill_zero(tuple(regions,sectors),sld[:kd0])
fill_zero(tuple(regions,sectors),sld[:ty0])
fill_zero(tuple(regions,goods),sld[:m0])
fill_zero(tuple(regions,goods),sld[:x0])
fill_zero(tuple(regions,goods),sld[:rx0])
fill_zero(tuple(regions,margins,goods),sld[:md0])
fill_zero(tuple(regions,goods,margins),sld[:nm0])
fill_zero(tuple(regions,goods,margins),sld[:dm0])
fill_zero(tuple(regions,goods),sld[:s0])
fill_zero(tuple(regions,goods),sld[:a0])
fill_zero(tuple(regions,goods),sld[:ta0])
fill_zero(tuple(regions,goods),sld[:tm0])
fill_zero(tuple(regions,goods),sld[:cd0])
fill_zero(tuple(regions),sld[:c0])
fill_zero(tuple(regions,goods),sld[:yh0])
fill_zero(tuple(regions),sld[:bopdef0])
fill_zero(tuple(regions),sld[:hhadj])
fill_zero(tuple(regions,goods),sld[:g0])
fill_zero(tuple(regions,goods),sld[:i0])
fill_zero(tuple(regions,goods),sld[:xn0])
fill_zero(tuple(regions,goods),sld[:xd0])
fill_zero(tuple(regions,goods),sld[:dd0])
fill_zero(tuple(regions,goods),sld[:nd0])

sld[:tm] = sld[:tm0]
sld[:ta] = sld[:ta0]
sld[:ty] = sld[:ty0]

#following subsets are used to limit the size of the model
# the a_set restricits the A variables indices to those
# with positive armington supply or re-exports
a_set = Dict()
[a_set[r,g] = sld[:a0][r,g] + sld[:rx0][r,g] for r in regions for g in goods]

# y_check is used to make sure the r/s combination 
# has a reference amount of sectoral supply
y_check = Dict()
[y_check[r,s] = sum(sld[:ys0][r,s,g] for g in goods) for r in regions for s in sectors]

gm_set = Dict()
[gm_set[g] = sum(sld[:nm0][r,g,m] + sld[:dm0][r,g,m] + sld[:md0][r,m,g] for r in set[:r] for m in set[:m]) for g in set[:g]]

set[:gm] = filter(x -> gm_set[x] != 0.0, set[:g]);

sset = Dict()

sset[:Y] = filter(x -> y_check[x] != 0.0, combvec(set[:r], set[:s]));
sset[:X] = filter(x -> sld[:s0][x[1],x[2]] != 0.0, combvec(set[:r], set[:g]));
sset[:A] = filter(x -> a_set[x[1], x[2]] != 0.0, combvec(set[:r], set[:g]));
sset[:PA] = filter(x -> sld[:a0][x[1],x[2]] != 0.0, combvec(set[:r], set[:g]));
sset[:PD] = filter(x -> sld[:xd0][x[1],x[2]] != 0.0, combvec(set[:r], set[:g]));
sset[:PK] = filter(x -> sld[:kd0][x[1],x[2]] != 0.0, combvec(set[:r], set[:s]));
sset[:PY] = filter(x -> sld[:s0][x[1], x[2]] != 0.0, combvec(set[:r], set[:g]));
sset[:CD] = filter(x -> sld[:cd0][x[1], x[2]] != 0.0, combvec(set[:r], set[:g]));


########## Model ##########
cge = MCPModel();

##############
# PARAMETERS
##############

#benchmark values
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
@NLparameter(cge, c0[r in set[:r]] == get(sld[:c0],(r,),0.0)); # Aggregate final demand
@NLparameter(cge, yh0[r in set[:r], g in set[:g]] == sld[:yh0][r,g]); #Household production
@NLparameter(cge, bopdef0[r in set[:r]] == get(sld[:bopdef0],(r,),0.0)); #Balance of payments
@NLparameter(cge, hhadj[r in set[:r]] == get(sld[:hhadj],(r,),0.0)); # Household adjustment
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
# @NLparameter(cge, tm[r in set[:r], g in set[:g]] == 0.0); #

@NLparameter(cge, tk0[r in set[:r]] == get(sld[:tk0],(r,),0.0)); #Balance of payments

for r in set[:r],s in set[:s]
    set_value(kd0[r,s],value(kd0[r,s])*(1+value(tk0[r])))
end

# benchmark value share parameters
@NLparameter(cge, alpha_kl[r in set[:r], s in set[:s]] == ensurefinite(value(ld0[r,s]) / (value(ld0[r,s]) + value(kd0[r,s]))));
@NLparameter(cge, theta_xe[r in set[:r], g in set[:g]] == ensurefinite((value(x0[r,g]) - value(rx0[r,g])) / value(s0[r,g])));
@NLparameter(cge, theta_xd[r in set[:r], g in set[:g]] == ensurefinite(value(xd0[r,g]) / value(s0[r,g])));
@NLparameter(cge, theta_xn[r in set[:r], g in set[:g]] == ensurefinite(value(xn0[r,g]) / value(s0[r,g])));
@NLparameter(cge, theta_n[r in set[:r], g in set[:g]] == ensurefinite(value(nd0[r,g]) / (value(nd0[r,g]) + value(dd0[r,g]))));
@NLparameter(cge, theta_m[r in set[:r], g in set[:g]] == ensurefinite((1+value(tm0[r,g])) * value(m0[r,g]) / (value(nd0[r,g]) + value(dd0[r,g]) + (1 + value(tm0[r,g])) * value(m0[r,g]))));

#Substitution and transformation elasticities
@NLparameter(cge, es_va[r in set[:r], s in set[:s]] == 1); # value-added nest - substitution elasticity
@NLparameter(cge, es_y[r in set[:r], s in set[:s]]  == 0); # Top-level Y nest (VA,M) - substitution elasticity
@NLparameter(cge, es_m[r in set[:r], s in set[:s]]  == 0); # Materials nest - substitution elasticity
@NLparameter(cge, et_x[r in set[:r], g in set[:g]]    == 4); # Disposition, distribute regional supply to local, national, export - transformation elasticity
@NLparameter(cge, es_a[r in set[:r], g in set[:g]]    == 0); # Top-level A nest for aggregate demand (set[:m], set[:g]) - substitution elasticity
@NLparameter(cge, es_mar[r in set[:r], g in set[:g]]  == 0); # Margin supply - substitution elasticity
@NLparameter(cge, es_d[r in set[:r], g in set[:g]]    == 4); # Domestic demand aggregation nest (intranational) - substitution elasticity
@NLparameter(cge, es_f[r in set[:r], g in set[:g]]    == 2); # Domestic and foreign demand aggregation nest (international) - substitution elasticity

##############
# VARIABLES
##############

# Set lower bound
lo = MODEL_LOWER_BOUND
#lo = 1e-4
lo_eps = 1e-4

#set[:s]
@variable(cge, Y[(r,s) in sset[:Y]] >= lo, start = 1.0);
@variable(cge, X[(r,g) in sset[:X]] >= lo, start = 1.0);
@variable(cge, A[(r,g) in sset[:A]] >= lo, start = 1.0);
@variable(cge, C[r in set[:r]] >= lo, start = 1.0);
@variable(cge, MS[r in set[:r], m in set[:m]] >= lo, start = 1.0);

#commodities:
@variable(cge, PA[(r,g) in sset[:PA]] >= lo, start = 1.0); # Regional market (input)
@variable(cge, PY[(r,g) in sset[:PY]] >= lo, start = 1.0); # Regional market (output)
@variable(cge, PD[(r,g) in sset[:PD]] >= lo, start = 1.0); # Local market price
@variable(cge, PN[g in set[:g]] >= lo, start =1.0); # National market
@variable(cge, PL[r in set[:r]] >= lo, start = 1.0); # Wage rate
@variable(cge, PK[(r,s) in sset[:PK]] >= lo, start = 1.0); # Rental rate of capital ###
@variable(cge, PM[r in set[:r], m in set[:m]] >= lo, start = 1.0); # Margin price
@variable(cge, PC[r in set[:r]] >= lo, start = 1.0); # Consumer price index #####
@variable(cge, 1.0>=PFX>=1.0, start = 1.0); # Foreign exchange

#consumer:
@variable(cge,RA[r in set[:r]]>=lo,start = value(c0[r])) ;

##############
# EQUATIONS
##############

#=
# * $prod:Y(r,s)$y_(r,s)  s:0 va:1
# * 	o:PY(r,g)	q:ys0(r,s,g)            a:RA(r) t:ty(r,s)    p:(1-ty0(r,s))
# * 	i:PA(r,g)	q:id0(r,g,s)
# * 	i:PL(r)		q:ld0(r,s)	va:
# * 	i:PK(r,s)	q:kd0(r,s)	va:

# parameter	lvs(r,s)	Labor value share;

# $echo	lvs(r,s) = 0; lvs(r,s)$ld0(r,s) = ld0(r,s)/(ld0(r,s)+kd0(r,s));	>>MCPMODEL.GEN	

# $macro	PVA(r,s)	(PL(r)**lvs(r,s) * PK(r,s)**(1-lvs(r,s)))

# $macro  LD(r,s)         (ld0(r,s)*PVA(r,s)/PL(r))
# $macro  KD(r,s)		(kd0(r,s)*PVA(r,s)/PK(r,s))

# prf_Y(y_(r,s))..

# 		sum(g, PA(r,g)*id0(r,g,s)) + 

# 			PL(r)*LD(r,s) + PK(r,s)*KD(r,s)
# *			(ld0(r,s)+kd0(r,s)) * PVA(r,s)

# 	=e= sum(g,PY(r,g)*ys0(r,s,g))*(1-ty(r,s));
=#

#cobb-douglas function for value added (VA)
@NLexpression(cge,CVA[r in set[:r],s in set[:s]],
              PL[r]^alpha_kl[r,s] * (haskey(PK.lookup[1], (r,s)) ? PK[(r,s)] : 1.0) ^ (1-alpha_kl[r,s]) );

#demand for labor in VA
@NLexpression(cge,LD[r in set[:r], s in set[:s]], ld0[r,s] * CVA[r,s] / PL[r] );

#demand for capital in VA
@NLexpression(cge,KD[r in set[:r],s in set[:s]],
              kd0[r,s] * CVA[r,s] / (haskey(PK.lookup[1], (r,s)) ? PK[(r,s)] : 1.0) );

@mapping(cge,profit_y[(r,s) in sset[:Y]],
# cost of intermediate demand
        sum(PA[(r,g)] * id0[r,g,s] for g in set[:g] if ((r,g) in sset[:PA]))
# cost of labor inputs
        + PL[r] * LD[r,s]
# cost of capital inputs
        + (haskey(PK.lookup[1], (r,s)) ? PK[(r,s)] : 1.0)* KD[r,s]
        -
# revenue from sectoral supply (take note of r/s/g indices on ys0)
        sum(PY[(r,g)] * ys0[r,s,g] for g in set[:g] if ((r,g) in sset[:PY])) * (1-ty[r,s])
);

#=
# * $prod:X(r,g)$x_(r,g)  t:4
# * 	o:PFX		q:(x0(r,g)-rx0(r,g))
# * 	o:PN(g)		q:xn0(r,g)
# * 	o:PD(r,g)	q:xd0(r,g)
# * 	i:PY(r,g)	q:s0(r,g)

# parameter	thetaxd(r,g)	Value share (output to PD market),
# 		thetaxn(r,g)	Value share (output to PN market),
# 		thetaxe(r,g)	Value share (output to PFX market);

# $echo	thetaxd(r,g) = xd0(r,g)/s0(r,g);		>>MCPMODEL.GEN	
# $echo	thetaxn(r,g) = xn0(r,g)/s0(r,g);		>>MCPMODEL.GEN	
# $echo	thetaxe(r,g) = (x0(r,g)-rx0(r,g))/s0(r,g);	>>MCPMODEL.GEN	

# $macro	RX(r,g)	 (( thetaxd(r,g) * PD(r,g)**(1+4) + thetaxn(r,g) * PN(g)**(1+4) + thetaxe(r,g) * PFX**(1+4) )**(1/(1+4)))

# prf_X(x_(r,g))..
# 		PY(r,g)*s0(r,g) =e= (x0(r,g)-rx0(r,g)+xn0(r,g)+xd0(r,g)) * RX(r,g);
=#

@NLexpression(cge,RX[r in set[:r],g in set[:g]],
              (
                  theta_xd[r,g]*(haskey(PD.lookup[1],(r,g)) ? PD[(r,g)] : 1.0)^(1+et_x[r,g])
                  + theta_xn[r,g]*PN[g]^(1+et_x[r,g])
                  + theta_xe[r,g]*PFX^(1+et_x[r,g])
              )^(1/(1+et_x[r,g]))
);

@mapping(cge,profit_x[(r,g) in sset[:X]],
         PY[(r,g)]*s0[r,g]
         - (x0[r,g]-rx0[r,g]+xn0[r,g]+xd0[r,g])*RX[r,g]
);

#=
# * $prod:A(r,g)$a_(r,g)  s:0 dm:2  d(dm):4
# * 	o:PA(r,g)	q:a0(r,g)		a:RA(r)	t:ta(r,g)	p:(1-ta0(r,g))
# * 	o:PFX		q:rx0(r,g)
# * 	i:PN(g)		q:nd0(r,g)	d:
# * 	i:PD(r,g)	q:dd0(r,g)	d:
# * 	i:PFX		q:m0(r,g)	dm: 	a:RA(r)	t:tm(r,g) 	p:(1+tm0(r,g))
# * 	i:PM(r,m)	q:md0(r,m,g)

# parameter	thetam(r,g)	Import value share
# 		thetan(r,g)	National value share;

# $echo	thetam(r,g)=0; thetan(r,g)=0;								>>MCPMODEL.GEN
# $echo	thetam(r,g)$m0(r,g) = m0(r,g)*(1+tm0(r,g))/(m0(r,g)*(1+tm0(r,g))+nd0(r,g)+dd0(r,g));	>>MCPMODEL.GEN
# $echo	thetan(r,g)$nd0(r,g) = nd0(r,g) /(nd0(r,g)+dd0(r,g));					>>MCPMODEL.GEN

# $macro PND(r,g)  ( (thetan(r,g)*PN(g)**(1-4) + (1-thetan(r,g))*PD(r,g)**(1-4))**(1/(1-4)) ) 
# $macro PMND(r,g) ( (thetam(r,g)*(PFX*(1+tm(r,g))/(1+tm0(r,g)))**(1-2) + (1-thetam(r,g))*PND(r,g)**(1-2))**(1/(1-2)) )

# prf_A(a_(r,g))..
# 	 	sum(m,PM(r,m)*md0(r,m,g)) + 
# 			(nd0(r,g)+dd0(r,g)+m0(r,g)*(1+tm0(r,g))) * PMND(r,g)
# 				=e= PA(r,g)*a0(r,g)*(1-ta(r,g)) + PFX*rx0(r,g);
=#

@NLexpression(cge,PND[r in set[:r],g in set[:g]],
              (
                  theta_n[r,g]*PN[g]^(1-es_d[r,g])
                  + (1-theta_n[r,g])*(haskey(PD.lookup[1],(r,g)) ? PD[(r,g)] : 1.0)^(1-es_d[r,g])
              )^(1/(1-es_d[r,g]))
);

@NLexpression(cge,PMND[r in set[:r],g in set[:g]],
              (
                  theta_m[r,g]*(PFX*(1+tm[r,g])/(1+tm0[r,g]))^(1-es_f[r,g])
                  + (1-theta_m[r,g])*PND[r,g]^(1-es_f[r,g])
              )^(1/(1-es_f[r,g]))
);

@mapping(cge,profit_a[(r,g) in sset[:A]],
         sum(PM[r,m]*md0[r,m,g] for m in set[:m])
         + (nd0[r,g]+dd0[r,g]+m0[r,g]*(1+tm0[r,g]))*PMND[r,g]
         - (
             (haskey(PA.lookup[1],(r,g)) ? PA[(r,g)] : 1.0)*a0[r,g]*(1-ta[r,g])
             + PFX*rx0[r,g]
         )
);

#=
# * $prod:MS(r,m)
# * 	o:PM(r,m)	q:(sum(gm, md0(r,m,gm)))
# * 	i:PN(gm)	q:nm0(r,gm,m)
# * 	i:PD(r,gm)	q:dm0(r,gm,m)

# prf_MS(r,m)..	sum(gm, PN(gm)*nm0(r,gm,m) + PD(r,gm)*dm0(r,gm,m)) =g= PM(r,m)*sum(gm, md0(r,m,gm));
=#

@mapping(cge,profit_ms[r in set[:r],m in set[:m]],
         sum(PN[gm]*nm0[r,gm,m] + (haskey(PD.lookup[1],(r,gm)) ? PD[(r,gm)] : 1.0)*dm0[r,gm,m] for gm in set[:gm])
         - PM[r,m]*sum(md0[r,m,gm] for gm in set[:gm])
);

#=
# * $prod:C(r)  s:1
# *     	o:PC(r)		q:c0(r)
# * 	i:PA(r,g)	q:cd0(r,g)

# prf_C(r)..	prod(g$cd0(r,g), PA(r,g)**(cd0(r,g)/c0(r))) =g= PC(r);
# prf_C(r).. sum(g$cd0(r,g),PA(r,g)*(cd0(r,g)/c0(r)) =g= PC(r);
=#

# !!!! no product function in Julia
# !!!! stick to fixed proportions I guess for now
# !!!! could possibly add if ((r,g) in sset[:CD]) to sum statement
@NLparameter(cge, theta_cd[r in set[:r], g in set[:g]] == ensurefinite(value(cd0[r,g]) / sum(value(cd0[r,gg]) for gg in set[:g])));

@NLparameter(cge, es_cd == 0.99);

# unit cost for consumption
@NLexpression(cge, CC[r in set[:r]],
    sum( theta_cd[r,gg]*(haskey(PA.lookup[1], (r, gg)) ? PA[(r, gg)] : 1.0)^(1-es_cd) for gg in set[:g])^(1/(1-es_cd))
);

# final demand
@NLexpression(cge,CD[r in set[:r],g in set[:g]],
    ((CC[r] / (haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0))^es_cd));
#  cd0[r,g]*PC[r] / (haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0));

@mapping(cge,profit_c[r in set[:r]],
#         sum(PA[(r,g)]*theta_cd[r,g] for g in set[:g] if ((r,g) in sset[:PA]))
         CC[r]
         - PC[r]
);

#=
# * $demand:RA(r)
# * 	d:PC(r)		q:c0(r)
# * 	e:PY(r,g)	q:yh0(r,g)
# * 	e:PFX		q:(bopdef0(r) + hhadj(r))
# * 	e:PA(r,g)	q:(-g0(r,g) - i0(r,g))
# * 	e:PL(r)		q:(sum(s,ld0(r,s)))
# * 	e:PK(r,s)	q:kd0(r,s)

# bal_RA(r)..	RA(r) =e= sum(g, PY(r,g)*yh0(r,g)) + PFX*(bopdef0(r) + hhadj(r))
# 				- sum(g, PA(r,g)*(g0(r,g)+i0(r,g))) 
# 				+ sum(s, PL(r)*ld0(r,s)) 
# 				+ sum(s, PK(r,s)*kd0(r,s))
# 				+ sum(y_(r,s), Y(r,s)*ty(r,s)*sum(g$ys0(r,s,g), PY(r,g)*ys0(r,s,g)))
# 				+ sum(a_(r,g)$a0(r,g), A(r,g)*ta(r,g)*PA(r,g)*a0(r,g))
# 				+ sum(a_(r,g)$m0(r,g), A(r,g)*tm(r,g)*PFX*m0(r,g)*
# 						(PMND(r,g)*(1+tm0(r,g))/(PFX*(1+tm(r,g))))**2);
=#

@mapping(cge,income_ra[r in set[:r]],
         RA[r]
         - (
             sum(PY[(r,g)]*yh0[r,g] for g in set[:g] if ((r,g) in sset[:PY]))
             + PFX*(bopdef0[r]+hhadj[r])
             - sum(PA[(r,g)]*(g0[r,g]+i0[r,g]) for g in set[:g] if ((r,g) in sset[:PA]))
             + sum(PL[r]*ld0[r,s] for s in set[:s])
             + sum(PK[(r,s)]*kd0[r,s] for s in set[:s] if ((r,s) in sset[:PK]))
             + sum(Y[(r,s)]*ty[r,s]*sum(PY[(r,g)]*ys0[r,s,g] for g in set[:g] if ((r,g) in sset[:PY])) for s in set[:s] if ((r,s) in sset[:Y]))
             + sum(A[(r,g)]*ta[r,g]*PA[(r,g)]*a0[r,g] for g in set[:g] if ((r,g) in sset[:PA]))
             + sum(A[(r,g)]*tm[r,g]*PFX*m0[r,g]*(PMND[r,g]*(1+tm0[r,g])/(PFX*(1+tm[r,g])))^es_f[r,g] for g in set[:g] if ((r,g) in sset[:A]))
         )
);

#=
# market clearance conditions:
# mkt_PA(a_(r,g))..	A(r,g)*a0(r,g) =e= sum(y_(r,s), Y(r,s)*id0(r,g,s)) 
# 					+ cd0(r,g)*C(r)*PC(r)/PA(r,g)
# 					+ g0(r,g) + i0(r,g);

# mkt_PA(a_(r,g))..	A(r,g)*a0(r,g) =e= sum(y_(r,s), Y(r,s)*id0(r,g,s)) 
# 					+ cd0(r,g)*C(r)
# 					+ g0(r,g) + i0(r,g);
=#

@mapping(cge,market_pa[(r,g) in sset[:PA]],
         A[(r,g)]*a0[r,g]
         - (
             sum(Y[(r,s)]*id0[r,g,s] for s in set[:s] if ((r,s) in sset[:Y]))
             + C[r]*cd0[r,g]*CD[r,g]
             + g0[r,g]
             + i0[r,g]
         )
);

# mkt_PY(r,g)$s0(r,g)..	sum(y_(r,s), Y(r,s)*ys0(r,s,g)) + yh0(r,g) =e= X(r,g) * s0(r,g);

@mapping(cge,market_py[(r,g) in sset[:PY]],
         sum(Y[(r,s)]*ys0[r,s,g] for s in set[:s] if ((r,s) in sset[:Y])) + yh0[r,g]
         - X[(r,g)]*s0[r,g]
);

#=
# mkt_PD(r,g)$xd0(r,g)..	X(r,g)*xd0(r,g) * 

# *	This is a tricky piece of code.  The PIP sector in HI has a single output from the 
# *	X sector into the PD market.  This output is only used in margins which have a Leontief
# *	demand structure.  In a counter-factual equilibrium, the price (PD("HI","PIP")) can then
# *	fall to zero, and iso-elastic compensated supply function cannot be evaluated  (0/0).
# *	We therefore need to differentiate between sectors with Leontief supply and those in 
# *	which outputs are produce for multiple markets.  This is the sort of numerical nuisance
# *	that is avoided when using MPSGE.

# 			( ( (PD(r,g)/RX(r,g))**4 )$round(1-thetaxd(r,g),6) + 1$(not round(1-thetaxd(r,g),6))) =e= 

# 				sum(a_(r,g), A(r,g) * dd0(r,g) * 
# 				(PND(r,g)/PD(r,g))**4 * (PMND(r,g)/PND(r,g))**2)
# 				+ sum((m,gm)$sameas(g,gm), dm0(r,gm,m)*MS(r,m));
=#

@NLexpression(cge,AD[r in set[:r],g in set[:g]],
  ((haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0) / (RX[r,g]))^et_x[r,g] );

# couple options for testing here
@mapping(cge,market_pd[(r,g) in sset[:PD]],
#         (haskey(X.lookup[1],(r,g)) ? X[(r,g)] : 1.0)*xd0[r,g]*((isless(1e-6,(1-value(theta_xd[r,g])))) ? ((PD[(r,g)]/RX[r,g])^et_x[r,g]) : 1.0)
#         (haskey(X.lookup[1],(r,g)) ? X[(r,g)] : 1.0)*xd0[r,g]*((PD[(r,g)]/RX[r,g])^et_x[r,g])
#         (haskey(X.lookup[1],(r,g)) ? X[(r,g)] : 1.0)*xd0[r,g]
         (haskey(X.lookup[1],(r,g)) ? X[(r,g)] : 1.0)*xd0[r,g]*((isless(1e-6,(1-value(theta_xd[r,g])))) ? AD[r,g] : 1.0)
         - (
             (haskey(A.lookup[1],(r,g)) ? A[(r,g)] : 1.0)*dd0[r,g]*((PND[r,g]/PD[(r,g)])^es_d[r,g])*((PMND[r,g]/PND[r,g])^es_f[r,g])
             + sum(MS[r,m]*dm0[r,g,m] for m in set[:m] if (g in set[:gm]))
         )
);

#=
# mkt_PN(g)..		sum(x_(r,g), X(r,g) * xn0(r,g) * (PN(g)/PY(r,g))**4) =e= 
# 			sum(a_(r,g), A(r,g) * nd0(r,g) * (PND(R,G)/PN(g))**4 * (PMND(r,g)/PND(r,g))**2)
# 			+ sum((r,m,gm)$sameas(g,gm), nm0(r,gm,m)*MS(r,m));
=#

@mapping(cge,market_pn[g in set[:g]],
         sum(X[(r,g)]*xn0[r,g]*((PN[g]/PY[(r,g)])^et_x[r,g]) for r in set[:r] if ((r,g) in sset[:X]))
         - (
             sum(A[(r,g)]*nd0[r,g]*((PND[r,g]/PN[g])^es_d[r,g])*((PMND[r,g]/PND[r,g])^es_f[r,g]) for r in set[:r] if ((r,g) in sset[:A]))
             + sum(MS[r,m]*nm0[r,g,m] for r in set[:r] for m in set[:m] if (g in set[:gm]))
         )
);

#=
# mkt_PFX..		sum(x_(r,g), X(r,g)*(x0(r,g)-rx0(r,g))*(PFX/PY(r,g))**4) 
# 			+ sum(a_(r,g), A(r,g)*rx0(r,g)) 
# 			+ sum(r, bopdef0(r)+hhadj(r)) =e= 
# 			sum(a_(r,g), A(r,g)*m0(r,g)*(PMND(r,g)*(1+tm0(r,g))/(PFX*(1+tm(r,g))))**2);
=#

@mapping(cge,market_pfx,
         sum(X[(r,g)]*(x0[r,g]-rx0[r,g]) for (r,g) in sset[:X])
         + sum(A[(r,g)]*rx0[r,g] for (r,g) in sset[:A])
         + sum(bopdef0[r]+hhadj[r] for r in set[:r])
         - sum(A[(r,g)]*m0[r,g]*(((PMND[r,g]*(1+tm0[r,g]))/(PFX*(1+tm[r,g])))^es_f[r,g]) for (r,g) in sset[:A])
);

# mkt_PL(r)..	sum(s,ld0(r,s)) =g= sum(y_(r,s), Y(r,s)*ld0(r,s)*PVA(r,s)/PL(r));

@mapping(cge,market_pl[r in set[:r]],
         sum(ld0[r,s] for s in set[:s])
#         - sum(Y[(r,s)]*ld0[r,s]*(CVA[r,s]/PL[r]) for s in set[:s] if ((r,s) in sset[:Y]))
         - sum(Y[(r,s)]*LD[r,s] for s in set[:s] if ((r,s) in sset[:Y]))
);

# mkt_PK(r,s)$kd0(r,s)..	kd0(r,s) =e= kd0(r,s)*Y(r,s)*PVA(r,s)/PK(r,s);

@mapping(cge,market_pk[(r,s) in sset[:PK]],
         kd0[r,s]
#         - kd0[r,s]*Y[(r,s)]*(CVA[r,s]/PK[(r,s)])
         - Y[(r,s)]*KD[r,s]
);

# mkt_PM(r,m)..		MS(r,m)*sum(gm,md0(r,m,gm)) =e= sum(a_(r,g),md0(r,m,g)*A(r,g));

@mapping(cge,market_pm[r in set[:r],m in set[:m]],
         MS[r,m]*sum(md0[r,m,gm] for gm in set[:gm])
         - sum(md0[r,m,g]*A[(r,g)] for g in set[:g] if ((r,g) in sset[:A]))
);

# mkt_PC(r)..	C(r)*c0(r)*PC(r) =e= RA(r);

@mapping(cge,market_pc[r in set[:r]],
         PC[r]*C[r]*c0[r]
         - RA[r]
);


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

# Free trade counterfactual
for r in set[:r],g in set[:g]
    set_value(tm[r,g],0.0)
    # set_value(tm[r,g],value(tm0[r,g]))
    # set_value(et_x[r,g],0.0)
    # set_value(es_d[r,g],0.0)
    # set_value(es_f[r,g],0.0)
end

chk = Dict((r,g) => isless(1e-6,(1-value(theta_xd[r,g])))
           for r in set[:r], g in set[:g]);

for r in set[:r],g in set[:g]
    if chk[r,g]==false
        println(r,",",g)
        # set_value(et_x[r,g],0.0)
        # set_value(es_d[r,g],0.0)
        # set_value(es_f[r,g],0.0)
    end
end

# for r in set[:r],s in set[:s]
#     set_value(ty[r,s],value(ty0[r,s])*1.05)
# end

#value(tm["SC","che"])

#set up the options for the path solver
PATHSolver.options(convergence_tolerance=1e-6, minor_iteration_limit=50812, time_limit=1e+10, cumulative_iteration_limit=100000)

# solve the model
status = solveMCP(cge)

for r in set[:r]
    println(r,"=>",result_value(C[r]))
end
