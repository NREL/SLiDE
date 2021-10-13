##################################################
#
# Replication of windc-3.0 capital transformation (rks) in julia with counterfactual testing
#
##################################################

# update packages in correct order
# - could skip the downgrade of PATHSolver/Complementarity and just do JuMP
# - new complementarity requires changes to way options/solve statement passed

# use repl to do this with package manager ] instead
# import Pkg
# Pkg.add(Pkg.PackageSpec(name = "DataFrames", version = v"0.21.8"))
# Pkg.add(Pkg.PackageSpec(name = "PATHSolver", version = v"0.6.2"))
# Pkg.add(Pkg.PackageSpec(name = "JuMP", version = v"0.21.4"))
# solution for jump is to use get(PK,(r,s),1.0) for example to replace haskey

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


# !!!! can't pass these to a @NLexpression
function testget(cont,key::Tuple,default)
    try
        getindex(cont,key)
    catch
        default
    end
end

function testget2(cont,key::Tuple,default)
    (isempty([k.I[1] for k in keys(cont) if k.I[1]==key]) ? 1.0 : getindex(cont,key))
end



############
# LOAD DATA
############

# year for the model to be based off of
mod_year = 2017
# dataset_r = "bmk_data_census"
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
sld[:resco2] = df_to_dict(Dict, read_data_temp("resco2",data_temp_dir,"residential co2 emissions"); drop_cols = [], value_col = :Val)
sld[:secco2] = df_to_dict(Dict, read_data_temp("secco2",data_temp_dir,"sectoral co2 emissions"); drop_cols = [], value_col = :Val)

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

for r in set[:r], g in set[:g], s in set[:s]
    get!(sld[:secco2],(r,g,s),0.0)
    get!(sld[:resco2],(r,g),0.0)
end

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


# More subsets
set[:em] = ["col","gas","oil","cru"]         # fossil energy pinned fuels
set[:fe] = ["col","gas","oil"]    # fossil energy goods
set[:xe] = ["col","gas","cru"]          # extractive resources
set[:ele] = ["ele"]                     # electricity
set[:oil] = ["oil"]                     # refined oil
set[:cru] = ["cru"]                     # crude oil
set[:gas] = ["gas"]                     # natural gas
set[:col] = ["col"]                     # coal
set[:en] = vcat(set[:fe], set[:ele]) # energy goods
set[:nfe] = setdiff(set[:g],set[:fe])   # non-fossil energy goods
set[:nxe] = setdiff(set[:g],set[:xe])   # non-extractive goods
set[:nele] = setdiff(set[:g],set[:ele]) # non-electricity goods
set[:nne] = setdiff(set[:g],set[:en])   # non-energy goods

sld[:va_bar] = (Dict((r,s) => (sld[:ld0][r,s] + sld[:kd0][r,s])
    for r in set[:r], s in set[:s]));

sld[:fe_bar] = (Dict((r,s) => sum(sld[:id0][r,g,s] for g in set[:fe])
    for r in set[:r], s in set[:s]));

sld[:en_bar] = (Dict((r,s) => sum(sld[:id0][r,g,s] for g in set[:en])
    for r in set[:r], s in set[:s]));

sld[:ne_bar] = (Dict((r,s) => sum(sld[:id0][r,g,s] for g in set[:nne])
    for r in set[:r], s in set[:s]));

sld[:vaen_bar] = (Dict((r,s) => (sld[:va_bar][r,s] + sld[:en_bar][r,s])
    for r in set[:r], s in set[:s]));

sld[:klem_bar] = (Dict((r,s) => (sld[:vaen_bar][r,s] + sld[:ne_bar][r,s])
    for r in set[:r], s in set[:s]));


sset[:PE] = filter(x -> sld[:en_bar][x] != 0.0, combvec(set[:r],set[:s]))
sset[:PVA] = filter(x -> sld[:va_bar][x] != 0.0, combvec(set[:r],set[:s]))
sset[:PYM] = filter(x -> sld[:klem_bar][x] != 0.0, combvec(set[:r],set[:s]))

sset[:IDA_ne] = filter(x -> sld[:id0][x] !=0.0, combvec(set[:r],set[:nne],set[:s]))
sset[:IDA_ele] = filter(x -> sld[:id0][x] !=0.0, combvec(set[:r],set[:ele],set[:s]))
sset[:IDA_fe] = filter(x -> sld[:id0][x] !=0.0, combvec(set[:r],set[:fe],set[:s]))

########## Model ##########
cge = MCPModel();

##############
# PARAMETERS
##############

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

# rescale taxes for now
@NLparameter(cge, tk0[r in set[:r]] == get(sld[:tk0],(r,),0.0)); #Balance of payments

#co2 emissions --- Converted to billion tonnes of co2
#so that model carbon prices interpreted in $/tonnes
@NLparameter(cge, idcb0[r in set[:r], g in set[:g], s in set[:s]] == sld[:secco2][r,g,s]*1e-3); # industrial/sectoral demand for co2
@NLparameter(cge, cdcb0[r in set[:r], g in set[:g]] == sld[:resco2][r,g]*1e-3);  # final demand for co2
@NLparameter(cge, cb0[r in set[:r]] == sum((sum(value(idcb0[r,g,s]) for s in set[:s]) + value(cdcb0[r,g])) for g in set[:g]));  # supply of co2
@NLparameter(cge, carb0[r in set[:r]] == value(cb0[r]));  # co2 endowment
@NLparameter(cge, idcco2[r in set[:r], g in set[:g], s in set[:s]] == ensurefinite(value(idcb0[r,g,s])/value(id0[r,g,s])));
@NLparameter(cge, cdcco2[r in set[:r], g in set[:g]] == ensurefinite(value(cdcb0[r,g])/value(cd0[r,g])));

for r in set[:r],s in set[:s]
    set_value(kd0[r,s],value(kd0[r,s])*(1+value(tk0[r])))
end

# labor-leisure parameters
@NLparameter(cge, inv0[r in set[:r]] == sum(value(i0[r,g]) for g in set[:g])); # Investment supply
@NLparameter(cge, lbr0[r in set[:r]] == sum(value(ld0[r,s]) for s in set[:s])); # Labor endowment/supply
@NLparameter(cge, extra[r in set[:r]] == 0.4); # extra time to calibrate time endowment based on labor
@NLparameter(cge, lte0[r in set[:r]] == value(lbr0[r])/(1-value(extra[r]))); # time endowment
@NLparameter(cge, lsr0[r in set[:r]] == value(lte0[r])-value(lbr0[r])); # leisure time
@NLparameter(cge, z0[r in set[:r]] == value(c0[r])+value(inv0[r])); # consumption-investment bundle
@NLparameter(cge, w0[r in set[:r]] == value(z0[r])+value(lsr0[r])); # welfare/full-consumption bundle

# calibrate welfare block substitution elasticity (explore ballard approach further)
@NLparameter(cge, theta_w[r in set[:r]] == ensurefinite(value(lsr0[r]) / value(w0[r])));
@NLparameter(cge, sup_ul == 0.05); # uncompensated labor supply elasticity
@NLparameter(cge, es_w[r in set[:r]] == 1 + value(sup_ul) / value(theta_w[r])); # elasticity for full consumption/welfare index bundle

# Recursive dynamic parameters
@NLparameter(cge, delta == 0.05); # 
@NLparameter(cge, eta == 0.0); # 
@NLparameter(cge, thetax == 0.25); # 
@NLparameter(cge, srv == 1-value(delta)); # 

@NLparameter(cge, ktot0[r in set[:r]] == sum(value(kd0[r,s]) for s in set[:s])); #
@NLparameter(cge, ktotrs0[r in set[:r],s in set[:s]] == value(kd0[r,s])); #
@NLparameter(cge, ks_x[r in set[:r],s in set[:s]] == value(thetax)*value(kd0[r,s])); #
@NLparameter(cge, ksrs_m0[r in set[:r],s in set[:s]] == (1-value(thetax))*value(kd0[r,s])); #
@NLparameter(cge, ksrs_m[r in set[:r],s in set[:s]] == value(ksrs_m0[r,s])); #
@NLparameter(cge, ks_m0[r in set[:r]] == value(ktot0[r])-sum(value(ks_x[r,s]) for s in set[:s])); #
@NLparameter(cge, ks_m[r in set[:r]] == value(ks_m0[r])); #

# Energy-Nesting Benchmark parameters
@NLparameter(cge, va_bar[r in set[:r], s in set[:s]] == value(ld0[r,s]) + value(kd0[r,s])); # bmk value-added
@NLparameter(cge, fe_bar[r in set[:r], s in set[:s]] == sum(value(id0[r,g,s]) for g in set[:fe])); # bmk fossil-energy FE
@NLparameter(cge, en_bar[r in set[:r], s in set[:s]] == sum(value(id0[r,g,s]) for g in set[:en])); # bmk energy EN
@NLparameter(cge, ne_bar[r in set[:r], s in set[:s]] == sum(value(id0[r,g,s]) for g in set[:nne])); # bmk non-energy NNE
@NLparameter(cge, vaen_bar[r in set[:r], s in set[:s]] == value(va_bar[r,s]) + value(en_bar[r,s])); # bmk value-added-energy vaen
@NLparameter(cge, klem_bar[r in set[:r], s in set[:s]] == value(vaen_bar[r,s]) + value(ne_bar[r,s])); # bmk value-added-energy vaen

# benchmark value share parameters
@NLparameter(cge, alpha_kl[r in set[:r], s in set[:s]] == ensurefinite(value(ld0[r,s]) / (value(ld0[r,s]) + value(kd0[r,s]))));
@NLparameter(cge, theta_xe[r in set[:r], g in set[:g]] == ensurefinite((value(x0[r,g]) - value(rx0[r,g])) / value(s0[r,g])));
@NLparameter(cge, theta_xd[r in set[:r], g in set[:g]] == ensurefinite(value(xd0[r,g]) / value(s0[r,g])));
@NLparameter(cge, theta_xn[r in set[:r], g in set[:g]] == ensurefinite(value(xn0[r,g]) / value(s0[r,g])));
@NLparameter(cge, theta_n[r in set[:r], g in set[:g]] == ensurefinite(value(nd0[r,g]) / (value(nd0[r,g]) + value(dd0[r,g]))));
@NLparameter(cge, theta_m[r in set[:r], g in set[:g]] == ensurefinite((1+value(tm0[r,g])) * value(m0[r,g]) / (value(nd0[r,g]) + value(dd0[r,g]) + (1 + value(tm0[r,g])) * value(m0[r,g]))));
@NLparameter(cge, theta_cd[r in set[:r], g in set[:g]] == ensurefinite(value(cd0[r,g]) / sum(value(cd0[r,gg]) for gg in set[:g])));
@NLparameter(cge, theta_inv[r in set[:r], g in set[:g]] == ensurefinite(value(i0[r,g]) / sum(value(i0[r,gg]) for gg in set[:g])));
@NLparameter(cge, theta_ksm[r in set[:r], s in set[:s]] == ensurefinite(value(ksrs_m0[r,s]) / sum(value(ksrs_m0[rr,ss]) for rr in set[:r] for ss in set[:s])));

# banchmark value shares - Energy-nesting
@NLparameter(cge, theta_fe[r in set[:r], g in set[:fe], s in set[:s]] == ensurefinite(value(id0[r,g,s])/value(fe_bar[r,s])));
@NLparameter(cge, theta_en[r in set[:r], g in set[:en], s in set[:s]] == ensurefinite(value(id0[r,g,s])/value(en_bar[r,s])));
@NLparameter(cge, theta_ele[r in set[:r], s in set[:s]] == ensurefinite(sum(value(id0[r,g,s]) for g in set[:ele])/value(en_bar[r,s])));
@NLparameter(cge, theta_ne[r in set[:r], g in set[:nne], s in set[:s]] == ensurefinite(value(id0[r,g,s])/value(ne_bar[r,s])));
@NLparameter(cge, theta_va[r in set[:r], s in set[:s]] == ensurefinite(value(va_bar[r,s])/value(vaen_bar[r,s])));
@NLparameter(cge, theta_kle[r in set[:r], s in set[:s]] == ensurefinite(value(vaen_bar[r,s])/value(klem_bar[r,s])));

#Substitution and transformation elasticities
@NLparameter(cge, es_va[r in set[:r], s in set[:s]] == 1); # value-added nest - substitution elasticity
@NLparameter(cge, es_y[r in set[:r], s in set[:s]]  == 0); # Top-level Y nest (VA,M) - substitution elasticity
@NLparameter(cge, es_m[r in set[:r], s in set[:s]]  == 0); # Materials nest - substitution elasticity
@NLparameter(cge, et_x[r in set[:r], g in set[:g]]    == 4); # Disposition, distribute regional supply to local, national, export - transformation elasticity
@NLparameter(cge, es_a[r in set[:r], g in set[:g]]    == 0); # Top-level A nest for aggregate demand (set[:m], set[:g]) - substitution elasticity
@NLparameter(cge, es_mar[r in set[:r], g in set[:g]]  == 0); # Margin supply - substitution elasticity
@NLparameter(cge, es_d[r in set[:r], g in set[:g]]    == 4); # Domestic demand aggregation nest (intranational) - substitution elasticity
@NLparameter(cge, es_f[r in set[:r], g in set[:g]]    == 2); # Domestic and foreign demand aggregation nest (international) - substitution elasticity
@NLparameter(cge, es_cd == 0.99); # Final consumption 
@NLparameter(cge, es_inv == 5); # investment
@NLparameter(cge, et_k == 4); # capital transformation

# Substitution elasticities Energy nesting
@NLparameter(cge, es_fe[s in set[:s]] == 0.5); #FE nest
@NLparameter(cge, es_ele[s in set[:s]] == 0.5); # EN nest
@NLparameter(cge, es_ve[s in set[:s]] == 0.5); # VAEN/KLE nest
@NLparameter(cge, es_ne[s in set[:s]] == 0); # NE nest
@NLparameter(cge, es_klem[s in set[:s]] == 0); # KLEM nest

set_value(es_ele["ele"],0.0);

##############
# VARIABLES
##############

# Set lower bound
lo = MODEL_LOWER_BOUND
#lo = 1e-4
lo_eps = 1e-4

#set[:s]
# @variable(cge, Y[(r,s) in sset[:Y]] >= lo, start = 1.0);
@variable(cge, YM[(r,s) in sset[:Y]] >= lo, start = 1-value(thetax));
@variable(cge, YX[(r,s) in sset[:Y]] >= lo, start = value(thetax));
@variable(cge, VA[(r,s) in sset[:PVA]] >= lo, start = (1-value(thetax)));
@variable(cge, E[(r,s) in sset[:PE]] >= lo, start = (1-value(thetax)));

@variable(cge, X[(r,g) in sset[:X]] >= lo, start = 1.0);
@variable(cge, A[(r,g) in sset[:A]] >= lo, start = 1.0);
@variable(cge, C[r in set[:r]] >= lo, start = 1.0);
@variable(cge, MS[r in set[:r], m in set[:m]] >= lo, start = 1.0);

@variable(cge, LS[r in set[:r]] >= lo, start = 1.0);
@variable(cge, KS >= lo, start = 1.0);
@variable(cge, INV[r in set[:r]] >= lo, start = 1.0);
@variable(cge, Z[r in set[:r]] >= lo, start = 1.0);
@variable(cge, W[r in set[:r]] >= lo, start = 1.0);

@variable(cge, CO2[r in set[:r]] >= lo, start = value(carb0[r]));


#commodities:
@variable(cge, PVA[(r,s) in sset[:PVA]] >= lo, start = 1.0); #
@variable(cge, PE[(r,s) in sset[:PE]] >= lo, start = 1.0); # 
@variable(cge, PA[(r,g) in sset[:PA]] >= lo, start = 1.0); # Regional market (input)
@variable(cge, PY[(r,g) in sset[:PY]] >= lo, start = 1.0); # Regional market (output)
@variable(cge, PD[(r,g) in sset[:PD]] >= lo, start = 1.0); # Local market price
@variable(cge, PN[g in set[:g]] >= lo, start =1.0); # National market
@variable(cge, PL[r in set[:r]] >= lo, start = 1.0); # Wage rate

# @variable(cge, PK[(r,s) in sset[:PK]] >= lo, start = 1.0); # Rental rate of capital ###
@variable(cge, RK[(r,s) in sset[:PK]] >= lo, start = 1.0); # Rental rate of capital - mutable ###
@variable(cge, RKX[(r,s) in sset[:PK]] >= lo, start = 1.0); # Rental rate of capital - extant ###
@variable(cge, RKS >= lo, start = 1.0); # Aggregate mutable rental rate

@variable(cge, PM[r in set[:r], m in set[:m]] >= lo, start = 1.0); # Margin price
@variable(cge, PC[r in set[:r]] >= lo, start = 1.0); # Consumer price index 

@variable(cge, 1.0>=PFX>=1.0, start = 1.0); # Foreign exchange (fixed as numeraire currently)

@variable(cge, PLS[r in set[:r]] >= lo, start = 1.0); # Opportunity cost of work price index
@variable(cge, PINV[r in set[:r]] >= lo, start = 1.0); # Investment price index
@variable(cge, PZ[r in set[:r]] >= lo, start = 1.0); # Cons-Inv price index
@variable(cge, PW[r in set[:r]] >= lo, start = 1.0); # Welfare/Full consumption price index 

@variable(cge, PDCO2[r in set[:r]] >= lo, start = 1e-6); # effective carbon price
@variable(cge, PCO2 >= lo, start = 1e-6); # carbon factor price

#consumer:
@variable(cge,RA[r in set[:r]]>=lo,start = value(w0[r])) ;

##############
# EQUATIONS
##############

#cobb-douglas function for value added (VA)
# @NLexpression(cge,CVA[r in set[:r],s in set[:s]],
#               PL[r]^alpha_kl[r,s] * (haskey(RK.lookup[1], (r,s)) ? RK[(r,s)] : 1.0) ^ (1-alpha_kl[r,s]) );
#               # PL[r]^alpha_kl[r,s] * (isempty([k.I[1] for k in keys(PK) if k.I[1]==(r,s)]) ? 1.0 : PK[(r,s)]) ^ (1-alpha_kl[r,s]) );

@NLexpression(cge,CVA[r in set[:r],s in set[:s]],
              PL[r]^alpha_kl[r,s] * (isempty([k.I[1] for k in keys(RK) if k.I[1]==(r,s)]) ? 1.0 : getindex(RK,(r,s))) ^ (1-alpha_kl[r,s]) );

# @NLexpression(cge,CVA[r in set[:r],s in set[:s]],
#               PL[r]^alpha_kl[r,s] * testget(RK,(r,s),1.0) ^ (1-alpha_kl[r,s]) );

#demand for labor in VA
@NLexpression(cge,LD[r in set[:r], s in set[:s]], ld0[r,s] * CVA[r,s] / PL[r] );

#demand for capital in VA
@NLexpression(cge,KD[r in set[:r],s in set[:s]],
              kd0[r,s] * CVA[r,s] / (haskey(RK.lookup[1], (r,s)) ? RK[(r,s)] : 1.0) );

@mapping(cge,profit_va[(r,s) in sset[:PVA]],
         CVA[r,s] - PVA[(r,s)]
);

# co2 inclusive input price
@NLexpression(cge,PID[r in set[:r],g in set[:g],s in set[:s]],
              ((haskey(PA.lookup[1],(r,g)) ? PA[(r,g)] : 1.0)+PDCO2[r]*idcco2[r,g,s])
);

@NLexpression(cge,PCD[r in set[:r],g in set[:g]],
              ((haskey(PA.lookup[1],(r,g)) ? PA[(r,g)] : 1.0)+PDCO2[r]*cdcco2[r,g])
);

# Unit cost function: Fossil-energy
@NLexpression(cge,CFE[r in set[:r], s in set[:s]],
              sum(theta_fe[r,g,s]*PID[r,g,s]^(1-es_fe[s]) for g in set[:fe])^(1/(1-es_fe[s]))
);

# Unit cost function: Energy (ele + fe)
@NLexpression(cge,CEN[r in set[:r], s in set[:s]],
              (sum(theta_ele[r,s]*PID[r,g,s]^(1-es_ele[s]) for g in set[:ele]) + (1-theta_ele[r,s])*CFE[r,s]^(1-es_ele[s]))^(1/(1-es_ele[s]))
);

# Demand function: fossil-energy
@NLexpression(cge,IDA_fe[r in set[:r], g in set[:fe], s in set[:s]],
              (CEN[r,s]/CFE[r,s])^(es_ele[s]) * (CFE[r,s]/PID[r,g,s])^(es_fe[s])
);

# Demand function: electricity
@NLexpression(cge,IDA_ele[r in set[:r], g in set[:ele], s in set[:s]],
              (CEN[r,s]/PID[r,g,s])^(es_ele[s])
);

@mapping(cge,profit_e[(r,s) in sset[:PE]],
         CEN[r,s] - PE[(r,s)]
);

# Unit cost function: Value-added + Energy
@NLexpression(cge,CVE[r in set[:r], s in set[:s]],
              (theta_va[r,s]*CVA[r,s]^(1-es_ve[s]) + (1-theta_va[r,s])*CEN[r,s]^(1-es_ve[s]))^(1/(1-es_ve[s]))
);

# Unit cost function: non-energy (materials)
@NLexpression(cge,CNE[r in set[:r], s in set[:s]],
              sum(theta_ne[r,g,s]*PID[r,g,s]^(1-es_ne[s]) for g in set[:nne])^(1/(1-es_ne[s]))
);

# Unit cost function: Value-added/Energy + non-energy (materials)
@NLexpression(cge,CYM[r in set[:r], s in set[:s]],
              (theta_kle[r,s]*CVE[r,s]^(1-es_klem[s]) + (1-theta_kle[r,s])*CNE[r,s]^(1-es_klem[s]))^(1/(1-es_klem[s]))
);

# Demand function: non-energy (materials)
@NLexpression(cge,IDA_ne[r in set[:r], g in set[:nne], s in set[:s]],
    (CYM[r,s]/CNE[r,s])^(es_klem[s])*(CNE[r,s]/PID[r,g,s])^(es_ne[s])
);

# Demand function: value-added composite
@NLexpression(cge,IVA[r in set[:r], s in set[:s]],
    (CYM[r,s]/CVE[r,s])^(es_klem[s])*(CVE[r,s]/CVA[r,s])^(es_ve[s])
);

# Demand function: energy composite
@NLexpression(cge,IE[r in set[:r], s in set[:s]],
    (CYM[r,s]/CVE[r,s])^(es_klem[s])*(CVE[r,s]/CEN[r,s])^(es_ve[s])
);

@mapping(cge,profit_ym[(r,s) in sset[:Y]],
         CYM[r,s]*klem_bar[r,s]
         - (sum(PY[(r,g)] * ys0[r,s,g] for g in set[:g] if ((r,g) in sset[:PY])) * (1-ty[r,s]))
);

@mapping(cge,profit_yx[(r,s) in sset[:Y]],
        sum(PID[r,g,s] * id0[r,g,s] for g in set[:g] if ((r,g) in sset[:PA]))
        + PL[r] * ld0[r,s]
        + (haskey(RKX.lookup[1], (r,s)) ? RKX[(r,s)] : 1.0)* kd0[r,s]
        - (sum(PY[(r,g)] * ys0[r,s,g] for g in set[:g] if ((r,g) in sset[:PY])) * (1-ty[r,s]))
);


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


@mapping(cge,profit_ms[r in set[:r],m in set[:m]],
         sum(PN[gm]*nm0[r,gm,m] + (haskey(PD.lookup[1],(r,gm)) ? PD[(r,gm)] : 1.0)*dm0[r,gm,m] for gm in set[:gm])
         - PM[r,m]*sum(md0[r,m,gm] for gm in set[:gm])
);

# !!!! no product function in Julia
# !!!! stick to fixed proportions I guess for now
# !!!! could possibly add if ((r,g) in sset[:CD]) to sum statement
# unit cost for consumption
@NLexpression(cge, CC[r in set[:r]],
    sum( theta_cd[r,gg]*PCD[r,gg]^(1-es_cd) for gg in set[:g])^(1/(1-es_cd))
);

# final demand
@NLexpression(cge,CD[r in set[:r],g in set[:g]],
    ((CC[r] / PCD[r,g])^es_cd));
#  cd0[r,g]*PC[r] / (haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0));

@mapping(cge,profit_c[r in set[:r]],
#         sum(PA[(r,g)]*theta_cd[r,g] for g in set[:g] if ((r,g) in sset[:PA]))
         CC[r]
         - PC[r]
);

@mapping(cge,profit_co2[r in set[:r]],
         PCO2 + (carb0[r]==0.0 ? PC[r] : 0.0)*1e-6
         - PDCO2[r]
);


@NLexpression(cge,CINV[r in set[:r]],
              (sum( theta_inv[r,gg]*(haskey(PA.lookup[1],(r,gg)) ? PA[(r,gg)] : 1.0)^(1-es_inv) for gg in set[:g])^(1/(1-es_inv)))
);

@NLexpression(cge, DINV[r in set[:r],g in set[:g]],
              ((CINV[r]/(haskey(PA.lookup[1],(r,g)) ? PA[(r,g)] : 1.0))^es_inv)
);

@mapping(cge, profit_inv[r in set[:r]],
         CINV[r]
         - PINV[r]
);

@mapping(cge, profit_ls[r in set[:r]],
         PLS[r]*lbr0[r]
         - PL[r]*lbr0[r]
);


@NLexpression(cge, CKS,
              (sum(theta_ksm[r,s]*RK[(r,s)]^(1+et_k) for r in set[:r] for s in set[:s] if ((r,s) in sset[:PK]))^(1/(1+et_k)))
);

@mapping(cge, profit_ks,
         RKS - CKS
);

@mapping(cge, profit_z[r in set[:r]],
         PC[r]*c0[r] + PINV[r]*inv0[r]
         - PZ[r]*z0[r]
);


@NLexpression(cge,CW[r in set[:r]],
              (theta_w[r]*PLS[r]^(1-es_w[r]) + (1-theta_w[r])*PZ[r]^(1-es_w[r]))^(1/(1-es_w[r]))
);

@NLexpression(cge, DZ[r in set[:r]],
              ((CW[r]/PZ[r])^es_w[r])
);

@NLexpression(cge, DLSR[r in set[:r]],
              ((CW[r]/PLS[r])^es_w[r])
);


@mapping(cge, profit_w[r in set[:r]],
         CW[r]
         - PW[r]
);


@mapping(cge,income_ra[r in set[:r]],
         RA[r]
         - (
             sum(PY[(r,g)]*yh0[r,g] for g in set[:g] if ((r,g) in sset[:PY]))
             + PFX*(bopdef0[r]+hhadj[r])
             - sum(PA[(r,g)]*(g0[r,g]) for g in set[:g] if ((r,g) in sset[:PA]))
             + PLS[r]*lbr0[r]
             + PLS[r]*lsr0[r]
             + RKS*ks_m[r]
             + sum(RKX[(r,s)]*ks_x[r,s] for s in set[:s] if ((r,s) in sset[:PK]))
             + sum(YM[(r,s)]*ty[r,s]*sum(PY[(r,g)]*ys0[r,s,g] for g in set[:g] if ((r,g) in sset[:PY])) for s in set[:s] if ((r,s) in sset[:Y]))
             + sum(YX[(r,s)]*ty[r,s]*sum(PY[(r,g)]*ys0[r,s,g] for g in set[:g] if ((r,g) in sset[:PY])) for s in set[:s] if ((r,s) in sset[:Y]))
             + sum(A[(r,g)]*ta[r,g]*PA[(r,g)]*a0[r,g] for g in set[:g] if ((r,g) in sset[:PA]))
             + sum(A[(r,g)]*tm[r,g]*PFX*m0[r,g]*(PMND[r,g]*(1+tm0[r,g])/(PFX*(1+tm[r,g])))^es_f[r,g] for g in set[:g] if ((r,g) in sset[:A]))
             + PCO2*carb0[r]
         )
);


# @mapping(cge,market_pa[(r,g) in sset[:PA]],
#          A[(r,g)]*a0[r,g]
#          - (
#              sum(YM[(r,s)]*id0[r,g,s] for s in set[:s] if ((r,s) in sset[:Y]))
#              + sum(YX[(r,s)]*id0[r,g,s] for s in set[:s] if ((r,s) in sset[:Y]))
#              + C[r]*cd0[r,g]*CD[r,g]
#              + g0[r,g]
#              + INV[r]*i0[r,g]*DINV[r,g]
#          )
# );


@mapping(cge,market_pa[(r,g) in sset[:PA]],
         A[(r,g)]*a0[r,g]
         - (
             sum(YM[(r,s)]*id0[r,g,s]*IDA_ne[r,g,s] for s in set[:s] if ((r,s) in sset[:Y] && (r,g,s) in sset[:IDA_ne]))
             + sum(E[(r,s)]*id0[r,g,s]*IDA_ele[r,g,s] for s in set[:s] if ((r,s) in sset[:PE] && (r,g,s) in sset[:IDA_ele]))
             + sum(E[(r,s)]*id0[r,g,s]*IDA_fe[r,g,s] for s in set[:s] if ((r,s) in sset[:PE] && (r,g,s) in sset[:IDA_fe]))
             # sum(YM[(r,s)]*id0[r,g,s] for s in set[:s] if ((r,s) in sset[:Y] && g in set[:nne]))
             # + sum(E[(r,s)]*id0[r,g,s] for s in set[:s] if ((r,s) in sset[:PE] && g in set[:ele]))
             # + sum(E[(r,s)]*id0[r,g,s] for s in set[:s] if ((r,s) in sset[:PE] && g in set[:fe]))
             + sum(YX[(r,s)]*id0[r,g,s] for s in set[:s] if ((r,s) in sset[:Y]))
             + C[r]*cd0[r,g]*CD[r,g]
             + g0[r,g]
             + INV[r]*i0[r,g]*DINV[r,g]
         )
);


@mapping(cge,market_py[(r,g) in sset[:PY]],
         sum(YM[(r,s)]*ys0[r,s,g] for s in set[:s] if ((r,s) in sset[:Y]))
         + sum(YX[(r,s)]*ys0[r,s,g] for s in set[:s] if ((r,s) in sset[:Y]))
         + yh0[r,g]
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
         (haskey(X.lookup[1],(r,g)) ? X[(r,g)] : 1.0)*xd0[r,g]*((isless(1e-6,(1-value(theta_xd[r,g])))) ? AD[r,g] : 1.0)
         - (
             (haskey(A.lookup[1],(r,g)) ? A[(r,g)] : 1.0)*dd0[r,g]*((PND[r,g]/PD[(r,g)])^es_d[r,g])*((PMND[r,g]/PND[r,g])^es_f[r,g])
             + sum(MS[r,m]*dm0[r,g,m] for m in set[:m] if (g in set[:gm]))
         )
);


@mapping(cge,market_pn[g in set[:g]],
         sum(X[(r,g)]*xn0[r,g]*((PN[g]/PY[(r,g)])^et_x[r,g]) for r in set[:r] if ((r,g) in sset[:X]))
         - (
             sum(A[(r,g)]*nd0[r,g]*((PND[r,g]/PN[g])^es_d[r,g])*((PMND[r,g]/PND[r,g])^es_f[r,g]) for r in set[:r] if ((r,g) in sset[:A]))
             + sum(MS[r,m]*nm0[r,g,m] for r in set[:r] for m in set[:m] if (g in set[:gm]))
         )
);


@mapping(cge,market_pfx,
         sum(X[(r,g)]*(x0[r,g]-rx0[r,g]) for (r,g) in sset[:X])
         + sum(A[(r,g)]*rx0[r,g] for (r,g) in sset[:A])
         + sum(bopdef0[r]+hhadj[r] for r in set[:r])
         - sum(A[(r,g)]*m0[r,g]*(((PMND[r,g]*(1+tm0[r,g]))/(PFX*(1+tm[r,g])))^es_f[r,g]) for (r,g) in sset[:A])
);


@mapping(cge,market_pe[(r,s) in sset[:PE]],
         E[(r,s)]*en_bar[r,s]
         - YM[(r,s)]*en_bar[r,s]*IE[r,s]
);

@mapping(cge,market_pva[(r,s) in sset[:PVA]],
         VA[(r,s)]*va_bar[r,s]
         - YM[(r,s)]*va_bar[r,s]*IVA[r,s]
);

@mapping(cge,market_pl[r in set[:r]],
         LS[r]*lbr0[r]
         - (
             sum(VA[(r,s)]*LD[r,s] for s in set[:s] if ((r,s) in sset[:PVA]))
             + sum(YX[(r,s)]*ld0[r,s] for s in set[:s] if ((r,s) in sset[:Y]))
         )
);

@mapping(cge,market_rk[(r,s) in sset[:PK]],
         KS*ksrs_m0[r,s]*((RK[(r,s)]/CKS)^et_k)
         - VA[(r,s)]*KD[r,s]
);

@mapping(cge,market_rks,
         sum(ks_m[r] for r in set[:r])
         - KS*sum(ksrs_m0[r,s] for r in set[:r] for s in set[:s])
);

@mapping(cge,market_rkx[(r,s) in sset[:PK]],
         ks_x[r,s]
         - YX[(r,s)]*kd0[r,s]
);


@mapping(cge,market_pm[r in set[:r],m in set[:m]],
         MS[r,m]*sum(md0[r,m,gm] for gm in set[:gm])
         - sum(md0[r,m,g]*A[(r,g)] for g in set[:g] if ((r,g) in sset[:A]))
);


@mapping(cge,market_pc[r in set[:r]],
         C[r]*c0[r]
         - Z[r]*c0[r]
);


@mapping(cge,market_pinv[r in set[:r]],
         INV[r]*inv0[r]
         - Z[r]*inv0[r]
);


@mapping(cge,market_pz[r in set[:r]],
         Z[r]*z0[r]
         - W[r]*z0[r]*DZ[r]
);


@mapping(cge,market_pls[r in set[:r]],
         lbr0[r]+lsr0[r]
         - (
             LS[r]*lbr0[r]
             + W[r]*lsr0[r]*DLSR[r]  
         )
);


@mapping(cge,market_pw[r in set[:r]],
         PW[r]*W[r]*w0[r]
         - RA[r]
);


@mapping(cge,market_pco2,
         sum(carb0[r] for r in set[:r]) - sum(CO2[r] for r in set[:r])
);


@mapping(cge,market_pdco2[r in set[:r]],
         CO2[r]
         - (
             sum(YX[(r,s)]*id0[r,g,s]*idcco2[r,g,s] for s in set[:s] for g in set[:g] if ((r,s) in sset[:Y]))
             + sum(YM[(r,s)]*id0[r,g,s]*idcco2[r,g,s]*IDA_ne[r,g,s] for s in set[:s] for g in set[:nne] if ((r,s) in sset[:Y] && (r,g,s) in sset[:IDA_ne]))
             + sum(E[(r,s)]*id0[r,g,s]*idcco2[r,g,s]*IDA_ele[r,g,s] for s in set[:s] for g in set[:ele] if ((r,s) in sset[:PE] && (r,g,s) in sset[:IDA_ele]))
             + sum(E[(r,s)]*id0[r,g,s]*idcco2[r,g,s]*IDA_fe[r,g,s] for s in set[:s] for g in set[:fe] if ((r,s) in sset[:PE] && (r,g,s) in sset[:IDA_fe]))
             + sum(C[r]*cd0[r,g]*CD[r,g]*cdcco2[r,g] for g in set[:g] if ((r,g) in sset[:PA]))
         )
);


# @complementarity(cge,profit_y,Y);
@complementarity(cge,profit_ym,YM);
@complementarity(cge,profit_yx,YX);
@complementarity(cge,profit_va,VA);
@complementarity(cge,profit_e,E);

@complementarity(cge,profit_x,X);
@complementarity(cge,profit_a,A);
@complementarity(cge,profit_c,C);
@complementarity(cge,profit_ms,MS);

@complementarity(cge,profit_ls,LS);
@complementarity(cge,profit_ks,KS);
@complementarity(cge,profit_inv,INV);
@complementarity(cge,profit_z,Z);
@complementarity(cge,profit_w,W);
@complementarity(cge,profit_co2,CO2);

@complementarity(cge,market_pva,PVA);
@complementarity(cge,market_pe,PE);
@complementarity(cge,market_pa,PA);
@complementarity(cge,market_py,PY);
@complementarity(cge,market_pd,PD);
@complementarity(cge,market_pn,PN);
@complementarity(cge,market_pl,PL);
# @complementarity(cge,market_pk,PK);
@complementarity(cge,market_rk,RK);
@complementarity(cge,market_rks,RKS);
@complementarity(cge,market_rkx,RKX);
@complementarity(cge,market_pm,PM);
@complementarity(cge,market_pc,PC);
@complementarity(cge,market_pfx,PFX);

@complementarity(cge,market_pls,PLS);
@complementarity(cge,market_pinv,PINV);
@complementarity(cge,market_pz,PZ);
@complementarity(cge,market_pw,PW);

@complementarity(cge,market_pco2,PCO2);
@complementarity(cge,market_pdco2,PDCO2);

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
    # set_value(tm[r,g],0.0)
    set_value(tm[r,g],value(tm0[r,g]))
end

for r in set[:r]
    set_value(carb0[r],value(carb0[r])*0.8)
end


chk = Dict((r,g) => isless(1e-6,(1-value(theta_xd[r,g])))
           for r in set[:r], g in set[:g]);

for r in set[:r],g in set[:g]
    if chk[r,g]==false
        println(r,",",g)
        # set_value(es_d[r,g],0.0)
    end
end

#set up the options for the path solver
PATHSolver.options(convergence_tolerance=1e-6, minor_iteration_limit=50812, time_limit=1e+10, cumulative_iteration_limit=100000)

# solve the model
status = solveMCP(cge)

for r in set[:r]
    println("$r=>",result_value(C[r])," C[r]")
    # println("$r=>",result_value(W[r])," W[r]")
end
