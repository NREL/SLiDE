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

function df_to_dict(df::DataFrame,remove_columns::Vector{Symbol},value_column::Symbol)
    colnames = setdiff(names(df),[remove_columns; value_column])
    return Dict(tuple(row[colnames]...)=>row[:Val] for row in eachrow(df))
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

###############
# -- SETS --
###############

# read sets from their dumped CSVs
regions = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_r.csv"),descriptor="region set"))[!,:Dim1]);
sectors = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_s.csv"),descriptor="sector set"))[!,:Dim1]);
goods = sectors;
margins = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_m.csv"),descriptor="margin set"))[!,:Dim1]);
goods_margins = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_gm.csv"),descriptor="goods with margins set"))[!,:g]);


#need to create a dictionary with unique r/s keys in ys0
#but requires us to remove the third 'g' key in the r/s/g 
#dict keys in the ys0 parameter
y_set = Dict()
y_vector = []
for keys in blueNOTE[:ys0]
    newkey = [keys[1][1],keys[1][2]]
    push!(y_vector,newkey)
end
y_vector = unique(y_vector)

for i in y_vector
    push!(y_set,(i[1],i[2])=>0)
end

x_set = blueNOTE[:s0]
pd_set = blueNOTE[:xd0]

#here creating a placeholder set to make sure we don't modify blueNOTE[:rx0]
temp_a2 = blueNOTE[:rx0]
fill_zero(blueNOTE[:a0],temp_a2)
a_set = temp_a2

fill_zero(y_set,blueNOTE[:yh0])

fill_zero(x_set,blueNOTE[:x0])
fill_zero(x_set,blueNOTE[:rx0])
fill_zero(x_set,blueNOTE[:xd0])
fill_zero(x_set,blueNOTE[:xn0])

fill_zero(a_set,blueNOTE[:nd0])
fill_zero(a_set,blueNOTE[:dd0])
fill_zero(a_set,blueNOTE[:tm0])
fill_zero(a_set,blueNOTE[:m0])
fill_zero(a_set,blueNOTE[:cd0])
fill_zero(a_set,blueNOTE[:g0])
fill_zero(a_set,blueNOTE[:i0])
fill_zero(a_set,blueNOTE[:a0])
fill_zero(a_set,blueNOTE[:ta0])


##############
# PARAMETERS
##############

alpha_kl = Dict() #value share of labor in the K/L nest for regions and sectors
alpha_x  = Dict() #export value share
alpha_d  = Dict() #local/domestic supply share
alpha_n  = Dict() #national supply share
theta_n  = Dict() #national share of domestic Absorption
theta_m  = Dict() #domestic share of absorption

for k in keys(y_set)
    val = blueNOTE[:ld0][k] / (blueNOTE[:kd0][k] + blueNOTE[:ld0][k])
    push!(alpha_kl,k=>val)
end

for k in keys(x_set)
    val = (blueNOTE[:x0][k] - blueNOTE[:rx0][k]) / blueNOTE[:s0][k]   
    push!(alpha_x,k=>val)
end

for k in keys(x_set)
    val = blueNOTE[:xd0][k] / blueNOTE[:s0][k]
    push!(alpha_d,k=>val)
end

for k in keys(x_set)
    val = blueNOTE[:xn0][k] / blueNOTE[:s0][k]
    push!(alpha_n,k=>val)
end

for k in keys(a_set)
    val = blueNOTE[:nd0][k] / (blueNOTE[:nd0][k] + blueNOTE[:dd0][k])
    push!(theta_n,k=>val)
end

#!!!! not sure on a_set here
for k in keys(a_set)
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

@variable(cge,Y[regions,sectors]>=eps,start=1)
@variable(cge,X[regions,goods]>=eps,start=1) # Disposition
@variable(cge,A[regions,goods]>=eps,start=1) # Absorption
@variable(cge,C[regions]>=eps,start=1) # Aggregate final demand
@variable(cge,MS[regions,margins]>=eps,start=1) # Margin supply

#commodities:
@variable(cge,PA[regions,goods]>=eps,start=1) # Regional market (input)
@variable(cge,PY[regions,goods]>=eps,start=1) # Regional market (output)
@variable(cge,PD[regions,goods]>=eps,start=1) # Local market price
@variable(cge,PN[goods]>=eps,start=1) # National market
@variable(cge,PL[regions]>=eps,start=1) # Wage rate
@variable(cge,PK[regions,sectors]>=eps,start=1) # Rental rate of capital
@variable(cge,PM[regions,margins]>=eps,start=1) # Margin price
@variable(cge,PC[regions]>=eps,start=1) # Consumer price index
@variable(cge,PFX>=eps,start=1) # Foreign exchange

#consumer:
@variable(cge,RA[r in regions]>=eps,start=blueNOTE[:c0][(r,)]) # Representative agent



###############################
# -- PLACEHOLDER VARIABLES --
###############################

@NLexpression(cge,CVA[r in regions,s in sectors; haskey(y_set,(r,s))],
  PL[r]^alpha_kl[r,s] * PK[r,s] ^(1-alpha_kl[r,s]) );

@NLexpression(cge,AL[r in regions,s in sectors; haskey(y_set,(r,s))],
  blueNOTE[:ld0][r,s] * CVA[r,s] / PL[r] );

@NLexpression(cge,AK[r in regions,s in sectors; haskey(y_set,(r,s))],
  blueNOTE[:kd0][r,s] * CVA[r,s] / PK[r,s] );

  ###

@NLexpression(cge,RX[r in regions,g in goods; haskey(x_set,(r,g))],
  (alpha_x[r,g]*PFX^5+alpha_n[r,g]*PN[g]^5+alpha_d[r,g]*PD[r,g]^5)^(1/5) );

@NLexpression(cge,AX[r in regions,g in goods; haskey(x_set,(r,g))],
  (blueNOTE[:x0][r,g] - blueNOTE[:rx0][r,g])*(PFX/RX[r,g])^4 );

@NLexpression(cge,AN[r in regions,g in goods; haskey(x_set,(r,g))],
  blueNOTE[:xn0][r,g]*(PN[g]/RX[r,g])^4 );

@NLexpression(cge,AD[r in regions,g in goods; haskey(x_set,(r,g))],
  blueNOTE[:xd0][r,g]*(PD[r,g]/RX[r,g])^4 );

  ###

@NLexpression(cge,CDN[r in regions,g in goods; haskey(a_set,(r,g))],
  (theta_n[r,g]*PN[g]^(1-2)+(1-theta_n[r,g])*PD[r,g]^(1-2))^(1/(1-2)) );

#!!!! here replaced first :tm with :tm0
@NLexpression(cge,CDM[r in regions,g in goods; haskey(a_set,(r,g))],
  ((1-theta_m[r,g])*CDN[r,g]^(1-4)+theta_m[r,g]*
  (PFX*(1+blueNOTE[:tm0][r,g])/(1+blueNOTE[:tm0][r,g]))^(1-4))^(1/(1-4)) 
  );

  ###

@NLexpression(cge,DN[r in regions,g in goods; haskey(a_set,(r,g))],
  blueNOTE[:nd0][r,g]*(CDN[r,g]/PN[g])^2*(CDM[r,g]/CDN[r,g])^4 );

@NLexpression(cge,DD[r in regions,g in goods; haskey(a_set,(r,g))],
  blueNOTE[:dd0][r,g]*(CDN[r,g]/PD[r,g])^2*(CDM[r,g]/CDN[r,g])^4 );

@NLexpression(cge,MD[r in regions,g in goods; haskey(a_set,(r,g))],
  blueNOTE[:m0][r,g]*(CDM[r,g]*(1+blueNOTE[:tm0][r,g])/(PFX*(1+blueNOTE[:tm0][r,g])))^4 );

@NLexpression(cge,CD[r in regions,g in goods; haskey(a_set,(r,g))],
  blueNOTE[:cd0][r,g]*PC[r] / PA[r,g] );

###############################
# -- Zero Profit Conditions --
###############################

#y_set here is equivalent to the $y_(r,s) in the blueNOTE model
@mapping(cge,profit_y[r in regions,s in sectors; haskey(y_set,(r,s)) ],
                sum(PA[r,g] * blueNOTE[:id0][r,g,s] for g in goods if haskey(blueNOTE[:id0],(r,g,s)) )
                + PL[r] * AL[r,s]
                + PK[r,s] * AK[r,s]
                == 
                sum(PY[r,g] * blueNOTE[:ys0][r,s,g] for g in goods if haskey(blueNOTE[:ys0],(r,s,g)) )
);

@mapping(cge,profit_x[r in regions,g in goods; haskey(x_set,(r,g)) ],
                  PY[r,g] * blueNOTE[:s0][r,g] 
                  == 
                  PFX * AX[r,g]
                + PN[g] * AN[r,g]
                + PD[r,g] * AD[r,g]
);

@mapping(cge,profit_a[r in regions,g in goods; haskey(a_set,(r,g)) ],
                  PY[r,g] * blueNOTE[:s0][r,g] 
                  == 
                  PFX * AX[r,g]
                + PN[g] * AN[r,g]
                + PD[r,g] * AD[r,g]
);

@mapping(cge,profit_c[r in regions],
                  sum(PA[r,g] * CD[r,g] for g in goods if haskey(a_set,(r,g)))
                  ==
                  PC[r] * blueNOTE[:c0][(r,)]
);

@mapping(cge,profit_ms[r in regions, m in margins],
    sum(PN[gm]   * blueNOTE[:nm0][r,m,gm] for gm in goods_margins if haskey(blueNOTE[:nm0],(r,m,gm)) )
  + sum(PD[r,gm] * blueNOTE[:dm0][r,m,gm] for gm in goods_margins if haskey(blueNOTE[:dm0],(r,m,gm)) )
  == 
  PM[r,m] * sum(blueNOTE[:md0][r,m,gm] for gm in goods_margins if haskey(blueNOTE[:md0],(r,m,gm)) )
);


###################################
# -- Market Clearing Conditions -- 
###################################

@mapping(cge,market_pa[r in regions, g in goods; haskey(a_set,(r,g))],
        A[r,g] * blueNOTE[:a0][r,g] 
        == 
        blueNOTE[:g0][r,g] 
      + blueNOTE[:i0][r,g]
      + C[r] * CD[r,g]
      + sum(Y[r,s] * blueNOTE[:id0][r,g,s] for s in sectors if haskey(blueNOTE[:id0],(r,g,s)))
);


@mapping(cge,market_py[r in regions, g in goods; haskey(y_set,(r,g))],
        sum(Y[r,s] * blueNOTE[:ys0][r,s,g] for s in sectors if haskey(blueNOTE[:ys0],(r,s,g)))
      + blueNOTE[:yh0][r,g]
        ==
        X[r,g] * blueNOTE[:s0][r,g]
);

@mapping(cge,market_pd[r in regions, g in goods; haskey(pd_set,(r,g))],
        X[r,g] * AD[r,g] 
        == 
        A[r,g] * DD[r,g]
      + sum(MS[r,m] * blueNOTE[:dm0][r,m,g] for m in margins if (g in goods_margins && haskey(blueNOTE[:dm0],(r,m,g))) )  
);

@mapping(cge,market_pn[g in goods],
        sum(X[r,g] * AN[r,g] for r in regions if haskey(x_set,(r,g)))
        == 
        sum(A[r,g] * DN[r,g] for r in regions if haskey(a_set,(r,g)))
        + sum(MS[r,m] * blueNOTE[:nm0][r,m,g] for r in regions for m in margins if (g in goods_margins && haskey(blueNOTE[:nm0],(r,m,g))) )
);

@mapping(cge,market_pl[r in regions],
        sum(blueNOTE[:ld0][r,s] for s in sectors if haskey(blueNOTE[:ld0],(r,s)))
        == 
        sum(Y[r,s] * AL[r,s] for s in sectors if haskey(y_set,(r,s)))
);

@mapping(cge,market_pk[r in regions, s in sectors; haskey(blueNOTE[:kd0],(r,s))],
        blueNOTE[:kd0][r,s]
        == 
        Y[r,s] * AK[r,s]
);

@mapping(cge,market_pm[r in regions, m in margins],
        MS[r,m] * sum(blueNOTE[:md0][r,m,gm] for gm in goods_margins if haskey(blueNOTE[:md0],(r,m,gm)))
        ==
        sum(A[r,g] * blueNOTE[:md0][r,m,g] for g in goods if haskey(blueNOTE[:md0],(r,m,g)))
);

@mapping(cge,market_pc[r in regions],
        C[r] * blueNOTE[:c0][(r,)] == RA[r] / PC[r]
);

@mapping(cge,market_pfx,
#will fix the reference here...
        sum(blueNOTE[:bopdef0][(r,)] for r in regions)
#!!!! not sure if haskey needed here...        
#        + sum(X[r,g] * AX[r,g] for r in regions for g in goods if haskey(x_set,(r,g)))
        + sum(X[r,g] * AX[r,g] for r in regions for g in goods)
        + sum(A[r,g] * blueNOTE[:x0][r,g] for r in regions for g in goods if haskey(a_set,(r,g)))
        ==
        sum(A[r,g] * MD[r,g] for r in regions for g in goods)
        );

@mapping(cge,income_ra[r in regions],
        RA[r] == 
        sum(PY[r,g]*blueNOTE[:yh0][r,g] for g in goods if haskey(blueNOTE[:yh0],(r,g)))
#will fix reference here...        
        + PFX * (blueNOTE[:bopdef0][(r,)] + blueNOTE[:hhadj][(r,)])
        - sum(PA[r,g] * (blueNOTE[:g0][r,g] + blueNOTE[:i0][r,g]) for g in goods)
        + PL[r] * sum(blueNOTE[:ld0][r,s] for s in sectors if haskey(blueNOTE[:ld0],(r,s)) )
        + sum(PK[r,s] * blueNOTE[:kd0][r,s] for s in sectors if haskey(blueNOTE[:kd0],(r,s)) )
#changed tm to tm0 here...        
        + sum(A[r,g] * MD[r,g]* PFX * blueNOTE[:tm0][r,g] for g in goods if haskey(a_set,(r,g)) )
#change ta to ta0 here
        + sum(A[r,g] * blueNOTE[:a0][r,g]*PA[r,g]*blueNOTE[:ta0][r,g] for g in goods if haskey(a_set,(r,g)) )
);


####################################
# -- Complementarity Conditions --
####################################

# equations with conditions cannot be paired 
# see workaround here: https://github.com/chkwon/Complementarity.jl/issues/37

[@complementarity(cge,profit_y[r,s],Y[r,s]) for r in regions for s in sectors if haskey(y_set,(r,s)) ];
[@complementarity(cge,profit_x[r,g],X[r,g]) for r in regions for g in goods if haskey(x_set,(r,g)) ];
[@complementarity(cge,profit_a[r,g],A[r,g]) for r in regions for g in goods if haskey(a_set,(r,g)) ];
@complementarity(cge,profit_c,C);
@complementarity(cge,profit_ms,MS);
[@complementarity(cge,market_pa[r,g],PA[r,g]) for r in regions for g in goods if haskey(a_set,(r,g)) ];
[@complementarity(cge,market_py[r,g],PY[r,g]) for r in regions for g in goods if haskey(y_set,(r,g)) ];
[@complementarity(cge,market_pd[r,g],PD[r,g]) for r in regions for g in goods if haskey(pd_set,(r,g)) ];
@complementarity(cge,market_pn,PN);
@complementarity(cge,market_pl,PL);
[@complementarity(cge,market_pk[r,s],PK[r,s]) for r in regions for s in sectors if haskey(blueNOTE[:kd0],(r,s)) ];
@complementarity(cge,market_pm,PM);
@complementarity(cge,market_pc,PC);
@complementarity(cge,market_pfx,PFX);
@complementarity(cge,income_ra,RA);

[fix(PK[r,s],1,force=true) for r in regions for s in sectors if !(haskey(blueNOTE[:kd0],(r,s)))];
[fix(PA[r,g],1,force=true) for r in regions for g in goods if !(haskey(blueNOTE[:a0],(r,g)))];
[fix(PY[r,g],1,force=true) for r in regions for g in goods if !(haskey(blueNOTE[:s0],(r,g)))];
[fix(PY[r,g],1,force=true) for r in regions for g in goods if !(haskey(blueNOTE[:xd0],(r,g)))];


PATHSolver.options(convergence_tolerance=1e-8, output=:yes, time_limit=3600)
status = solveMCP(cge)
