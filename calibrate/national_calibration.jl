

################################################
# 
# Calibration exercise to create balanced SAM
#
################################################


using SLiDE
using CSV
using JuMP
using DataFrames
using Ipopt


# -- Functions

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
  
  function fill_zero(source::Vector, tofill::Dict)
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
  
  function df_to_dict(df::DataFrame,remove_column::Symbol,value_column::Symbol)
    colnames = setdiff(names(df),[value_column,remove_column])
    if length(colnames) == 1 
        return Dict((row[colnames]...)=>row[:Val] for row in eachrow(df))
    end 

    if length(colnames) > 1 
        return Dict(tuple(row[colnames]...)=>row[:Val] for row in eachrow(df))
    end 

    
  end
  

##################
# -- Load Data --
##################

data_temp_dir = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "calibrate", "data_temp"))

mod_year = 2016


cal = Dict(
    :y0 => df_to_dict(read_data_temp("y0",mod_year,data_temp_dir,"Gross output"),:yr,:Val),
    :ys0 => df_to_dict(read_data_temp("ys0",mod_year,data_temp_dir,"Sectoral supply"),:yr,:Val),
    :fs0 => df_to_dict(read_data_temp("fs0",mod_year,data_temp_dir,"Household supply"),:yr,:Val),
    :id0 => df_to_dict(read_data_temp("id0",mod_year,data_temp_dir,"Intermediate demand"),:yr,:Val),
    :fd0 => df_to_dict(read_data_temp("fd0",mod_year,data_temp_dir,"Final demand"),:yr,:Val),
    :va0 => df_to_dict(read_data_temp("va0",mod_year,data_temp_dir,"Value added"),:yr,:Val),
    :m0 => df_to_dict(read_data_temp("m0",mod_year,data_temp_dir,"Imports"),:yr,:Val),
    :x0 => df_to_dict(read_data_temp("x0",mod_year,data_temp_dir,"Exports of goods and services"),:yr,:Val),
    :ms0 => df_to_dict(read_data_temp("ms0",mod_year,data_temp_dir,"Margin supply"),:yr,:Val),
    :md0 => df_to_dict(read_data_temp("md0",mod_year,data_temp_dir,"Margin demand"),:yr,:Val),
    :a0 => df_to_dict(read_data_temp("a0",mod_year,data_temp_dir,"Armington supply"),:yr,:Val),
    :ta0 => df_to_dict(read_data_temp("ta0",mod_year,data_temp_dir,"Tax net subsidy rate on intermediate demand"),:yr,:Val),
    :tm0 => df_to_dict(read_data_temp("tm0",mod_year,data_temp_dir,"Import tariff"),:yr,:Val)
)

fd_set = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_fd.csv"),descriptor="fd set"))[!,:Dim1]);
i_set = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_i.csv"),descriptor="i set"))[!,:Dim1]);
j_set = i_set
ts_set = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_ts.csv"),descriptor="ts set"))[!,:Dim1]);
va_set = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_va.csv"),descriptor="va set"))[!,:Dim1]);
m_set = convert(Vector{String},SLiDE.read_file(data_temp_dir,CSVInput(name=string("set_m.csv"),descriptor="m set"))[!,:Dim1]);


calib = Model(with_optimizer(Ipopt.Optimizer))

@variable(calib,ys0_est[j in j_set,i in i_set]>=0);
@variable(calib,fs0_est[i in i_set]>=0);
@variable(calib,ms0_est[i in i_set,m in m_set]>=0);
@variable(calib,y0_est[i in i_set]>=0);
@variable(calib,id0_est[i in i_set,j in j_set]>=0);
@variable(calib,fd0_est[i in i_set,fd in fd_set]>=0);
@variable(calib,va0_est[va in va_set,j in j_set]>=0);
@variable(calib,a0_est[i in i_set]>=0);
@variable(calib,x0_est[i in i_set]>=0);
@variable(calib,m0_est[i in i_set]>=0);
@variable(calib,md0_est[m in m_set,i in i_set]>=0);

@constraint(calib,mkt_py[i in i_set],
  sum(ys0_est[j,i] for j in j_set) + fs0_est[i] == sum(ms0_est[i,m] for m in m_set) + y0_est[i]
);

@constraint(calib,mkt_pa[i in i_set],
  a0_est[i] == sum(id0_est[i,j] for j in j_set) + sum(fd0_est[i,fd] for fd in fd_set)
);

@constraint(calib,mkt_pm[m in m_set],
  sum(ms0_est[i,m] for i in i_set) == sum(md0_est[m,i] for i in i_set)
);

@constraint(calib,prf_y[j in j_set],
  sum(ys0_est[j,i] for i in i_set) == sum(id0_est[i,j] for i in i_set) + sum(va0_est[va,j] for va in va_set)
);


#fill_zero not working for single dimensions..
for i in i_set
  if haskey(cal[:ta0],i)==false
    push!(cal[:ta0],i=>0)
  end
  if haskey(cal[:tm0],i)==false
    push!(cal[:tm0],i=>0)
  end
end

@constraint(calib,prf_a[i in i_set],
  a0_est[i] * (1-cal[:ta0][i]) + x0_est[i] == y0_est[i] + m0_est[i]*(1+cal[:tm0][i]) + sum(md0_est[m,i] for m in m_set)
);

@objective(calib,Min,
  + sum(abs(cal[:ys0][j,i]) * (ys0_est[j,i] / cal[:ys0][j,i] - 1)^ 2 for i in i_set for j in j_set if haskey(cal[:ys0],(j,i))  )
  + sum(abs(cal[:id0][i,j]) * (id0_est[i,j] /cal[:id0][i,j] - 1)^2 for i in i_set for j in j_set if haskey(cal[:id0],(i,j)) )
  + sum(abs(cal[:fs0][i]) * (fs0_est[i] /cal[:fs0][i] - 1)^2 for i in i_set if haskey(cal[:fs0],i) )
  + sum(abs(cal[:ms0][i,m]) * (ms0_est[i,m] /cal[:ms0][i,m] - 1)^2 for i in i_set for m in m_set if haskey(cal[:ms0],(i,m)) )
  + sum(abs(cal[:y0][i]) * (y0_est[i] /cal[:y0][i] - 1)^2 for i in i_set if haskey(cal[:y0],i) )
  + sum(abs(cal[:fd0][i,fd]) * (fd0_est[i,fd] /cal[:fd0][i,fd] - 1)^2 for i in i_set for fd in fd_set if haskey(cal[:fd0],(i,fd)) )
  + sum(abs(cal[:va0][va,j]) * (va0_est[va,j] /cal[:va0][va,j] - 1)^2 for va in va_set for j in j_set if haskey(cal[:va0],(va,j)) )
  + sum(abs(cal[:a0][i]) * (a0_est[i] /cal[:a0][i] - 1)^2  for i in i_set if haskey(cal[:a0],(i)) )
  + sum(abs(cal[:x0][i]) * (x0_est[i] /cal[:x0][i] - 1)^2  for i in i_set if haskey(cal[:x0],i) )
  + sum(abs(cal[:m0][i]) * (m0_est[i] /cal[:m0][i] - 1)^2  for i in i_set if haskey(cal[:m0],i) )
  + sum(abs(cal[:md0][m,i]) * (md0_est[m,i] /cal[:md0][m,i] - 1)^2 for m in m_set for i in i_set if haskey(cal[:md0],(m,i)) ) 

+ 1e7 * (
  + sum(ys0_est[j,i] for i in i_set for j in j_set if !haskey(cal[:ys0],(j,i)) )
  + sum(id0_est[i,j]  for i in i_set for j in j_set if !haskey(cal[:id0],(i,j)) )
  + sum(fs0_est[i]  for i in i_set if !haskey(cal[:fs0],i) )
  + sum(ms0_est[i,m]  for i in i_set for m in m_set if !haskey(cal[:ms0],(i,m)) )
  + sum(y0_est[i] for i in i_set if !haskey(cal[:y0],i) )
  + sum(fd0_est[i,fd] for i in i_set for fd in fd_set if !haskey(cal[:fd0],(i,fd)) )
  + sum(va0_est[va,j] for va in va_set for j in j_set if !haskey(cal[:va0],(va,j)) )
  + sum(a0_est[i] for i in i_set if !haskey(cal[:a0],(i)) )
  + sum(x0_est[i] for i in i_set if !haskey(cal[:x0],i) )
  + sum(m0_est[i] for i in i_set if !haskey(cal[:m0],i) )
  + sum(md0_est[m,i]  for m in m_set for i in i_set if !haskey(cal[:md0],(m,i)) ) 
  )
);

[set_start_value(ys0_est[j,i],cal[:ys0][j,i]) for i in i_set for j in j_set if haskey(cal[:ys0],(j,i)) ] ;
[set_start_value(id0_est[i,j],cal[:id0][i,j]) for i in i_set for j in j_set if haskey(cal[:id0],(i,j)) ] ;
[set_start_value(fs0_est[i],cal[:fs0][i]) for i in i_set if haskey(cal[:fs0],i) ];
[set_start_value(ms0_est[i,m],cal[:ms0][i,m]) for i in i_set for m in m_set if haskey(cal[:ms0],(i,m)) ];
[set_start_value(y0_est[i],cal[:y0][i]) for i in i_set if haskey(cal[:y0],i) ];
[set_start_value(fd0_est[i,fd],cal[:fd0][i,fd]) for i in i_set for fd in fd_set if haskey(cal[:fd0],(i,fd)) ];
[set_start_value(va0_est[va,j],cal[:va0][va,j]) for va in va_set for j in j_set if haskey(cal[:va0],(va,j)) ];
[set_start_value(a0_est[i],cal[:a0][i]) for i in i_set if haskey(cal[:a0],(i)) ];
[set_start_value(x0_est[i],cal[:x0][i]) for i in i_set if haskey(cal[:x0],i) ];
[set_start_value(m0_est[i],cal[:m0][i]) for i in i_set if haskey(cal[:m0],i) ];
[set_start_value(md0_est[m,i],cal[:md0][m,i]) for m in m_set for i in i_set if haskey(cal[:md0],(m,i)) ] ;

[set_lower_bound(ys0_est[j,i],max(0,0.1 * cal[:ys0][j,i] )) for i in i_set for j in j_set if haskey(cal[:ys0],(j,i)) ] ;
[set_lower_bound(id0_est[i,j],max(0,0.1 * cal[:id0][i,j] )) for i in i_set for j in j_set if haskey(cal[:id0],(i,j)) ] ;
[set_lower_bound(fs0_est[i],max(0,0.1 * cal[:fs0][i])) for i in i_set if haskey(cal[:fs0],i) ];
[set_lower_bound(ms0_est[i,m],max(0,0.1 * cal[:ms0][i,m])) for i in i_set for m in m_set if haskey(cal[:ms0],(i,m)) ];
[set_lower_bound(y0_est[i],max(0,0.1 * cal[:y0][i])) for i in i_set if haskey(cal[:y0],i) ];
[set_lower_bound(fd0_est[i,fd],max(0,0.1 * cal[:fd0][i,fd])) for i in i_set for fd in fd_set if haskey(cal[:fd0],(i,fd)) ];
[set_lower_bound(va0_est[va,j],max(0,0.1 * cal[:va0][va,j])) for va in va_set for j in j_set if haskey(cal[:va0],(va,j)) ];
[set_lower_bound(a0_est[i],max(0,0.1 * cal[:a0][i])) for i in i_set if haskey(cal[:a0],(i)) ];
[set_lower_bound(x0_est[i],max(0,0.1 * cal[:x0][i])) for i in i_set if haskey(cal[:x0],i) ];
[set_lower_bound(m0_est[i],max(0,0.1 * cal[:m0][i])) for i in i_set if haskey(cal[:m0],i) ];
[set_lower_bound(md0_est[m,i],max(0,0.1 * cal[:md0][m,i])) for m in m_set for i in i_set if haskey(cal[:md0],(m,i)) ] ;

[set_upper_bound(ys0_est[j,i],abs(5 * cal[:ys0][j,i] )) for i in i_set for j in j_set if haskey(cal[:ys0],(j,i)) ] ;
[set_upper_bound(id0_est[i,j],abs(5 * cal[:id0][i,j] )) for i in i_set for j in j_set if haskey(cal[:id0],(i,j)) ] ;
[set_upper_bound(fs0_est[i],abs(5 * cal[:fs0][i])) for i in i_set if haskey(cal[:fs0],i) ];
[set_upper_bound(ms0_est[i,m],abs(5 * cal[:ms0][i,m])) for i in i_set for m in m_set if haskey(cal[:ms0],(i,m)) ];
[set_upper_bound(y0_est[i],abs(5 * cal[:y0][i])) for i in i_set if haskey(cal[:y0],i) ];
[set_upper_bound(fd0_est[i,fd],abs(5 * cal[:fd0][i,fd])) for i in i_set for fd in fd_set if haskey(cal[:fd0],(i,fd)) ];
[set_upper_bound(va0_est[va,j],abs(5 * cal[:va0][va,j])) for va in va_set for j in j_set if haskey(cal[:va0],(va,j)) ];
[set_upper_bound(a0_est[i],abs(5 * cal[:a0][i])) for i in i_set if haskey(cal[:a0],(i)) ];
[set_upper_bound(x0_est[i],abs(5 * cal[:x0][i])) for i in i_set if haskey(cal[:x0],i) ];
[set_upper_bound(m0_est[i],abs(5 * cal[:m0][i])) for i in i_set if haskey(cal[:m0],i) ];
[set_upper_bound(md0_est[m,i],abs(5 * cal[:md0][m,i])) for m in m_set for i in i_set if haskey(cal[:md0],(m,i)) ] ;

[fix(fs0_est[i],cal[:fs0][i],force=true) for i in i_set if haskey(cal[:fs0],i)];
[fix(fs0_est[i],0,force=true) for i in i_set if !haskey(cal[:fs0],i)];

[fix(va0_est[va,j],cal[:va0][va,j],force=true) for va in va_set for j in j_set if haskey(cal[:va0],(va,j))];
[fix(va0_est[va,j],0,force=true) for va in va_set for j in j_set if !haskey(cal[:va0],(va,j))];

[fix(m0_est[i],cal[:m0][i],force=true) for i in i_set if haskey(cal[:m0],i)];
[fix(m0_est[i],0,force=true) for i in i_set if !haskey(cal[:m0],i)];



JuMP.optimize!(calib)