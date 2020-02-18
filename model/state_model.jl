################################################
#
# Replication of the state-level blueNOTE model
#
################################################


#include("SLiDE.jl")
using SLiDE
using CSV
using JuMP
using Complementarity
using DataFrames

############
# LOAD DATA
############

# For the time being, these result from a call to gdxdump
# for each parameter in the winddcdatabase.gdx file

# First need to select a year for the model to be based off of
mod_year = 2014

#specify the path where the dumped csv files are stored
data_temp_dir = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "model", "data_temp"))

#function here simplifies the loading and subsequent subsetting of the dataframes
function read_data_temp(file::String,year::Int64,dir::String,desc::String)
    df = SLiDE.read_file(dir,CSVInput(name=string(file,".csv"),descriptor=desc))
    df = df[df[!,:yr].==year,:]
    return df
end

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

##########
# FUNCTIONS
##########

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

#ordering here matters in that nd0 should be filled
#with m0 keys before dd0 filled with nd0
#never add keys to:
#ys0, s0, and a0
fill_zero(blueNOTE[:m0],blueNOTE[:tm0])
fill_zero(blueNOTE[:m0],blueNOTE[:nd0])
fill_zero(blueNOTE[:s0],blueNOTE[:x0])
fill_zero(blueNOTE[:x0],blueNOTE[:rx0])
fill_zero(blueNOTE[:nd0],blueNOTE[:dd0])

#need to create a dictionary with unique r/s keys in ys0
y_set = Dict()
y_vector = []
for keys in blueNOTE[:ys0]
    newkey = [keys[1][1],keys[1][2]]
    push!(y_vector,newkey)
end
y_vector = unique(y_vector)

for i in y_vector
    print(i)
    push!(y_set,(i[1],i[2])=>0)
end


###############
# -- SETS --
###############

# extract model indices from blueNOTE dict
# here are the exhaustive struct names
r = unique(key_to_vec(blueNOTE[:ys0],1))
s = unique(key_to_vec(blueNOTE[:ys0],2))
g = unique(key_to_vec(blueNOTE[:ys0],3))
m = unique(key_to_vec(blueNOTE[:md0],2))


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

for k in keys(blueNOTE[:m0])
    val = (1+blueNOTE[:tm0][k]) * blueNOTE[:m0][k] / (blueNOTE[:nd0][k]+blueNOTE[:dd0][k]+(1+blueNOTE[:tm0][k]) * blueNOTE[:m0][k])
    push!(theta_m,k=>val)
end


################
# VARIABLES
################

cge = MCPModel();

# some small value that acts 
# as a lower limit to variable values
eps = 1e-3

@variable(cge,Y[r,s]>=eps)
@variable(cge,X[r,g]>=eps,start=1) # Disposition
@variable(cge,A[r,g]>=eps,start=1) # Absorption
@variable(cge,C[r]>=eps,start=1) # Aggregate final demand
@variable(cge,MS[r,m]>=eps,start=1) # Margin supply

#commodities:
@variable(cge,PA[r,g]>=eps,start=1) # Regional market (input)
@variable(cge,PY[r,g]>=eps,start=1) # Regional market (output)
@variable(cge,PD[r,g]>=eps,start=1) # Local market price
@variable(cge,PN[g]>=eps,start=1) # National market
@variable(cge,PL[r]>=eps,start=1) # Wage rate
@variable(cge,PK[r,s]>=eps,start=1) # Rental rate of capital
@variable(cge,PM[r,m]>=eps,start=1) # Margin price
@variable(cge,PC[r]>=eps,start=1) # Consumer price index
@variable(cge,PFX>=eps,start=1) # Foreign exchange

#consumer:
@variable(cge,RA[r]>=eps,start=1) # Representative agent

##############
# CONSTRAINTS
##############



####XY -- designates that the macro named XY in the blueNOTE mcp was replaced
#y_set here is equivalent to the $y_(r,s) in the blueNOTE model
@mapping(cge,profit_y[r in rr,s in ss; haskey(y_set,(r,s)) ],
                sum(PA[r,g] * blueNOTE[:id0][r,g,s] for g in gg if haskey(blueNOTE[:id0],(r,g,s)) )
                + PL[r]   * (blueNOTE[:ld0][r,s] * (PL[r]^alpha_kl[r,s] * PK[r,s]^(1-alpha_kl[r,s]) ) / PL[r])  ####AL
                + PK[r,s] * (blueNOTE[:kd0][r,s] * (PL[r]^alpha_kl[r,s] * PK[r,s]^(1-alpha_kl[r,s]) ) / PK[r,s])  ####AK
                == 
                sum(PY[r,g] * blueNOTE[:ys0][r,s,g] for g in gg if haskey(blueNOTE[:ys0],(r,s,g)) )
);

fill_zero(alpha_x,alpha_n)
fill_zero(alpha_x,alpha_d)
fill_zero(blueNOTE[:s0],blueNOTE[:xd0])
fill_zero(blueNOTE[:s0],blueNOTE[:xn0])


@mapping(cge,profit_x[r in rr,g in gg; haskey(blueNOTE[:s0],(r,g)) ],
                PY[r,g] * blueNOTE[:s0][r,g] 
                == 
                PFX * ((blueNOTE[:x0][r,g] - blueNOTE[:rx0][r,g]) * PFX / (alpha_x[r,g]*PFX^5+alpha_n[r,g]*PN[g]^5+alpha_d[r,g]*PD[r,g]^5)^(1/5) )^4 ####AX
                + PN[g] * blueNOTE[:xn0][r,g] * (PN[g] / (alpha_x[r,g]*PFX^5+alpha_n[r,g]*PN[g]^5+alpha_d[r,g]*PD[r,g]^5)^(1/5))^4 ####AN / ####RX
                + PD[r,g] * blueNOTE[:xd0][r,g] * (PD[r,g] / (alpha_x[r,g]*PFX^5+alpha_n[r,g]*PN[g]^5+alpha_d[r,g]*PD[r,g]^5)^(1/5))^4 ####AD / ####RX
);


@mapping(cge,profit_x[r in rr,g in gg; haskey(blueNOTE[:a0],(r,g)) ],
                PY[r,g] * blueNOTE[:s0][r,g] 
                == 
                PFX * ((blueNOTE[:x0][r,g] - blueNOTE[:rx0][r,g]) * PFX / (alpha_x[r,g]*PFX^5+alpha_n[r,g]*PN[g]^5+alpha_d[r,g]*PD[r,g]^5)^(1/5) )^4 ####AX
                + PN[g] * blueNOTE[:xn0][r,g] * (PN[g] / (alpha_x[r,g]*PFX^5+alpha_n[r,g]*PN[g]^5+alpha_d[r,g]*PD[r,g]^5)^(1/5))^4 ####AN / ####RX
                + PD[r,g] * blueNOTE[:xd0][r,g] * (PD[r,g] / (alpha_x[r,g]*PFX^5+alpha_n[r,g]*PN[g]^5+alpha_d[r,g]*PD[r,g]^5)^(1/5))^4 ####AD / ####RX
);





