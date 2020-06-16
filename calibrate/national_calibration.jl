

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
 
  function df_to_dict(df::DataFrame,remove_column::Symbol,value_column::Symbol,year::Int64)
    colnames = setdiff(names(df),[value_column,remove_column])
    #subset on year
    df = df[df[!,:yr].==year,:]
    
    #filter out negative values
    df[df[!,value_column].<0,:value] .= 0
    
    #only want non-zero values
    df = df[df[!,value_column].!=0.0,:]
    
    if length(colnames) == 1 
        return Dict((row[colnames]...)=>row[value_column] for row in eachrow(df))
    end 

    if length(colnames) > 1 
        return Dict(tuple(row[colnames]...)=>row[value_column] for row in eachrow(df))
    end 

    
  end
  
##################
# -- Load Data --
##################

mod_year = 2016;

symbols_calibration = [:y0,:ys0,:fs0,:id0,:fd0,:va0,:m0,:x0,:ms0,:md0,:a0,:ta0,:tm0];

iot = copy(io)
io[:x0] = io[:x0][[:yr,:i,:value]]
io[:m0] = io[:m0][[:yr,:i,:value]]
io[:fs0] = io[:fs0][[:yr,:i,:value]]
io[:ys0] = io[:ys0][[:yr,:j,:i,:value]]

cal = Dict();

for i in symbols_calibration
  push!(cal,i=>df_to_dict(io[i],:yr,:value,mod_year));
end

i_set = unique(io[:y0][!,:i]);
j_set = copy(i_set);
fd_set = ["pce","equipment","intelprop","residential","changinv","structures","def_equipment","defense","def_intelprop","def_structures","nondefense","fed_equipment","fed_intelprop","fed_structures","state_consume","state_equipment","state_intelprop","state_invest"];
ts_set = ["taxes","subsidies"];
va_set = ["compen","surplus","othtax"];
m_set = ["trn","trd"];
output_use_set = ["use","oth"];

####################
# -- Calibration --
####################

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
  + sum(abs(cal[:ys0][j,i]) * (ys0_est[j,i] / cal[:ys0][j,i] - 1)^2 for i in i_set for j in j_set if haskey(cal[:ys0],(j,i))  )
  + sum(abs(cal[:id0][i,j]) * (id0_est[i,j] / cal[:id0][i,j] - 1)^2 for i in i_set for j in j_set if haskey(cal[:id0],(i,j)) )
  + sum(abs(cal[:fs0][i]) * (fs0_est[i] / cal[:fs0][i] - 1)^2 for i in i_set if haskey(cal[:fs0],i) )
  + sum(abs(cal[:ms0][i,m]) * (ms0_est[i,m] / cal[:ms0][i,m] - 1)^2 for i in i_set for m in m_set if haskey(cal[:ms0],(i,m)) )
  + sum(abs(cal[:y0][i]) * (y0_est[i] / cal[:y0][i] - 1)^2 for i in i_set if haskey(cal[:y0],i) )
  + sum(abs(cal[:fd0][i,fd]) * (fd0_est[i,fd] / cal[:fd0][i,fd] - 1)^2 for i in i_set for fd in fd_set if haskey(cal[:fd0],(i,fd)) )
  + sum(abs(cal[:va0][va,j]) * (va0_est[va,j] / cal[:va0][va,j] - 1)^2 for va in va_set for j in j_set if haskey(cal[:va0],(va,j)) )
  + sum(abs(cal[:a0][i]) * (a0_est[i] / cal[:a0][i] - 1)^2  for i in i_set if haskey(cal[:a0],i) )
  + sum(abs(cal[:x0][i]) * (x0_est[i] / cal[:x0][i] - 1)^2  for i in i_set if haskey(cal[:x0],i) )
  + sum(abs(cal[:m0][i]) * (m0_est[i] / cal[:m0][i] - 1)^2  for i in i_set if haskey(cal[:m0],i) )
  + sum(abs(cal[:md0][m,i]) * (md0_est[m,i] / cal[:md0][m,i] - 1)^2 for m in m_set for i in i_set if haskey(cal[:md0],(m,i)) ) 

+ 1e7 * (
  + sum(ys0_est[j,i] for i in i_set for j in j_set if !haskey(cal[:ys0],(j,i)) )
  + sum(id0_est[i,j]  for i in i_set for j in j_set if !haskey(cal[:id0],(i,j)) )
  + sum(fs0_est[i]  for i in i_set if !haskey(cal[:fs0],i) )
  + sum(ms0_est[i,m]  for i in i_set for m in m_set if !haskey(cal[:ms0],(i,m)) )
  + sum(y0_est[i] for i in i_set if !haskey(cal[:y0],i) )
  + sum(fd0_est[i,fd] for i in i_set for fd in fd_set if !haskey(cal[:fd0],(i,fd)) )
  + sum(va0_est[va,j] for va in va_set for j in j_set if !haskey(cal[:va0],(va,j)) )
  + sum(a0_est[i] for i in i_set if !haskey(cal[:a0],i) )
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

[fix(ys0_est[i,j],0,force=true) for i in output_use_set for j in j_set]

JuMP.optimize!(calib)


##################
# -- Reporting -- 
##################

Diagnostics = Dict()

Diagnostics[:Z] = objective_value(calib)

Diagnostics[:u1] = sum(abs(cal[:ys0][j,i]) * (JuMP.value(ys0_est[j,i]) / cal[:ys0][j,i] - 1)^2 for i in i_set for j in j_set if haskey(cal[:ys0],(j,i))  )
Diagnostics[:u2] = sum(abs(cal[:id0][i,j]) * (JuMP.value(id0_est[i,j]) / cal[:id0][i,j] - 1)^2 for i in i_set for j in j_set if haskey(cal[:id0],(i,j)) )
Diagnostics[:u3] = sum(abs(cal[:fs0][i]) * (JuMP.value(fs0_est[i]) / cal[:fs0][i] - 1)^2 for i in i_set if haskey(cal[:fs0],i) )
Diagnostics[:u4] = sum(abs(cal[:ms0][i,m]) * (JuMP.value(ms0_est[i,m]) / cal[:ms0][i,m] - 1)^2 for i in i_set for m in m_set if haskey(cal[:ms0],(i,m)) )
Diagnostics[:u5] = sum(abs(cal[:y0][i]) * (JuMP.value(y0_est[i]) / cal[:y0][i] - 1)^2 for i in i_set if haskey(cal[:y0],i) )
Diagnostics[:u6] = sum(abs(cal[:fd0][i,fd]) * (JuMP.value(fd0_est[i,fd]) / cal[:fd0][i,fd] - 1)^2 for i in i_set for fd in fd_set if haskey(cal[:fd0],(i,fd)) )
Diagnostics[:u7] = sum(abs(cal[:va0][va,j]) * (JuMP.value(va0_est[va,j]) / cal[:va0][va,j] - 1)^2 for va in va_set for j in j_set if haskey(cal[:va0],(va,j)) )
Diagnostics[:u8] = sum(abs(cal[:a0][i]) * (JuMP.value(a0_est[i]) / cal[:a0][i] - 1)^2  for i in i_set if haskey(cal[:a0],i) )
Diagnostics[:u9] = sum(abs(cal[:x0][i]) * (JuMP.value(x0_est[i]) / cal[:x0][i] - 1)^2  for i in i_set if haskey(cal[:x0],i) )
Diagnostics[:u10] = sum(abs(cal[:m0][i]) * (JuMP.value(m0_est[i]) / cal[:m0][i] - 1)^2  for i in i_set if haskey(cal[:m0],i) )
Diagnostics[:u11] = sum(abs(cal[:md0][m,i]) * (JuMP.value(md0_est[m,i]) / cal[:md0][m,i] - 1)^2 for m in m_set for i in i_set if haskey(cal[:md0],(m,i)) ) 
Diagnostics[:u_all] = Diagnostics[:u1] + Diagnostics[:u2] + Diagnostics[:u3] + Diagnostics[:u4] + Diagnostics[:u5] + Diagnostics[:u6] + Diagnostics[:u7] + Diagnostics[:u8] + Diagnostics[:u9] + Diagnostics[:u10] + Diagnostics[:u11]


Diagnostics[:t1] = sum(JuMP.value(ys0_est[j,i]) for i in i_set for j in j_set if !haskey(cal[:ys0],(j,i)) )
Diagnostics[:t2] = sum(JuMP.value(id0_est[i,j])  for i in i_set for j in j_set if !haskey(cal[:id0],(i,j)) )
Diagnostics[:t3] = sum(JuMP.value(fs0_est[i])  for i in i_set if !haskey(cal[:fs0],i) )
Diagnostics[:t4] = sum(JuMP.value(ms0_est[i,m])  for i in i_set for m in m_set if !haskey(cal[:ms0],(i,m)) )
Diagnostics[:t5] = sum(JuMP.value(y0_est[i]) for i in i_set if !haskey(cal[:y0],i) )
Diagnostics[:t6] = sum(JuMP.value(fd0_est[i,fd]) for i in i_set for fd in fd_set if !haskey(cal[:fd0],(i,fd)) )
Diagnostics[:t7] = sum(JuMP.value(va0_est[va,j]) for va in va_set for j in j_set if !haskey(cal[:va0],(va,j)) )
Diagnostics[:t8] = sum(JuMP.value(a0_est[i]) for i in i_set if !haskey(cal[:a0],i) )
Diagnostics[:t9] = sum(JuMP.value(x0_est[i]) for i in i_set if !haskey(cal[:x0],i) )
Diagnostics[:t10] = sum(JuMP.value(m0_est[i]) for i in i_set if !haskey(cal[:m0],i) )
Diagnostics[:t11] = sum(JuMP.value(md0_est[m,i])  for m in m_set for i in i_set if !haskey(cal[:md0],(m,i)) ) 

Diagnostics_Detailed = Dict()


