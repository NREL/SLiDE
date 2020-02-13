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


td = Dict()

test2 = read_data_temp("ys0",mod_year,data_temp_dir,"Sectoral supply")

function df_to_dict(df::DataFrame)
    for i in 1:length(df[!,names(df)[1]])
end


for i in 1:length(test2[!,:yr])
    push!(td,[test2[i,:r],test2[i,:s],test2[i,:g]] => test2[i,:Val])
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
# SETS
##########

# extract model indices from blueNOTE dict
# here are the exhaustive struct names
ss = unique(blueNOTE[:ys0],:s)[!,:s]
gg = unique(blueNOTE[:ys0],:g)[!,:g]
rr = unique(blueNOTE[:ys0],:r)[!,:r]
mm = unique(blueNOTE[:md0],:m)[!,:m]

##############
# PARAMETERS
##############

alpha_rs = blueNOTE[:ld0]
alpha_rs[!,:ld0] = alpha_rs[!,:Val]
alpha_rs[!,:kd0] = blueNOTE[:kd0][!,:Val]
alpha_rs[!,:Val] = alpha_rs[!,:ld0] ./ (alpha_rs[!,:ld0] + alpha_rs[!,:kd0])







##################################
# CONDITIONAL SETS AND FUNCTIONS
##################################

function tupleize(z::DataFrames.DataFrame,sets::Vector)

    #create an empty vector
    v = []

    #loop over elements in the vector 
    for i in 1:length(z[!,sets[1]])
        push!(v,[z[i,sets[1]],z[i,sets[2]]])
    end #end loop

    return v

end #end function


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

@variable(cge,Y[r in rr,s in ss]>=0)

@constraint(cge,ycon[r in rr,s in ss],
                Y[r,s] >= sum(values(td[[r,s,g]]) for g in gg if haskey(td,[r,s,g]))
)





@variable(cge,Y[r in rr,s in ss,g in gg]>=0)

@constraint(cge,ycon[r in rr,s in ss,g in gg; haskey(td,[r,s,g])],
                    Y[r,s,g] >= td[r,s,g])


@constraint(cge,temp1[r,s],Y[r,s]>=0)


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

