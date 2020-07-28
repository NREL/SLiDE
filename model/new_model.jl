using SLiDE
using CSV
using JuMP
using Complementarity
using DataFrames

mod_year = 2016
end_year = 2018
years = mod_year:end_year
years_last = maximum(years)

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
        #Comments: its better to skip creating this massive dict and store all the parameters individual so you dont pass this around
                # - Next stpe to build struct would be to group data according to sectors or regions
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
regions = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_r.csv"),descriptor="region set"))[!,:Dim1]);
sectors = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_s.csv"),descriptor="sector set"))[!,:Dim1]);
goods = sectors;
# margins = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_m.csv"),descriptor="margin set"))[!,:Dim1]);
margins = convert(Vector{String}, CSV.read("./model/data_temp/set_m.csv").Dim1)
goods_margins = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_gm.csv"),descriptor="goods with margins set"))[!,:g]);

#need to have both benchmark and counterfactual tax rates
#more important here is the distinction between tm and tm0
#since the ratio of the two is used in the calculation of 
#the value share - good to be clear on ta as well though
blueNOTE[:tm] = blueNOTE[:tm0];
blueNOTE[:ta] = blueNOTE[:ta0];
blueNOTE[:ty] = blueNOTE[:ty0];

#following subsets are used to limit the size of the model
# the a_set restricts the A and PA variables indices to those
# with positive armington supply or re-exports
a_set = Dict();
[a_set[r,g] = get(blueNOTE[:a0], (r,g), 0) + get(blueNOTE[:rx0], (r,g), 0) for r in regions for g in goods];

# y_check is used to make sure the r/s combination 
# has a reference amount of sectoral supply
y_check = Dict();
[y_check[r,s] = sum(get(blueNOTE[:ys0], (r,s,g), 0 ) for g in goods) for r in regions for s in sectors];

########## Model ##########
cge = MCPModel();

##############
# PARAMETERS
##############

@NLparameter(cge, alpha_kl[ i in keys(blueNOTE[:ld0])] ==  (blueNOTE[:ld0][i] + blueNOTE[:kd0][i]) / blueNOTE[:ld0][i]);
@NLparameter(cge, alpha_x[ i in keys(blueNOTE[:x0])] == (blueNOTE[:x0][i] - get(blueNOTE[:rx0], i, 0)) / blueNOTE[:s0][i]);
@NLparameter(cge, alpha_d[ i in keys(blueNOTE[:xd0])] ==  blueNOTE[:xd0][i] / blueNOTE[:s0][i]);
@NLparameter(cge, alpha_n[ i in keys(blueNOTE[:xn0])] ==  blueNOTE[:xn0][i]/blueNOTE[:s0][i]);
@NLparameter(cge, theta_n[ i in keys(blueNOTE[:nd0])] ==  blueNOTE[:nd0][i]/(blueNOTE[:nd0][i] -  get(blueNOTE[:dd0], i, 0)));
@NLparameter(cge, theta_m[ i in keys(blueNOTE[:tm0])] ==  (blueNOTE[:tm0][i] * get(blueNOTE[:m0], i, 0)) / (get(blueNOTE[:nd0], i, 0) +  get(blueNOTE[:dd0], i, 0) + (1+blueNOTE[:tm0][i]) * get(blueNOTE[:m0], i, 0) ));

##################
# -- VARIABLES -- 
##################

sv = 0.00

#sectors
@variable(cge,Y[r in regions, s in sectors, t in years]>=sv,start=1);
@variable(cge,X[r in regions, g in goods, t in years]>=sv,start=1);
@variable(cge,A[r in regions, g in goods, t in years]>=sv,start=1);
@variable(cge,C[r in regions, t in years]>=sv,start=1);
@variable(cge,MS[r in regions, m in margins, t in years]>=sv,start=1);

sub_set_rst = filter(x-> haskey(blueNOTE[:kd0], (x[1],x[2])), combvec(regions, sectors, years));
@variable(cge,K[(r,s,t) in sub_set_rst]>=sv,start=blueNOTE[:kd0][r,s]);
@variable(cge,I[(r,s,t) in sub_set_rst]>=sv,start=(delta * blueNOTE[:kd0][r,s]));

#commodities:
@variable(cge,PA[r in regions, g in goods, t in years]>=sv,start=pvm[t]); # Regional market (input)
@variable(cge,PY[r in regions, g in goods, t in years]>=sv,start=pvm[t]); # Regional market (output)
@variable(cge,PD[r in regions, g in goods, t in years]>=sv,start=pvm[t]); # Local market price
@variable(cge,PN[g in goods, t in years]>=sv,start=pvm[t]); # National market
@variable(cge,PL[r in regions, t in years]>=sv,start=pvm[t]); # Wage rate
@variable(cge,PK[r in regions, s in sectors, t in years]>=sv,start=pvm[t] * (1+i)); # Rental rate of capital ###
@variable(cge,RK[r in regions, s in sectors, t in years]>=sv,start=pvm[t] * rk0); # Capital return rate ###
sub_set_rs = filter(x-> haskey(blueNOTE[:kd0], (x[1],x[2])), combvec(regions, sectors));
@variable(cge,TK[(r,s) in sub_set_rs]>=sv,start=blueNOTE[:kd0][r,s]); ### Terminal capital amount
@variable(cge,PKT[r in regions, s in sectors]>=sv,start=pvm[years_last]); # Terminal capital cost
@variable(cge,PM[r in regions, m in margins, t in years] >=sv,start=pvm[t]); # Margin price
@variable(cge,PC[r in regions, t in years]>=sv,start=pvm[t]); # Consumer price index #####
@variable(cge,PFX[t in years]>=sv,start=pvm[t]); # Foreign exchange

#consumer:
@variable(cge,RA[r in regions, t in years]>=sv,start = pvm[t] * blueNOTE[:c0][(r,)]); # Representative agent

###############################
# -- PLACEHOLDER VARIABLES --
###############################

#cobb-douglas function for value added (VA) ######
@NLexpression(cge,CVA[r in regions,s in sectors,t in years; haskey(alpha_kl.lookup[1], (r,s)) ],
  PL[r,t]^alpha_kl[(r,s)] * (RK[r,s,t] / rk0) ^ (1-alpha_kl[(r,s)]) );

#demand for labor in VA
@NLexpression(cge,AL[r in regions, s in sectors, t in years; haskey(blueNOTE[:ld0], (r,s)) ],
blueNOTE[:ld0][r,s] * CVA[r,s,t] / PL[r,t] );

#demand for capital in VA ######
@NLexpression(cge,AK[r in regions,s in sectors, t in years; haskey(blueNOTE[:kd0], (r,s)) ],
  blueNOTE[:kd0][r,s] * CVA[r,s,t] / (RK[r,s,t] / rk0) );

#CES function for output demand - including
# exports (absent of re-exports) times the price for foreign exchange, 
# region's supply to national market times the national market price
# regional supply to local market times domestic price
@NLexpression(cge,RX[r in regions,g in goods, t in years; haskey(alpha_n.lookup[1], (r,g)) && haskey(alpha_x.lookup[1], (r,g)) && haskey(alpha_d.lookup[1], (r,g))], 
  (alpha_x[(r,g)] * PFX[t]^5 + alpha_n[(r,g)] * PN[g,t]^5 + alpha_d[(r,g)] * PD[r,g,t]^5)^(1/5) );

#demand for exports via demand function
@NLexpression(cge,AX[r in regions,g in goods, t in years;  haskey(RX, (r,g,t)) ],
  (blueNOTE[:x0][r,g] - (haskey(blueNOTE[:rx0], (r,g)) ? blueNOTE[:rx0][r,g] : 0.0)) * (PFX[t]/RX[r,g,t])^4 );

#demand for contribution to national market 
@NLexpression(cge,AN[r in regions,g in goods, t in years; haskey(blueNOTE[:xn0], (r,g)) && haskey(RX, (r,g,t)) ],
  blueNOTE[:xn0][r,g]*(PN[g,t]/(RX[r,g,t]))^4 );

#demand for regionals supply to local market
@NLexpression(cge,AD[r in regions,g in goods, t in years; haskey(blueNOTE[:xd0], (r,g)) && haskey(RX, (r,g,t)) ], 
        blueNOTE[:xd0][r,g] * (PD[r,g,t] / (RX[r,g,t]))^4 );

# CES function for tradeoff between national and domestic market
@NLexpression(cge,CDN[r in regions,g in goods, t in years; haskey(theta_n.lookup[1], (r,g))],
  (theta_n[(r,g)]*PN[g,t]^(1-2)+(1-theta_n[(r,g)])*PD[r,g,t]^(1-2))^(1/(1-2)) );

# CES function for tradeoff between domestic consumption and foreign exports
# recall tm in the import tariff thus tm / tm0 is the relative change in import tariff rates
@NLexpression(cge,CDM[r in regions,g in goods, t in years;haskey(theta_m.lookup[1], (r,g)) && haskey(CDN, (r,g,t)) ],
  ((1-theta_m[(r,g)])*CDN[r,g,t]^(1-4)+theta_m[(r,g)]*
  (PFX[t]*(1+blueNOTE[:tm][r,g])/(1+blueNOTE[:tm0][r,g]))^(1-4))^(1/(1-4)) 
  );

# regions demand from the national market <- note nesting of CDN in CDM
@NLexpression(cge,DN[r in regions,g in goods, t in years;  haskey(CDN, (r,g,t)) && haskey(CDM, (r,g,t))],
  blueNOTE[:nd0][r,g]*(CDN[r,g,t]/PN[g,t])^2*(CDM[r,g,t]/CDN[r,g,t])^4 );

# region demand from local market <- note nesting of CDN in CDM
@NLexpression(cge,DD[r in regions,g in goods, t in years;haskey(blueNOTE[:dd0], (r,g)) && haskey(CDM, (r,g,t)) ],
  blueNOTE[:dd0][r,g]*(CDN[r,g,t]/PD[r,g,t])^2*(CDM[r,g,t]/CDN[r,g,t])^4 );

# import demand
@NLexpression(cge,MD[r in regions,g in goods, t in years; haskey(blueNOTE[:m0], (r,g)) && haskey(CDM, (r,g,t)) ],
  blueNOTE[:m0][r,g]*(CDM[r,g,t]*(1+blueNOTE[:tm][r,g])/(PFX[t]*(1+blueNOTE[:tm0][r,g])))^4 );

# final demand
@NLexpression(cge,CD[r in regions,g in goods, t in years; haskey(blueNOTE[:cd0], (r,g)) ],
  blueNOTE[:cd0][r,g]*PC[r,t] / PA[r,g,t] );

###############################
# -- Zero Profit Conditions --
###############################

@NLexpression(cge,profit_y[r in regions,s in sectors, t in years],
# cost of intermediate demand
        sum(PA[r,g,t] * blueNOTE[:id0][r,g,s] for g in goods if haskey(blueNOTE[:id0], (r,g,s)) ) 
# cost of labor inputs
        +  PL[r,t] * (haskey(AL, (r,s,t)) ? AL[r,s,t] : 0.0 )
# cost of capital inputs 
        + (RK[r,s,t] / rk0) * (haskey(AK, (r,s,t)) ? AK[r,s,t] : 0.0 )
        - 
# revenue from sectoral supply (take note of r/s/g indices on ys0)                
        sum(PY[r,g,t] * blueNOTE[:ys0][r,s,g] for g in goods if haskey(blueNOTE[:ys0], (r,s, g)) ) * (1-(haskey(blueNOTE[:ty], (r,s)) ? blueNOTE[:ty][r,s] : 0.0))
);

@NLexpression(cge,profit_x[r in regions,g in goods, t in years],
# output 'cost' from aggregate supply
        PY[r,g,t] * blueNOTE[:s0][r,g] 
        - (
# revenues from foreign exchange
        PFX[t] * (haskey(AX, (r,g,t)) ? AX[r,g,t] : 0.0 )
# revenues from national market                  
        + PN[g,t] * (haskey(AN, (r,g,t)) ? AN[r,g,t] : 0.0 )
# revenues from domestic market
        + PD[r,g,t] * (haskey(AD, (r,g,t)) ? AD[r,g,t] : 0.0 )
        )
);

@NLexpression(cge,profit_a[r in regions,g in goods, t in years],
# costs from national market
        PN[g,t] * (haskey(DN, (r,g,t)) ? DN[r,g,t] : 0.0) 
# costs from domestic market                  
        + PD[r,g,t] * (haskey(DD, (r,g,t)) ? DD[r,g,t] : 0.0) 
# costs from imports, including import tariff
        + PFX[t] * 
        (1 + (haskey(blueNOTE[:tm], (r,g)) ? blueNOTE[:tm][r,g] : 0.0)) 
        * (haskey(MD, (r,g,t)) ? MD[r,g,t] : 0.0)
# costs of margin demand                
        + sum(PM[r,m,t] * blueNOTE[:md0][r,m,g] for m in margins if haskey(blueNOTE[:md0], (r,m,g)))
        - ( 
# revenues from regional market based on armington supply               
        PA[r,g,t] * (1-(haskey(blueNOTE[:ta], (r,g)) ? blueNOTE[:ta][r,g] : 0.0)) * (haskey(blueNOTE[:a0], (r,g)) ? blueNOTE[:a0][r,g] : 0.0) 
# revenues from re-exports                   
        + PFX[t] * (haskey(blueNOTE[:rx0], (r,g)) ? blueNOTE[:rx0][r,g] : 0.0)
        )
);

@NLexpression(cge,profit_c[r in regions, t in years],
# costs of inputs - computed as final demand times regional market prices
        sum(PA[r,g,t] * CD[r,g,t] for g in goods if haskey(CD, (r,g,t)) ) 
        - 
# revenues/benefit computed as CPI * reference consumption                  
        PC[r,t] * blueNOTE[:c0][(r,)]
);

@NLexpression(cge,profit_k[(r, s,t) in combvec(regions, sectors, years)],
        PK[r,s,t] 
        - (
        RK[r,s,t]
        + (1-delta) * (t!=years_last ? PK[r,s,t+1] : PKT[r,s])
        )
);

@NLexpression(cge,profit_i[(r, s,t) in combvec(regions, sectors, years)],
        PY[r,s,t] 
        - 
        (t!=years_last ? PK[r,s,t+1] : PKT[r,s])
);

@NLexpression(cge,profit_ms[r in regions, m in margins, t in years],
# provision of margins to national market
        sum(PN[gm,t]   * blueNOTE[:nm0][r,gm,m] for gm in goods_margins if haskey(blueNOTE[:nm0], (r,gm,m)) )
# provision of margins to domestic market    
        + sum(PD[r,gm,t] * blueNOTE[:dm0][r,gm,m] for gm in goods_margins if haskey(blueNOTE[:dm0], (r,gm,m)) ) 
# total margin demand    
        - PM[r,m,t] * sum(blueNOTE[:md0][r,m,gm] for gm in goods_margins if haskey(blueNOTE[:md0], (r,m,gm)) )
);

###################################
# -- Market Clearing Conditions -- 
###################################

@NLexpression(cge, market_pa[r in regions, g in goods, t in years],
# absorption or supply
        A[r,g,t] * (haskey(blueNOTE[:a0], (r,g)) ? blueNOTE[:a0][r,g] : 0.)
        - ( 
# government demand (exogenous)       
        (haskey(blueNOTE[:g0], (r,g)) ? blueNOTE[:g0][r,g] : 0.)
# demand for investment (exogenous)
        + (haskey(blueNOTE[:i0], (r,g)) ? blueNOTE[:i0][r,g] : 0.)
# final demand        
        + C[r,t] * (haskey(CD, (r,g,t)) ? CD[r,g,t] : 0.)
# intermediate demand        
        + sum(Y[r,s,t] * blueNOTE[:id0][r,g,s] for s in sectors if (y_check[r,s] > 0) && haskey(blueNOTE[:id0], (r,g,s)) )
        )
);

@NLexpression(cge, market_py[r in regions, g in goods, t in years],
# sectoral supply
        sum(Y[r,s,t] * blueNOTE[:ys0][r,s,g] for s in sectors if haskey(blueNOTE[:ys0], (r,s,g)) )
# household production (exogenous)        
        + (haskey(blueNOTE[:yh0], (r,g)) ? blueNOTE[:yh0][r,g] : 0.)
# aggregate supply (akin to market demand)                
        - X[r,g,t] *  (haskey(blueNOTE[:s0], (r,g)) ? blueNOTE[:s0][r,g] : 0.)
);

@NLexpression(cge,market_pd[r in regions, g in goods, t in years],
# aggregate supply
        X[r,g,t] * (haskey(AD, (r,g,t)) ? AD[r,g,t] : 0.0)
        - ( 
# demand for local market          
        A[r,g,t] * (haskey(DD, (r,g,t)) ? DD[r,g,t] : 0.0)
# margin supply from local market
        + sum(MS[r,m,t] * blueNOTE[:dm0][r,g,m] for m in margins if (g in goods_margins ) && haskey(blueNOTE[:dm0], (r,g,m)) )  
        )
);

@NLexpression(cge,market_pn[g in goods, t in years],
# supply to the national market
        sum(X[r,g,t] * AN[r,g,t] for r in regions if haskey(AN, (r,g,t)))
        - ( 
# demand from the national market 
        sum(A[r,g,t] * DN[r,g,t] for r in regions if haskey(DN, (r,g,t)) )
# market supply to the national market        
        + sum(MS[r,m,t] * blueNOTE[:nm0][r,g,m] for r in regions for m in margins if (g in goods_margins) && haskey(blueNOTE[:nm0], (r,g,m)))
        )
);

@NLexpression(cge,market_pl[r in regions, t in years],
# supply of labor
        sum(blueNOTE[:ld0][r,s] for s in sectors if haskey(blueNOTE[:ld0], (r,s)) ) 
# demand for labor in all sectors        
        - sum(Y[r,s,t] * (haskey(AL, (r,s,t)) ? AL[r,s,t] : 0.0) for s in sectors)
);

@NLexpression(cge,market_pk[r in regions, s in sectors, t in years],
# if first year, initial capital
# else investment plus previous year's decayed capital
        (t==mod_year ? get(blueNOTE[:kd0], (r,s), 0.) : (haskey(I.lookup[1], (r,s,t-1)) ? I[(r,s,t-1)] : 0))
        + (1-delta) * (t>mod_year ? (haskey(K.lookup[1], (r,s,t-1)) ? K[(r,s,t-1)] : 0) : 0) 
#current year's capital capital        
        - (haskey(K.lookup[1], (r,s,t)) ? K[(r,s,t)] : 0) 
);

@NLexpression(cge,market_rk[r in regions, s in sectors, t in years],
        (haskey(K.lookup[1], (r,s,t)) ? K[(r,s,t)] : 0)
        -
        Y[r,s,t] * (haskey(blueNOTE[:kd0], (r,s)) ? blueNOTE[:kd0][r,s] : 0.0) 
        * (haskey(CVA, (r,s,t)) ? CVA[r,s,t] : 0) / (RK[r,s,t] / rk0)
);

#terminal investment constraint
@NLexpression(cge,market_pkt[r in regions, s in sectors],
        (1-delta) * (haskey(K.lookup[1], (r,s,years_last)) ? K[(r,s,years_last)] : 0)
        + (haskey(I.lookup[1], (r,s,years_last)) ? I[(r,s,years_last)] : 0)
        - 
        (haskey(TK.lookup[1], (r,s,years_last)) ? TK[(r,s,years_last)] : 0)
);

@NLexpression(cge,termk[(r,s) in combvec(regions, sectors)],
        (haskey(I.lookup[1], (r,s,years_last)) ? I[(r,s,years_last)] : 0) / ((haskey(I.lookup[1], (r,s,years_last-1)) ? I[(r,s,years_last-1)] : 0) + (haskey(blueNOTE[:kd0], (r,s))==0 ? 1e-6 : 0))
        - 
        Y[r,s,years_last] / Y[r,s,years_last-1]
);

@NLexpression(cge,market_pm[r in regions, m in margins, t in years],
# margin supply 
        MS[r,m,t] * sum(blueNOTE[:md0][r,m,gm] for gm in goods_margins if haskey(blueNOTE[:md0], (r,m,gm)))
        - 
# margin demand        
        sum(A[r,g,t] * blueNOTE[:md0][r,m,g] for g in goods if haskey(blueNOTE[:md0], (r,m,g)) )
);

@NLexpression(cge,market_pfx[t in years],
# balance of payments (exogenous)
        sum(blueNOTE[:bopdef0][(r,)] for r in regions if haskey(blueNOTE[:bopdef0], (r,)) )
# supply of exports     
        + sum(X[r,g,t] * AX[r,g,t] for r in regions for g in goods if haskey(AX, (r,g,t)) )
# supply of re-exports        
        + sum(A[r,g,t] * blueNOTE[:rx0][r,g] for r in regions for g in goods if (a_set[r,g] != 0) && haskey(blueNOTE[:rx0], (r,g)) )
        - 
# import demand                
        sum(A[r,g,t] * MD[r,g,t] for r in regions for g in goods if (a_set[r,g] != 0) && haskey(MD, (r,g,t)))
);

@NLexpression(cge,market_pc[r in regions, t in years],
# a period's final demand
        C[r,t] * (haskey(blueNOTE[:c0], (r,)) ? blueNOTE[:c0][(r,)] : 0.0)
        - 
# consumption / utiltiy        
        RA[r,t] / PC[r,t]
);

@NLexpression(cge,income_ra[r in regions, t in years],
# consumption/utility
        RA[r,t] 
        - 
        (
# labor income        
        PL[r,t] * sum(blueNOTE[:ld0][r,s] for s in sectors if haskey(blueNOTE[:ld0], (r,s)) )
# provision of household supply          
        + sum(PY[r,g,t]*blueNOTE[:yh0][r,g] for g in goods if haskey(blueNOTE[:yh0], (r,g)) )
# revenue or costs of foreign exchange including household adjustment   
        + PFX[t] * (blueNOTE[:bopdef0][(r,)] + blueNOTE[:hhadj][(r,)])
# government and investment provision        
        - sum(PA[r,g,t] * ((haskey(blueNOTE[:g0], (r,g)) ? blueNOTE[:g0][(r,g)] : 0.0) + (haskey(blueNOTE[:i0], (r,g)) ? blueNOTE[:i0][(r,g)] : 0.0) ) for g in goods )
# import taxes - assumes lumpsum recycling
        + sum(A[r,g,t] * MD[r,g,t]* PFX[t] * blueNOTE[:tm][r,g] for g in goods if (a_set[r,g] != 0) && haskey(MD, (r,g,t)) && haskey(blueNOTE[:tm], (r,g)) )
# taxes on intermediate demand - assumes lumpsum recycling
        + sum(A[r,g,t] * blueNOTE[:a0][r,g]*PA[r,g,t]*blueNOTE[:ta][r,g] for g in goods if (a_set[r,g] != 0)  && haskey(blueNOTE[:ta], (r,g)) && haskey(blueNOTE[:a0], (r,g)))
# production taxes - assumes lumpsum recycling  
        + sum(pvm[t] * Y[r,s,t] * blueNOTE[:ys0][r,s,g] * blueNOTE[:ty][r,s] for s in sectors for g in goods if haskey(blueNOTE[:ys0], (r,s,g)) && haskey(blueNOTE[:ty], (r,s)) )
# income from capital
        + (1-bool_lastyear[t]) * sum(PK[r,s,t] * K[(r,s,t)] for s in sectors if haskey(K.lookup[1], (r,s,t)) ) / (1+i)
#cost of terminal year investment
        + bool_lastyear[t] * sum(PKT[r,s] * TK[(r,s)] for s in sectors if haskey(TK.lookup[1], (r,s)) )
        )
);

####################################
# -- Complementarity Conditions --
####################################

# equations with conditions cannot be paired 
# see workaround here: https://github.com/chkwon/Complementarity.jl/issues/37
[fix(PK[r,s,t],1;force=true) for r in regions for s in sectors for t in years if !(blueNOTE[:kd0][r,s] > 0)]
[fix(RK[r,s,t],1;force=true) for r in regions for s in sectors for t in years if !(blueNOTE[:kd0][r,s] > 0)]
[fix(PY[r,g,t],1,force=true) for r in regions for g in goods for t in years if !(y_check[r,g]>0)]
[fix(PA[r,g,t],1,force=true) for r in regions for g in goods for t in years if !(blueNOTE[:a0][r,g]>0)]
[fix(PD[r,g,t],1,force=true) for r in regions for g in goods for t in years if (blueNOTE[:xd0][r,g] == 0)]
[fix(Y[r,s,t],1,force=true) for r in regions for s in sectors for t in years if !(y_check[r,s] > 0)]
[fix(X[r,g,t],1,force=true) for r in regions for g in goods for t in years if !(blueNOTE[:s0][r,g] > 0)]
[fix(A[r,g,t],1,force=true) for r in regions for g in goods for t in years if (a_set[r,g] == 0)]
[fix(K[r,s,t],0;force=true) for r in regions for s in sectors for t in years if !(blueNOTE[:kd0][r,s] > 0)]
[fix(I[r,s,t],1e-5;force=true) for r in regions for s in sectors for t in years if !(blueNOTE[:kd0][r,s] > 0)]

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
@complementarity(cge,market_pkt,PKT);
@complementarity(cge,termk,TK);
@complementarity(cge,profit_k,K);
@complementarity(cge,profit_i,I);



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
