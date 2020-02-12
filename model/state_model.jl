################################################
#
# Replication of the state-level blueNOTE model
#
################################################


#include("../src/slide.jl")
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

##########
# SETS
##########

# extract model indices from blueNOTE dict
# here are the exhaustive struct names
ss = unique(blueNOTE[:ys0],:s)[!,:s]
gg = unique(blueNOTE[:ys0],:g)[!,:g]
rr = unique(blueNOTE[:ys0],:r)[!,:r]
mm = unique(blueNOTE[:md0],:m)[!,:m]


function tupleize(z::DataFrames.DataFrame,sets::Vector)

    #create an empty vector
    v = []

    #loop over elements in the vector 
    for i in 1:length(z[!,sets[1]])
        push!(v,[z[i,sets[1]],z[i,sets[2]]])
    end #end loop

    return v

end #end functiobn

# until we have structs, we'll need composite sets
# to evaluate the variable creation conditions
y_rs = tupleize(unique(blueNOTE[:ys0][!,[:r,:s]]),[:r,:s])
x_rg = tupleize(unique(blueNOTE[:s0][!,[:r,:g]]),[:r,:g]) #can be used as a substitute for pd0
a_rg = tupleize(unique([blueNOTE[:a0];blueNOTE[:rx0]][!,[:r,:g]]),[:r,:g])
pk_rs = tupleize(unique(blueNOTE[:kd0][!,[:r,:s]]),[:r,:s])

# function to check if the [x[xx],y[yy]] exists 
# in xy where xy is a vector of tuples
function check_xy(x,y,xx::Int64,yy::Int64,xy::Array)
    tup = [x[xx],y[yy]]
    return tup in xy
end

################
# VARIABLES
################

cge = MCPModel();


@variable(cge, Y[r=1:length(rr),ss=1:length(ss); check_xy(rr,ss,r,s,y_rs)]>=0)
@variable(cge,X[r=1:length(rr),g=1:length(gg); check_xy(rr,gg,r,g,x_rg)]>=0,start=1) # Disposition
@variable(cge,A[r=1:length(rr),g=1:length(gg); check_xy(rr,gg,r,g,a_rg)]>=0,start=1) # Absorption
@variable(cge,C[r=1:length(rr)]>=0,start=1) # Aggregate final demand
@variable(cge,MS[r=1:length(rr),m=1:length(mm)]>=0,start=1) # Margin supply

#commodities:
@variable(cge,PA[r=1:length(rr),g=1:length(gg)]>=0,start=1) # Regional market (input)
@variable(cge,PY[r=1:length(rr),g=1:length(gg)]>=0,start=1) # Regional market (output)
@variable(cge,PD[r=1:length(rr),g=1:length(gg)]>=0,start=1) # Local market price
@variable(cge,PN[g=1:length(gg)]>=0,start=1) # National market
@variable(cge,PL[r=1:length(rr)]>=0,start=1) # Wage rate
@variable(cge,PK[r=1:length(rr),s=1:length(ss)]>=0,start=1) # Rental rate of capital
@variable(cge,PM[r=1:length(rr),m=1:length(ss)]>=0,start=1) # Margin price
@variable(cge,PC[r=1:length(rr)]>=0,start=1) # Consumer price index
@variable(cge,PFX>=0,start=1) # Foreign exchange

#consumer:
@variable(cge,RA[r=1:length(rr)]>=0,start=1) # Representative agent

##############
# CONSTRAINTS
##############





