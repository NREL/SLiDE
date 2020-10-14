
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

# Note - using the comlementarity package until the native JuMP implementation 
#        of complementarity constraints allows for exponents neq 0/1/2
#               --- most recently tested on May 11, 2020 --- 


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
#data_temp_dir = "/Users/mbrown1/Documents/GitHub/SLiDE_JB/model/data_temp/"
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
#regions = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_r.csv"),descriptor="region set"))[!,:Dim1]);
#sectors = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_s.csv"),descriptor="sector set"))[!,:Dim1]);
#goods = sectors;
#margins = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_m.csv"),descriptor="margin set"))[!,:Dim1]);
#margins = convert(Vector{String},CSV.read(string(data_temp_dir,"\\set_m.csv"))[!,:Dim1])
#goods_margins = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_gm.csv"),descriptor="goods with margins set"))[!,:g]);

regions = convert(Vector{String},CSV.read(string(data_temp_dir,"\\set_r.csv"))[!,:Dim1])
sectors = convert(Vector{String},CSV.read(string(data_temp_dir,"\\set_s.csv"))[!,:Dim1])
goods = sectors;
margins = convert(Vector{String},CSV.read(string(data_temp_dir,"\\set_m.csv"))[!,:Dim1])
goods_margins = convert(Vector{String},CSV.read(string(data_temp_dir,"\\set_gm.csv"))[!,:g])

# declare subsets
fe = ["oil","min","pet"]
xe = ["oil","min"]
ele = ["uti"]
en = ["oil","min","pet","uti"]
ne = []
#populate ne subset - ne != en
for k in goods
        bki=0
        for i in en
                if k == i
                        bki = 1
                end
        end
        if bki == 0 
                push!(ne, k)
        end
end



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


##############
# PARAMETERS
##############

alpha_kl = Dict() #value share of labor in the K/L nest for regions and sectors
alpha_x  = Dict() #export value share
alpha_d  = Dict() #local/domestic supply share
alpha_n  = Dict() #national supply share
theta_n  = Dict() #national share of domestic Absorption
theta_m  = Dict() #domestic share of absorption

alpha_l = Dict()        #share of labor in total value-added (r,s)
alpha_k = Dict()        #share of capital in total value added (r,s)
theta_fe = Dict()       #share of g in FE as share of total FE (r,g,s)
theta_en = Dict()       #share of g in EN (r,g,s) 
theta_ele = Dict()      #share of ele in total energy (FE & ELE) (r,s)
theta_va = Dict()       #share of va in total value-added + Energy (r,s)
theta_ene = Dict()       #share of energy in total value-added + Energy (r,s)
theta_ne = Dict()       #share of g in NE as share of total NE (r,g,s)
theta_kle = Dict()      #share of kle in total kle + NE (r,s)
theta_mm = Dict()        #share of materials(m)/total NE in klem




for k in keys(blueNOTE[:ld0])
    val = blueNOTE[:ld0][k] / (blueNOTE[:kd0][k] + blueNOTE[:ld0][k])
    if isnan(val)
      val = 0
    end
    push!(alpha_kl,k=>val)
end

for k in keys(blueNOTE[:x0])
    val = (blueNOTE[:x0][k] - blueNOTE[:rx0][k]) / blueNOTE[:s0][k]   
    if isnan(val)
      val = 0
    end
    push!(alpha_x,k=>val)
end

for k in keys(blueNOTE[:xd0])
    val = blueNOTE[:xd0][k] / blueNOTE[:s0][k]
    if isnan(val)
      val = 0
    end
    push!(alpha_d,k=>val)
end

for k in keys(blueNOTE[:xn0])
    val = blueNOTE[:xn0][k] / blueNOTE[:s0][k]
    if isnan(val)
      val = 0
    end
    push!(alpha_n,k=>val)
end

for k in keys(blueNOTE[:nd0])
    val = blueNOTE[:nd0][k] / (blueNOTE[:nd0][k] + blueNOTE[:dd0][k])
    if isnan(val)
      val = 0
    end
    push!(theta_n,k=>val)
end

for k in keys(blueNOTE[:tm0])
    val = (1+blueNOTE[:tm0][k]) * blueNOTE[:m0][k] / (blueNOTE[:nd0][k]+blueNOTE[:dd0][k]+(1+blueNOTE[:tm0][k]) * blueNOTE[:m0][k])
    if isnan(val)
      val = 0
    end
    push!(theta_m,k=>val)
end

#calculate thetas and ..._bar 
va_bar = Dict()
fe_bar = Dict()
en_bar = Dict()
vaen_bar = Dict()
ne_bar = Dict()
klem_bar = Dict()



for k in keys(blueNOTE[:ld0])
        val = blueNOTE[:ld0][k]+blueNOTE[:kd0][k]
        rat = blueNOTE[:ld0][k]/val
        if isnan(rat)
                rat = 0
        end
        
        push!(va_bar, k=>val)
        push!(alpha_l, k=>rat)
        push!(alpha_k, k=>(1-rat))
end

### If I have a NaN for some of these ratios, and set to zero, what about other share (1-share).
### in the case of alpha_kl, which is assigned to labor share, that assumes capital share is (1-alpha_kl)
### but capital share is also zero...

function check_valz(d::Dict)
        counter=0
for k in keys(d)
        if d[k] == 0
#                println(k,"==>",d[k])
                counter+=1
        end
end
return counter
end
check_valz(va_bar)
check_valz(blueNOTE[:kd0])
check_valz(blueNOTE[:ld0])



for r in regions, s in sectors
        val=0
        for g in fe
                if haskey(blueNOTE[:id0],(r,g,s))
                        val += blueNOTE[:id0][r,g,s]
                end
        end
        push!(fe_bar, tuple(r,s)=>val)
end

for r in regions, s in sectors, g in fe
        if haskey(blueNOTE[:id0],(r,g,s))
                val = blueNOTE[:id0][r,g,s]/fe_bar[r,s]
                if isnan(val)
                        val = 0
                end

                push!(theta_fe,tuple(r,g,s)=>val)
        end
end

for r in regions, s in sectors
        val=0
        for g in en
                if haskey(blueNOTE[:id0],(r,g,s))
                        val += blueNOTE[:id0][r,g,s]
                end
        end
        push!(en_bar, tuple(r,s)=>val)
end

for r in regions, s in sectors, g in en
        if haskey(blueNOTE[:id0],(r,g,s))
                val = blueNOTE[:id0][r,g,s]/en_bar[r,s]
                if isnan(val)
                        val = 0
                end

                push!(theta_en, tuple(r,g,s)=>val)
        end
end

for r in regions, s in sectors
        val=0
        for g in ele
                if haskey(theta_en,(r,g,s))
                        val += theta_en[r,g,s]
                end
        end
        push!(theta_ele, tuple(r,s)=>val)
end

for r in regions, s in sectors
        val = va_bar[r,s] + en_bar[r,s]
        rat = va_bar[r,s]/val
        if isnan(rat)
                rat = 0
        end
        push!(vaen_bar, tuple(r,s)=>val)
        push!(theta_va, tuple(r,s)=>rat)
        push!(theta_ene, tuple(r,s)=>(1-rat))
end

for r in regions, s in sectors
        val=0
        for g in ne
                if haskey(blueNOTE[:id0],(r,g,s))
                        val += blueNOTE[:id0][r,g,s]
                end
        end
        push!(ne_bar, tuple(r,s) => val)
end

for r in regions, s in sectors, g in ne
        if haskey(blueNOTE[:id0],(r,g,s))
                val = blueNOTE[:id0][r,g,s]/ne_bar[r,s]
                if isnan(val)
                        val = 0
                end

                push!(theta_ne, tuple(r,g,s)=>val)
        end
end

for r in regions, s in sectors
        val = vaen_bar[r,s] + ne_bar[r,s]
        rat = vaen_bar[r,s]/val
        if isnan(rat)
                rat = 0
        end

        push!(klem_bar, tuple(r,s)=>val)
        push!(theta_kle, tuple(r,s)=>rat)
        push!(theta_mm, tuple(r,s)=>(1-rat))
end

check_valz(alpha_l)
check_valz(theta_fe)
check_valz(theta_en)
check_valz(theta_ele)
check_valz(theta_va)
#check_valz(theta_ene)
check_valz(theta_ne)
check_valz(theta_kle)
#check_valz(theta_mm)

check_valz(va_bar)
check_valz(fe_bar)
check_valz(en_bar)
check_valz(vaen_bar)
check_valz(ne_bar)
check_valz(klem_bar)

#= @NLexpression(cge,CEN[r in regions, s in sectors],
        ( sum( theta_ele[r,s] * PA[r,g] ^ (1-esub_ele) for g in ele ) + ((1-theta_ele[r,s]) * CFE[r,s] ^ (1-esub_ele)) ) ^ (1/(1-esub_ele))
);
 =#


#= theta_fe2 = Dict()
theta_fe2 = [tuple(r,g,s)=>blueNOTE[:id0][r,g,s]/denomfe[r,s] for r in regions, s in sectors, g in fe if haskey(blueNOTE[:id0],(r,g,s))]
theta_fe2 =#

#substitution elasticities
#esub_va = Dict()        #substitution elasticity in VA/KL nest
#esub_fe = Dict()        #substitution elasticity in FE nest
#esub_ele = Dict()       #substitution elasticity in EN nest
#esub_ve = Dict()        #substitution elasticity in VE/KLE nest 
#esub_ne = Dict()        #substitution elasticity in NE nest
#esub_klem = Dict()      #substitution elasticity in Y/KLEM nest

esub_va = 1
esub_fe = 0.5
esub_ele = 0.1
esub_ve = 0.5
esub_ne = 0.2
esub_klem = 0.3

test1 = Dict()
[test1[r,s] = (( theta_ele[r,s] * 1 ^ (1-esub_ele)) + ((1-theta_ele[r,s]) * 1 ^ (1-esub_ele)) ) ^ (1/(1-esub_ele)) for r in regions for s in sectors]
test1

test2 = Dict()
[test2[r,s] = ( sum( theta_fe[r,g,s] * 1 ^ (1-esub_fe) for g in fe ) ) ^ (1/(1-esub_fe)) for r in regions for s in sectors]
test2

test2b = Dict()
[test2b[r,s] = ( 1^theta_fe[r,g,s] for g in fe ) for r in regions for s in sectors]
test2b
cfeshr = Dict()

function product_dict(price, share, setlist, varnm)
for r in regions, s in sectors
        val=1
        for g in setlist
                val = val * (price^share[r,g,s])
        end
        push!(varnm, tuple(r,s)=>val)
end
end
product_dict(1, theta_fe, fe, cfeshr)
cfeshr


test3 = Dict()
[test3[r,s] = ( sum( theta_ne[r,g,s] * 1 ^ (1-esub_ne) for g in ne ) ) ^ (1/(1-esub_ne)) for r in regions for s in sectors]
test3

test4 = Dict()
[test4[r,s] = (theta_va[r,s]*1^(1-esub_ve) + (1-theta_va[r,s])*1^(1-esub_ve) ) ^ (1/(1-esub_ve)) for r in regions for s in sectors]
test4

test5 = Dict()
[test5[r,s] = (theta_va[r,s]*1^(1-esub_ve) + (1-theta_va[r,s])*1^(1-esub_ve) ) ^ (1/(1-esub_ve)) for r in regions for s in sectors]
test5

test6 = Dict()
[test6[r,s] = (1^alpha_kl[r,s] * 1 ^ (1-alpha_kl[r,s])) for r in regions for s in sectors]
test6

check_valz(test1)
check_valz(test2) # has zeros corresponding to zeros in kd0,ld0,va_bar --- these must just be missing entries
check_valz(test3) # has zeros corresponding to zeros in kd0, ld0, va_bar --- these must just be missing entries
check_valz(test4) 
check_valz(test5)
check_valz(test6)




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

##energy nesting sectors
@variable(cge,E[r in regions, s in sectors]>=sv, start=1)
@variable(cge,VA[r in regions, s in sectors]>=sv, start=1)


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

##energy nesting commodities
@variable(cge,PE[r in regions, s in sectors]>=sv,start=1)
@variable(cge,PVA[r in regions, s in sectors]>=sv,start=1)


#consumer:
@variable(cge,RA[r in regions]>=sv,start=blueNOTE[:c0][(r,)]) # Representative agent


###############################
# -- PLACEHOLDER VARIABLES --
###############################

#cobb-douglas function for value added (VA)
@NLexpression(cge,CVA[r in regions,s in sectors],
  PL[r]^alpha_kl[r,s] * PK[r,s] ^ (1-alpha_kl[r,s]) );

#demand for labor in VA
@NLexpression(cge,AL[r in regions, s in sectors],
  blueNOTE[:ld0][r,s] * CVA[r,s] / PL[r] );

#demand for capital in VA
@NLexpression(cge,AK[r in regions,s in sectors],
  blueNOTE[:kd0][r,s] * CVA[r,s] / PK[r,s] );

###

#### Energy Nesting Unit Cost Functions ###

@NLexpression(cge,CFE[r in regions, s in sectors],
        ( sum( theta_fe[r,g,s] * PA[r,g] ^ (1-esub_fe) for g in fe ) ) ^ (1/(1-esub_fe))
);

@NLexpression(cge,CEN[r in regions, s in sectors],
        ( sum( theta_ele[r,s] * PA[r,g] ^ (1-esub_ele) for g in ele ) + ((1-theta_ele[r,s]) * CFE[r,s] ^ (1-esub_ele)) ) ^ (1/(1-esub_ele))
);

@NLexpression(cge,CVE[r in regions, s in sectors],
        ( theta_va[r,s]*CVA[r,s]^(1-esub_ve) + (1-theta_va[r,s])*CEN[r,s]^(1-esub_ve) ) ^ (1/(1-esub_ve))
);

@NLexpression(cge,CNE[r in regions, s in sectors],
        ( sum( theta_ne[r,g,s] * PA[r,g] ^ (1-esub_ne) for g in ne ) ) ^ (1/(1-esub_ne))
);

@NLexpression(cge,CY[r in regions, s in sectors],
        ( theta_kle[r,s]*CVE[r,s]^(1-esub_klem) + (1-theta_kle[r,s])*CNE[r,s]^(1-esub_klem) ) ^ (1/(1-esub_klem))
);


######

### Energy Nesting Input Demand Functions ###

#= @NLexpression(cge,IDA[r in regions, g in goods, s in sectors],
        ( blueNOTE[:id0][r,g,s] * ( CNE[r,s] / PA[r,g] ) ^ esub_ne if g in ne )
        + ( blueNOTE[:id0][r,g,s] * ( CEN[r,s] / PA[r,g] ) ^ esub_ele if g in ele )
        + ( blueNOTE[:id0][r,g,s] * (( CEN[r,s] / CFE[r,s] ) ^ esub_ele) * (( CFE[r,s] / PA[r,g] ) ^ esub_fe) if g in fe )
); =#

#= @NLexpression(cge,IDA[r in regions, g in goods, s in sectors],
         ( g in ne ? blueNOTE[:id0][r,g,s] * ( CNE[r,s] / PA[r,g] ) ^ esub_ne : 0 )
        + ( g in ele  ?  blueNOTE[:id0][r,g,s] * ( CEN[r,s] / PA[r,g])  ^ esub_ele : 0)
        + ( g in fe ? blueNOTE[:id0][r,g,s] * (( CEN[r,s] / CFE[r,s] ) ^ esub_ele) * (( CFE[r,s] / PA[r,g] ) ^ esub_fe) : 0 )
); =#

@NLexpression(cge,IDA_ne[r in regions, g in ne, s in sectors],
        blueNOTE[:id0][r,g,s] * ( CNE[r,s] / PA[r,g] ) ^ esub_ne
);

@NLexpression(cge,IDA_ele[r in regions, g in ele, s in sectors],
        blueNOTE[:id0][r,g,s] * ( CEN[r,s] / PA[r,g])  ^ esub_ele
);

@NLexpression(cge,IDA_fe[r in regions, g in fe, s in sectors],
        blueNOTE[:id0][r,g,s] * (( CEN[r,s] / CFE[r,s] ) ^ esub_ele) * (( CFE[r,s] / PA[r,g] ) ^ esub_fe)
);


@NLexpression(cge,IVA[r in regions, s in sectors],
        ( va_bar[r,s] * ( CVE[r,s] / CVA[r,s] ) ^ esub_ve )
);

@NLexpression(cge,IE[r in regions, s in sectors],
        ( en_bar[r,s] * ( CVE[r,s] / CEN[r,s] ) ^ esub_ve )
);

######

#CES function for output demand - including
# exports (absent of re-exports) times the price for foreign exchange, 
# region's supply to national market times the national market price
# regional supply to local market times domestic price
@NLexpression(cge,RX[r in regions,g in goods],
  (alpha_x[r,g]*PFX^5+alpha_n[r,g]*PN[g]^5+alpha_d[r,g]*PD[r,g]^5)^(1/5) );

#demand for exports via demand function
@NLexpression(cge,AX[r in regions,g in goods],
  (blueNOTE[:x0][r,g] - blueNOTE[:rx0][r,g])*(PFX/RX[r,g])^4 );

#demand for contribution to national market 
@NLexpression(cge,AN[r in regions,g in goods],
  blueNOTE[:xn0][r,g]*(PN[g]/(RX[r,g]))^4 );

#demand for regionals supply to local market
@NLexpression(cge,AD[r in regions,g in goods],
  blueNOTE[:xd0][r,g] * (PD[r,g] / (RX[r,g]))^4 );

  ###

# CES function for tradeoff between national and domestic market
@NLexpression(cge,CDN[r in regions,g in goods],
  (theta_n[r,g]*PN[g]^(1-2)+(1-theta_n[r,g])*PD[r,g]^(1-2))^(1/(1-2)) );

# CES function for tradeoff between domestic consumption and foreign exports
# recall tm in the import tariff thus tm / tm0 is the relative change in import tariff rates
@NLexpression(cge,CDM[r in regions,g in goods],
  ((1-theta_m[r,g])*CDN[r,g]^(1-4)+theta_m[r,g]*
  (PFX*(1+blueNOTE[:tm][r,g])/(1+blueNOTE[:tm0][r,g]))^(1-4))^(1/(1-4)) 
  );

  ###

# regions demand from the national market <- note nesting of CDN in CDM
@NLexpression(cge,DN[r in regions,g in goods],
  blueNOTE[:nd0][r,g]*(CDN[r,g]/PN[g])^2*(CDM[r,g]/CDN[r,g])^4 );

# region demand from local market <- note nesting of CDN in CDM
@NLexpression(cge,DD[r in regions,g in goods],
  blueNOTE[:dd0][r,g]*(CDN[r,g]/PD[r,g])^2*(CDM[r,g]/CDN[r,g])^4 );

# import demand
@NLexpression(cge,MD[r in regions,g in goods],
  blueNOTE[:m0][r,g]*(CDM[r,g]*(1+blueNOTE[:tm][r,g])/(PFX*(1+blueNOTE[:tm0][r,g])))^4 );

# final demand
@NLexpression(cge,CD[r in regions,g in goods],
  blueNOTE[:cd0][r,g]*PC[r] / PA[r,g] );


###############################
# -- Zero Profit Conditions --
###############################

#= @mapping(cge,profit_y[r in regions,s in sectors],
# cost of intermediate demand
        sum(PA[r,g] * blueNOTE[:id0][r,g,s] for g in goods) 
# cost of labor inputs
        + PL[r] * AL[r,s]
# cost of capital inputs
        + PK[r,s] * AK[r,s]
        - 
# revenue from sectoral supply (take note of r/s/g indices on ys0)                
        sum(PY[r,g] * blueNOTE[:ys0][r,s,g] for g in goods) * (1-blueNOTE[:ty][r,s])
); =#

# Modified zero profit condition for Y
@mapping(cge,profit_y[r in regions, s in sectors],
        PVA[r,s] * IVA[r,s] 
        + PE[r,s] * IE[r,s] 
        + sum( PA[r,g] * IDA_ne[r,g,s] for g in ne )
        -
        sum( PY[r,g] * blueNOTE[:ys0][r,s,g] for g in goods ) * (1-blueNOTE[:ty][r,s])
);

### Energy nesting ZPF

@mapping(cge,profit_va[r in regions, s in sectors],
        PL[r] * AL[r,s] + PK[r,s] * AK[r,s]
        -
        PVA[r,s] * va_bar[r,s]
);

@mapping(cge,profit_e[r in regions, s in sectors],
        sum( PA[r,g] * IDA_ele[r,g,s] for g in ele )
        + sum( PA[r,g] * IDA_fe[r,g,s] for g in fe )
        -
        PE[r,s] * en_bar[r,s]
);

######

@mapping(cge,profit_x[r in regions,g in goods],
# output 'cost' from aggregate supply
        PY[r,g] * blueNOTE[:s0][r,g] 
        - (
# revenues from foreign exchange
        PFX * AX[r,g]
# revenues from national market                  
        + PN[g] * AN[r,g]
# revenues from domestic market
        + PD[r,g] * AD[r,g])
);


@mapping(cge,profit_a[r in regions,g in goods],
# costs from national market
        PN[g] * DN[r,g] 
# costs from domestic market                  
        + PD[r,g] * DD[r,g] 
# costs from imports, including import tariff
        + PFX * (1+blueNOTE[:tm][r,g]) * MD[r,g]
# costs of margin demand                
        + sum(PM[r,m] * blueNOTE[:md0][r,m,g] for m in margins)
        - ( 
# revenues from regional market based on armington supply               
        PA[r,g] * (1-blueNOTE[:ta][r,g]) * blueNOTE[:a0][r,g] 
# revenues from re-exports                   
        + PFX * blueNOTE[:rx0][r,g]
        )
);

@mapping(cge,profit_c[r in regions],
# costs of inputs - computed as final demand times regional market prices
        sum(PA[r,g] * CD[r,g] for g in goods)
        - 
# revenues/benefit computed as CPI * reference consumption                  
        PC[r] * blueNOTE[:c0][(r,)]
);


@mapping(cge,profit_ms[r in regions, m in margins],
# provision of margins to national market
        sum(PN[gm]   * blueNOTE[:nm0][r,gm,m] for gm in goods_margins)
# provision of margins to domestic market    
        + sum(PD[r,gm] * blueNOTE[:dm0][r,gm,m] for gm in goods_margins)
        - 
# total margin demand    
        PM[r,m] * sum(blueNOTE[:md0][r,m,gm] for gm in goods_margins)
);


###################################
# -- Market Clearing Conditions -- 
###################################

### Energy nesting market clearance ###

@mapping(cge,market_pe[r in regions, s in sectors],
        E[r,s] * en_bar[r,s] - Y[r,s] * IE[r,s]
);

@mapping(cge,market_pva[r in regions, s in sectors],
        VA[r,s] * va_bar[r,s] - Y[r,s] * IVA[r,s]
);

######


#= @mapping(cge,market_pa[r in regions, g in goods],
# absorption or supply
        A[r,g] * blueNOTE[:a0][r,g] 
        - ( 
# government demand (exogenous)       
        blueNOTE[:g0][r,g] 
# demand for investment (exogenous)
        + blueNOTE[:i0][r,g]
# final demand        
        + C[r] * CD[r,g]
# intermediate demand        
        + sum(Y[r,s] * blueNOTE[:id0][r,g,s] for s in sectors if (y_check[r,s] > 0))
        )
); =#

# Update to market_pa for energy nesting
@mapping(cge,market_pa[r in regions, g in goods],
        A[r,g] * blueNOTE[:a0][r,g]
        - (
                blueNOTE[:g0][r,g] + blueNOTE[:i0][r,g]
                + C[r] * CD[r,g]
#                + sum( Y[r,s] * IDA[r,g,s] for s in sectors if (y_check[r,s] > 0) )
#                + sum(Y[r,s] * blueNOTE[:id0][r,g,s] for s in sectors if (y_check[r,s] > 0))
                + sum( Y[r,s] * IDA_ne[r,g,s] for s in sectors if (y_check[r,s] > 0) && (g in ne) )
                + sum( Y[r,s] * IDA_ele[r,g,s] for s in sectors if (y_check[r,s] > 0) && (g in ele) )
                + sum( Y[r,s] * IDA_fe[r,g,s] for s in sectors if (y_check[r,s] > 0) && (g in fe) )
        )
);

@mapping(cge,market_py[r in regions, g in goods],
# sectoral supply
        sum(Y[r,s] * blueNOTE[:ys0][r,s,g] for s in sectors)
# household production (exogenous)        
        + blueNOTE[:yh0][r,g]
        - 
# aggregate supply (akin to market demand)                
        X[r,g] * blueNOTE[:s0][r,g]
);


@mapping(cge,market_pd[r in regions, g in goods],
# aggregate supply
        X[r,g] * AD[r,g] 
        - ( 
# demand for local market          
        A[r,g] * DD[r,g]
# margin supply from local market
        + sum(MS[r,m] * blueNOTE[:dm0][r,g,m] for m in margins if (g in goods_margins ) )  
        )
);

@mapping(cge,market_pn[g in goods],
# supply to the national market
        sum(X[r,g] * AN[r,g] for r in regions)
        - ( 
# demand from the national market 
        sum(A[r,g] * DN[r,g] for r in regions)
# market supply to the national market        
        + sum(MS[r,m] * blueNOTE[:nm0][r,g,m] for r in regions for m in margins if (g in goods_margins) )
        )
);

@mapping(cge,market_pl[r in regions],
# supply of labor
        sum(blueNOTE[:ld0][r,s] for s in sectors)
        - 
# demand for labor in all sectors        
        sum(Y[r,s] * AL[r,s] for s in sectors)
);

@mapping(cge,market_pk[r in regions, s in sectors],
# supply of capital available to each sector
        blueNOTE[:kd0][r,s]
# demand for capital in each sector        
        - Y[r,s] * AK[r,s]
);

@mapping(cge,market_pm[r in regions, m in margins],
# margin supply 
        MS[r,m] * sum(blueNOTE[:md0][r,m,gm] for gm in goods_margins)
        - 
# margin demand        
        sum(A[r,g] * blueNOTE[:md0][r,m,g] for g in goods)
);

@mapping(cge,market_pc[r in regions],
# final demand
        C[r] * blueNOTE[:c0][(r,)] 
        - 
# consumption / utiltiy        
        RA[r] / PC[r]
);


@mapping(cge,market_pfx,
# balance of payments (exogenous)
        sum(blueNOTE[:bopdef0][(r,)] for r in regions)
# supply of exports     
        + sum(X[r,g] * AX[r,g] for r in regions for g in goods)
# supply of re-exports        
        + sum(A[r,g] * blueNOTE[:rx0][r,g] for r in regions for g in goods if (a_set[r,g] != 0))
# import demand        
        - sum(A[r,g] * MD[r,g] for r in regions for g in goods if (a_set[r,g] != 0))
);

@mapping(cge,income_ra[r in regions],
# consumption/utility
        RA[r] - 
        ( 
# labor income        
        PL[r] * sum(blueNOTE[:ld0][r,s] for s in sectors)
# capital income        
        + sum(PK[r,s] * blueNOTE[:kd0][r,s] for s in sectors)
# provision of household supply          
        + sum(PY[r,g]*blueNOTE[:yh0][r,g] for g in goods)
# revenue or costs of foreign exchange including household adjustment   
        + PFX * (blueNOTE[:bopdef0][(r,)] + blueNOTE[:hhadj][(r,)])
# government and investment provision        
        - sum(PA[r,g] * (blueNOTE[:g0][r,g] + blueNOTE[:i0][r,g]) for g in goods)
# import taxes - assumes lumpsum recycling
        + sum(A[r,g] * MD[r,g]* PFX * blueNOTE[:tm][r,g] for g in goods if (a_set[r,g] != 0))
# taxes on intermediate demand - assumes lumpsum recycling
        + sum(A[r,g] * blueNOTE[:a0][r,g]*PA[r,g]*blueNOTE[:ta][r,g] for g in goods if (a_set[r,g] != 0) )
# production taxes - assumes lumpsum recycling  
        + sum(Y[r,s] * blueNOTE[:ys0][r,s,g] * blueNOTE[:ty][r,s] for s in sectors for g in goods)
        )
);


####################################
# -- Complementarity Conditions --
####################################

# equations with conditions cannot be paired 
# see workaround here: https://github.com/chkwon/Complementarity.jl/issues/37
[fix(PK[r,s],1;force=true) for r in regions for s in sectors if !(blueNOTE[:kd0][r,s] > 0)]
[fix(PY[r,g],1,force=true) for r in regions for g in goods if !(y_check[r,g]>0)]
[fix(PA[r,g],1,force=true) for r in regions for g in goods if !(blueNOTE[:a0][r,g]>0)]
[fix(PD[r,g],1,force=true) for r in regions for g in goods if (blueNOTE[:xd0][r,g] == 0)]
[fix(Y[r,s],1,force=true) for r in regions for s in sectors if !(y_check[r,s] > 0)]
[fix(X[r,g],1,force=true) for r in regions for g in goods if !(blueNOTE[:s0][r,g] > 0)]
[fix(A[r,g],1,force=true) for r in regions for g in goods if (a_set[r,g] == 0)]

### Not sure why do this, but doing anyways for energy nesting structure ###
[fix(E[r,s],1,force=true) for r in regions for s in sectors if !(en_bar[r,s] > 0)]
[fix(VA[r,s],1,force=true) for r in regions for s in sectors if !(va_bar[r,s] > 0)]
[fix(PE[r,s],1,force=true) for r in regions for s in sectors if !(en_bar[r,s] > 0)]
[fix(PVA[r,s],1,force=true) for r in regions for s in sectors if !(va_bar[r,s] > 0)]
######


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

### Energy nesting structure ###
@complementarity(cge,profit_e,E);
@complementarity(cge,profit_va,VA);
@complementarity(cge,market_pe,PE);
@complementarity(cge,market_pva,PVA);
######

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

