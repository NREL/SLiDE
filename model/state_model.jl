################################################
#
# Replication of the state-level blueNOTE model
#
################################################

using SLiDE
using CSV
using JuMP
using Complementarity

############
# LOAD DATA
############

# For the time being, these result from a call to gdxdump
# for each parameter in the winddcdatabase.gdx file

# First need to select a year for the model to be based off of
mod_year = 2014
data_temp_dir = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "model", "data_temp"))

function read_data_temp(file::String,year::Int64,dir::String,desc::String)
    df = SLiDE.read_file(dir,CSVInput(name=string(file,".csv"),descriptor=desc))
    df = df[df[!,:yr].==year,:]
    return df
end


blueNOTE = Dict(
    :ys0 => read_data_temp("ys0",mod_year,data_temp_dir,"Sectoral supply"),
    :id0 => read_data_temp("id0",mod_year,data_temp_dir,"Intermediate demand"),
    :ld0 => read_data_temp("ld0",mod_year,data_temp_dir,"Labor demand"),
    :kd0 => read_data_temp("kd0",mod_year,data_temp_dir,"Capital demand"),
    :ty0 => read_data_temp("ty0",mod_year,data_temp_dir,"Production tax"),
    :m0 => read_data_temp("m0",mod_year,data_temp_dir,"Imports"),
    :x0 => read_data_temp("x0",mod_year,data_temp_dir,"Exports of goods and services"),
    :rx0 => read_data_temp("rx0",mod_year,data_temp_dir,"Re-exports of goods and services"),
    :md0 => read_data_temp("md0",mod_year,data_temp_dir,"Total margin demand"),
    :nm0 => read_data_temp("nm0",mod_year,data_temp_dir,"Margin demand from national market"),
    :dm0 => read_data_temp("dm0",mod_year,data_temp_dir,"Margin supply from local market"),
    :s0 => read_data_temp("s0",mod_year,data_temp_dir,"Aggregate supply"),
    :a0 => read_data_temp("a0",mod_year,data_temp_dir,"Armington supply"),
    :ta0 => read_data_temp("ta0",mod_year,data_temp_dir,"Tax net subsidy rate on intermediate demand"),
    :tm0 => read_data_temp("tm0",mod_year,data_temp_dir,"Import tariff"),
    :cd0 => read_data_temp("cd0",mod_year,data_temp_dir,"Final demand"),
    :c0 => read_data_temp("c0",mod_year,data_temp_dir,"Aggregate final demand"),
    :yh0 => read_data_temp("yh0",mod_year,data_temp_dir,"Household production"),
    :bopdef0 => read_data_temp("bopdef0",mod_year,data_temp_dir,"Balance of payments"),
    :hhadj => read_data_temp("hhadj",mod_year,data_temp_dir,"Household adjustment"),
    :g0 => read_data_temp("g0",mod_year,data_temp_dir,"Government demand"),
    :i0 => read_data_temp("i0",mod_year,data_temp_dir,"Investment demand"),
    :xn0 => read_data_temp("xn0",mod_year,data_temp_dir,"Regional supply to national market"),
    :xd0 => read_data_temp("xd0",mod_year,data_temp_dir,"Regional supply to local market"),
    :dd0 => read_data_temp("dd0",mod_year,data_temp_dir,"Regional demand from local  market"),
    :nd0 => read_data_temp("nd0",mod_year,data_temp_dir,"Regional demand from national market")
)

```
function unique_array(dict::Dict,symb::Symbol)
    k = unique(Dict[:symb],:symb)[!,:symb]
    return k
end
```

##########
# SETS
##########

# extract model indices from blueNOTE dict
# here are the exhaustive struct names
s = unique(blueNOTE[:ys0],:s)[!,:s]
g = unique(blueNOTE[:ys0],:g)[!,:g]
r = unique(blueNOTE[:ys0],:r)[!,:r]
m = unique(blueNOTE[:md0],:m)[!,:m]

# until we have structs, we'll need composite sets
rs = unique(blueNOTE[:ys0][!,[:r,:s]])
rg = unique(blueNOTE[:s0][!,[:r,:g]])
a_rg = unique([blueNOTE[:a0];blueNOTE[:rx0]][!,[:r,:g]])

kk = []
for i in 1:length(rs[!,:r])
    push!(kk,[rs[i,:r],rs[i,:s]])
end


################
# VARIABLES
################

cge = MCPModel();

#convert rs to a vector of tuples
kk=[]
for i=1:length(rs[!,:r])
    push!(kk,[rs[i,:r],rs[i,:s]])
end

#function to check if [x[xx],y[yy]] exists in xy
function check_rs(x,y,xx::Int64,yy::Int64,xy::Array)
    tup = [x[xx],y[yy]]
    return tup in xy
end

@variable(cge, Y[rr=1:length(r),ss=1:length(s); check_rs(r,s,rr,ss,kk)]>=0)
@variable(cge,X[r,g]>=0,start=1) # Disposition
@variable(cge,A[r,g]>=0,start=1) # Absorption
@variable(cge,C[r]>=0,start=1) # Aggregate final demand
@variable(cge,MS[r,m]>=0,start=1) # Margin supply

#commodities:
@variable(cge,PA[r,g]>=0,start=1) # Regional market (input)
@variable(cge,PY[r,g]>=0,start=1) # Regional market (output)
@variable(cge,PD[r,g]>=0,start=1) # Local market price
@variable(cge,PN[g]>=0,start=1) # National market
@variable(cge,PL[r]>=0,start=1) # Wage rate
@variable(cge,PK[r,s]>=0,start=1) # Rental rate of capital
@variable(cge,PM[r,m]>=0,start=1) # Margin price
@variable(cge,PC[r]>=0,start=1) # Consumer price index
@variable(cge,PFX>=0,start=1) # Foreign exchange

#consumer:
@variable(cge,RA[r]>=0,start=1) # Representative agent

##############
# CONSTRAINTS
##############





