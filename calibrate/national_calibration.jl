

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


##########
# FUNCTIONS
##########

#replace here with "collect"
  function key_to_vec(d::Dict,index_num::Int64)
    return [k[index_num] for k in keys(d)]
  end
 
  function df_to_dict(df::DataFrame,remove_column::Symbol,value_column::Symbol,year::Int64,sub::Bool)
    colnames = setdiff(names(df),[value_column,remove_column])
    #subset on year
    df = df[df[!,:yr].==year,:]
    
    #filter out negative values
    if sub
      df[df[!,value_column].<0,value_column] .= 0
    end
    
    #only want non-zero values
    df = df[df[!,value_column].!=0.0,:]

    #df[!,value_column] .= round.(df[!,value_column],digits=3)
    
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

#need to set all negative pce values in :fd0 to zero
# but others can remain
kk = copy(io[:fd0])
k1 = kk[(kk[:fd].=="pce"),:]
k1[(k1[!,:value].<0),:value] .= 0 
k2 = kk[(kk[!,:fd].!="pce"),:]

kkt = [k1;k2]
io[:fd0] = kkt

cal = Dict();

skpneg = [:fd0,:ta0, :tm0]

for i in symbols_calibration
  if !(i in skpneg)
    push!(cal,i=>df_to_dict(io[i],:yr,:value,mod_year,true));
  end

  if i in skpneg
    push!(cal,i=>df_to_dict(io[i],:yr,:value,mod_year,false));
  end
end



i_set = unique(io[:y0][!,:i]);
j_set = copy(i_set);

fd_set = ["pce","equipment","intelprop","residential","changinv","structures","def_equipment","defense",
          "def_intelprop","def_structures","nondefense","fed_equipment","fed_intelprop","fed_structures",
          "state_consume","state_equipment","state_intelprop","state_invest"];

ts_set = ["taxes","subsidies"];

va_set = ["compen","surplus","othtax"];

m_set = ["trn","trd"];

output_use_set = ["use","oth"];

#fill_zero not working for single dimensions..
for i in i_set
  if haskey(cal[:ta0],i)==false
    push!(cal[:ta0],i=>0)
  end
  if haskey(cal[:tm0],i)==false
    push!(cal[:tm0],i=>0)
  end
end


####################
# -- Calibration --
####################

calib = Model(with_optimizer(Ipopt.Optimizer,nlp_scaling_method="gradient-based"))

@variable(calib,ys0_est[j in j_set,i in i_set]>=0,start=0);
@variable(calib,fs0_est[i in i_set]>=0,start=0);
@variable(calib,ms0_est[i in i_set,m in m_set]>=0,start=0);
@variable(calib,y0_est[i in i_set]>=0,start=0);
@variable(calib,id0_est[i in i_set,j in j_set]>=0,start=0);
@variable(calib,fd0_est[i in i_set,fd in fd_set]>=0,start=0);
@variable(calib,va0_est[va in va_set,j in j_set]>=0,start=0);
@variable(calib,a0_est[i in i_set]>=0,start=0);
@variable(calib,x0_est[i in i_set]>=0,start=0);
@variable(calib,m0_est[i in i_set]>=0,start=0);
@variable(calib,md0_est[m in m_set,i in i_set]>=0,start=0);

```
mkt_py(i)..	sum(j, ys0_(j,i)) +  fs0_(i) =E= sum(m, ms0_(i,m)) + y0_(i);
mkt_pa(i)..	a0_(i) =E= sum(j, id0_(i,j)) + sum(fd,fd0_(i,fd));
mkt_pm(m)..	sum(i,ms0_(i,m)) =E= sum(i, md0_(m,i));
prf_y(j)..	sum(i, ys0_(j,i)) =E= sum(i, id0_(i,j)) + sum(va,va0_(va,j));
prf_a(i)..	a0_(i)*(1-ta0(i)) + x0_(i) =E= y0_(i) + m0_(i)*(1+tm0(i)) + sum(m, md0_(m,i));
```

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

@constraint(calib,prf_a[i in i_set],
  a0_est[i] * (1-cal[:ta0][i]) + x0_est[i] == y0_est[i] + m0_est[i]*(1+cal[:tm0][i]) + sum(md0_est[m,i] for m in m_set)
);

penalty_nokey = 1e4

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

+  penalty_nokey * (
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

# multipliers for lower and upper bound relative
# to each respective variables reference parameter
lb = 0.1
ub = 5

[set_lower_bound(ys0_est[j,i],max(0,lb * cal[:ys0][j,i] )) for i in i_set for j in j_set if haskey(cal[:ys0],(j,i)) ] ;
[set_lower_bound(id0_est[i,j],max(0,lb * cal[:id0][i,j] )) for i in i_set for j in j_set if haskey(cal[:id0],(i,j)) ] ;
[set_lower_bound(fs0_est[i],max(0,lb * cal[:fs0][i])) for i in i_set if haskey(cal[:fs0],i) ];
[set_lower_bound(ms0_est[i,m],max(0,lb * cal[:ms0][i,m])) for i in i_set for m in m_set if haskey(cal[:ms0],(i,m)) ];
[set_lower_bound(y0_est[i],max(0,lb * cal[:y0][i])) for i in i_set if haskey(cal[:y0],i) ];
[set_lower_bound(fd0_est[i,fd],max(0,lb * cal[:fd0][i,fd])) for i in i_set for fd in fd_set if haskey(cal[:fd0],(i,fd)) ];
[set_lower_bound(va0_est[va,j],max(0,lb * cal[:va0][va,j])) for va in va_set for j in j_set if haskey(cal[:va0],(va,j)) ];
[set_lower_bound(a0_est[i],max(0,lb * cal[:a0][i])) for i in i_set if haskey(cal[:a0],(i)) ];
[set_lower_bound(x0_est[i],max(0,lb * cal[:x0][i])) for i in i_set if haskey(cal[:x0],i) ];
[set_lower_bound(m0_est[i],max(0,lb * cal[:m0][i])) for i in i_set if haskey(cal[:m0],i) ];
[set_lower_bound(md0_est[m,i],max(0,lb * cal[:md0][m,i])) for m in m_set for i in i_set if haskey(cal[:md0],(m,i)) ] ;

[set_upper_bound(ys0_est[j,i],abs(ub * cal[:ys0][j,i] )) for i in i_set for j in j_set if haskey(cal[:ys0],(j,i)) ] ;
[set_upper_bound(id0_est[i,j],abs(ub * cal[:id0][i,j] )) for i in i_set for j in j_set if haskey(cal[:id0],(i,j)) ] ;
[set_upper_bound(fs0_est[i],abs(ub * cal[:fs0][i])) for i in i_set if haskey(cal[:fs0],i) ];
[set_upper_bound(ms0_est[i,m],abs(ub * cal[:ms0][i,m])) for i in i_set for m in m_set if haskey(cal[:ms0],(i,m)) ];
[set_upper_bound(y0_est[i],abs(ub * cal[:y0][i])) for i in i_set if haskey(cal[:y0],i) ];
[set_upper_bound(fd0_est[i,fd],abs(ub * cal[:fd0][i,fd])) for i in i_set for fd in fd_set if haskey(cal[:fd0],(i,fd)) ];
[set_upper_bound(va0_est[va,j],abs(ub * cal[:va0][va,j])) for va in va_set for j in j_set if haskey(cal[:va0],(va,j)) ];
[set_upper_bound(a0_est[i],abs(ub * cal[:a0][i])) for i in i_set if haskey(cal[:a0],(i)) ];
[set_upper_bound(x0_est[i],abs(ub * cal[:x0][i])) for i in i_set if haskey(cal[:x0],i) ];
[set_upper_bound(m0_est[i],abs(ub * cal[:m0][i])) for i in i_set if haskey(cal[:m0],i) ];
[set_upper_bound(md0_est[m,i],abs(ub * cal[:md0][m,i])) for m in m_set for i in i_set if haskey(cal[:md0],(m,i)) ] ;

[fix(fs0_est[i],cal[:fs0][i],force=true) for i in i_set if haskey(cal[:fs0],i)];
[fix(fs0_est[i],0,force=true) for i in i_set if !haskey(cal[:fs0],i)];

[fix(va0_est[va,j],cal[:va0][va,j],force=true) for va in va_set for j in j_set if haskey(cal[:va0],(va,j))];
[fix(va0_est[va,j],0,force=true) for va in va_set for j in j_set if !haskey(cal[:va0],(va,j))];

[fix(m0_est[i],cal[:m0][i],force=true) for i in i_set if haskey(cal[:m0],i)];
[fix(m0_est[i],0,force=true) for i in i_set if !haskey(cal[:m0],i)];

#fd_temp = filter!(x->x≠"pce",fd_set)
#[fix(fd0_est[i,fd],cal[:fd0][i,fd],force=true) for i in i_set for fd in fd_temp if haskey(cal[:fd0],(i,fd))]
#[fix(fd0_est[i,fd],0,force=true) for i in i_set for fd in fd_temp if !haskey(cal[:fd0],(i,fd))]

[fix(ys0_est[j,i],0,force=true) for j in output_use_set for i in i_set]




JuMP.optimize!(calib)


##################
# -- Reporting -- 
##################


Obj_Diagnostics = Dict();

Obj_Diagnostics[:Z] = - objective_value(calib);


Obj_Diagnostics[:ys0_withkey] = sum(abs(cal[:ys0][j,i]) * (JuMP.value(ys0_est[j,i]) / cal[:ys0][j,i] - 1)^2 for i in i_set for j in j_set if haskey(cal[:ys0],(j,i))  ) ;
Obj_Diagnostics[:id0_withkey] = sum(abs(cal[:id0][i,j]) * (JuMP.value(id0_est[i,j]) / cal[:id0][i,j] - 1)^2 for i in i_set for j in j_set if haskey(cal[:id0],(i,j)) ) ;
Obj_Diagnostics[:fs0_withkey] = sum(abs(cal[:fs0][i]) * (JuMP.value(fs0_est[i]) / cal[:fs0][i] - 1)^2 for i in i_set if haskey(cal[:fs0],i) ) ;
Obj_Diagnostics[:ms0_withkey] = sum(abs(cal[:ms0][i,m]) * (JuMP.value(ms0_est[i,m]) / cal[:ms0][i,m] - 1)^2 for i in i_set for m in m_set if haskey(cal[:ms0],(i,m)) ) ;
Obj_Diagnostics[:y0_withkey] = sum(abs(cal[:y0][i]) * (JuMP.value(y0_est[i]) / cal[:y0][i] - 1)^2 for i in i_set if haskey(cal[:y0],i) ) ;
Obj_Diagnostics[:fd0_withkey] = sum(abs(cal[:fd0][i,fd]) * (JuMP.value(fd0_est[i,fd]) / cal[:fd0][i,fd] - 1)^2 for i in i_set for fd in fd_set if haskey(cal[:fd0],(i,fd)) ) ;
Obj_Diagnostics[:va0_withkey] = sum(abs(cal[:va0][va,j]) * (JuMP.value(va0_est[va,j]) / cal[:va0][va,j] - 1)^2 for va in va_set for j in j_set if haskey(cal[:va0],(va,j)) ) ;
Obj_Diagnostics[:a0_withkey] = sum(abs(cal[:a0][i]) * (JuMP.value(a0_est[i]) / cal[:a0][i] - 1)^2  for i in i_set if haskey(cal[:a0],i) ) ;
Obj_Diagnostics[:x0_withkey] = sum(abs(cal[:x0][i]) * (JuMP.value(x0_est[i]) / cal[:x0][i] - 1)^2  for i in i_set if haskey(cal[:x0],i) ) ;
Obj_Diagnostics[:m0_withkey] = sum(abs(cal[:m0][i]) * (JuMP.value(m0_est[i]) / cal[:m0][i] - 1)^2  for i in i_set if haskey(cal[:m0],i) ) ;
Obj_Diagnostics[:md0_withkey] = sum(abs(cal[:md0][m,i]) * (JuMP.value(md0_est[m,i]) / cal[:md0][m,i] - 1)^2 for m in m_set for i in i_set if haskey(cal[:md0],(m,i)) )  ;

Obj_Diagnostics[:ys0_nokey] = penalty_nokey * sum(JuMP.value(ys0_est[j,i]) for i in i_set for j in j_set if !haskey(cal[:ys0],(j,i)) ) ;
Obj_Diagnostics[:id0_nokey] = penalty_nokey * sum(JuMP.value(id0_est[i,j])  for i in i_set for j in j_set if !haskey(cal[:id0],(i,j)) ) ;
Obj_Diagnostics[:fs0_nokey] = penalty_nokey * sum(JuMP.value(fs0_est[i])  for i in i_set if !haskey(cal[:fs0],i) ) ;
Obj_Diagnostics[:ms0_nokey] = penalty_nokey * sum(JuMP.value(ms0_est[i,m])  for i in i_set for m in m_set if !haskey(cal[:ms0],(i,m)) ) ;
Obj_Diagnostics[:y0_nokey] = penalty_nokey * sum(JuMP.value(y0_est[i]) for i in i_set if !haskey(cal[:y0],i) ) ;
Obj_Diagnostics[:fd0_nokey] = penalty_nokey * sum(JuMP.value(fd0_est[i,fd]) for i in i_set for fd in fd_set if !haskey(cal[:fd0],(i,fd)) ) ;
Obj_Diagnostics[:va0_nokey] = penalty_nokey * sum(JuMP.value(va0_est[va,j]) for va in va_set for j in j_set if !haskey(cal[:va0],(va,j)) ) ;
Obj_Diagnostics[:a0_nokey] = penalty_nokey * sum(JuMP.value(a0_est[i]) for i in i_set if !haskey(cal[:a0],i) ) ;
Obj_Diagnostics[:x0_nokey] = penalty_nokey * sum(JuMP.value(x0_est[i]) for i in i_set if !haskey(cal[:x0],i) ) ;
Obj_Diagnostics[:m0_nokey] = penalty_nokey * sum(JuMP.value(m0_est[i]) for i in i_set if !haskey(cal[:m0],i) ) ;
Obj_Diagnostics[:md0_nokey] = penalty_nokey * sum(JuMP.value(md0_est[m,i])  for m in m_set for i in i_set if !haskey(cal[:md0],(m,i)) )  ;

Obj_Diagnostics[:difference] = sum(values(Obj_Diagnostics)) ;


#############################
# -- Variable diagnostics --
#############################

variable_diagnostics = Dict()

variable_diagnostics[:ys0_min] = minimum(JuMP.value.(ys0_est))
variable_diagnostics[:id0_min] = minimum(JuMP.value.(id0_est))
variable_diagnostics[:fs0_min] = minimum(JuMP.value.(fs0_est))
variable_diagnostics[:ms0_min] = minimum(JuMP.value.(ms0_est))
variable_diagnostics[:y0_min] = minimum(JuMP.value.(y0_est))
variable_diagnostics[:fd0_min] = minimum(JuMP.value.(fd0_est))
variable_diagnostics[:va0_min] = minimum(JuMP.value.(va0_est))
variable_diagnostics[:a0_min] = minimum(JuMP.value.(a0_est))
variable_diagnostics[:x0_min] = minimum(JuMP.value.(x0_est))
variable_diagnostics[:m0_min] = minimum(JuMP.value.(m0_est))
variable_diagnostics[:md0_min] = minimum(JuMP.value.(md0_est))

variable_diagnostics[:ys0_max] = maximum(JuMP.value.(ys0_est))
variable_diagnostics[:id0_max] = maximum(JuMP.value.(id0_est))
variable_diagnostics[:fs0_max] = maximum(JuMP.value.(fs0_est))
variable_diagnostics[:ms0_max] = maximum(JuMP.value.(ms0_est))
variable_diagnostics[:y0_max] = maximum(JuMP.value.(y0_est))
variable_diagnostics[:fd0_max] = maximum(JuMP.value.(fd0_est))
variable_diagnostics[:va0_max] = maximum(JuMP.value.(va0_est))
variable_diagnostics[:a0_max] = maximum(JuMP.value.(a0_est))
variable_diagnostics[:x0_max] = maximum(JuMP.value.(x0_est))
variable_diagnostics[:m0_max] = maximum(JuMP.value.(m0_est))
variable_diagnostics[:md0_max] = maximum(JuMP.value.(md0_est))


variable_diagnostics[:ys_rat] = Dict()
variable_diagnostics[:id_rat] = Dict()
variable_diagnostics[:fs_rat] = Dict()
variable_diagnostics[:ms_rat] = Dict()
variable_diagnostics[:y0_rat] = Dict()
variable_diagnostics[:fd_rat] = Dict()
variable_diagnostics[:va_rat] = Dict()
variable_diagnostics[:a0_rat] = Dict()
variable_diagnostics[:x0_rat] = Dict()
variable_diagnostics[:m0_rat] = Dict()
variable_diagnostics[:md_rat] = Dict()


for i in i_set 
  for j in j_set 
      if haskey(cal[:ys0],(j,i)) 
          val = (JuMP.value(ys0_est[j,i]) / cal[:ys0][j,i] ) 
          push!(variable_diagnostics[:ys_rat],[j,i]=>val)
      end
  end
end


for i in i_set 
  for j in j_set 
      if haskey(cal[:id0],(i,j)) 
          val = (JuMP.value(id0_est[i,j]) / cal[:id0][i,j] ) 
          push!(variable_diagnostics[:id_rat],[i,j]=>val)
      end
  end
end


for i in i_set 
  if haskey(cal[:fs0],i)
      val = (JuMP.value(fs0_est[i]) / cal[:fs0][i]) 
      push!(variable_diagnostics[:fs_rat],[i]=>val)
  end
end



for i in i_set 
  for m in m_set 
      if haskey(cal[:ms0],(i,m))
      val = (JuMP.value(ms0_est[i,m]) / cal[:ms0][i,m]) 
      push!(variable_diagnostics[:ms_rat],[i,m]=>val)
      end
  end
end



for i in i_set 
  if haskey(cal[:y0],i)
      val = (JuMP.value(y0_est[i]) / cal[:y0][i]) 
      push!(variable_diagnostics[:y0_rat],[i]=>val)
  end
end

for i in i_set 
  for fd in fd_set 
      if haskey(cal[:fd0],(i,fd))
          val = (JuMP.value(fd0_est[i,fd]) / cal[:fd0][i,fd]) 
          push!(variable_diagnostics[:fd_rat],[i,fd]=>val)
      end
  end
end


for va in va_set 
  for j in j_set 
      if haskey(cal[:va0],(va,j))
          val = (JuMP.value(va0_est[va,j]) / cal[:va0][va,j]) 
          push!(variable_diagnostics[:va_rat],[va,j]=>val)
      end
  end
end


for i in i_set 
  if haskey(cal[:a0],(i))
      val = (JuMP.value(a0_est[i]) / cal[:a0][i]) 
      push!(variable_diagnostics[:a0_rat],[i]=>val)
  end
end


for i in i_set 
  if haskey(cal[:x0],i)
      val = (JuMP.value(x0_est[i]) / cal[:x0][i]) 
      push!(variable_diagnostics[:x0_rat],[i]=>val)
  end
end

for i in i_set 
  if haskey(cal[:m0],i)
      val = (JuMP.value(m0_est[i]) / cal[:m0][i]) 
      push!(variable_diagnostics[:m0_rat],[i]=>val)
  end
end

for m in m_set 
  for i in i_set 
      if haskey(cal[:md0],(m,i)) 
          val = (JuMP.value(md0_est[m,i]) / cal[:md0][m,i]) 
          push!(variable_diagnostics[:md_rat],[m,i]=>val)
      end
  end
end

variable_diagnostics[:ys_rat_max] = findmax(variable_diagnostics[:ys_rat])
variable_diagnostics[:id_rat_max] = findmax(variable_diagnostics[:id_rat])
variable_diagnostics[:fs_rat_max] = findmax(variable_diagnostics[:fs_rat])
variable_diagnostics[:ms_rat_max] = findmax(variable_diagnostics[:ms_rat])
variable_diagnostics[:y0_rat_max] = findmax(variable_diagnostics[:y0_rat])
variable_diagnostics[:fd_rat_max] = findmax(variable_diagnostics[:fd_rat])
variable_diagnostics[:va_rat_max] = findmax(variable_diagnostics[:va_rat])
variable_diagnostics[:a0_rat_max] = findmax(variable_diagnostics[:a0_rat])
variable_diagnostics[:x0_rat_max] = findmax(variable_diagnostics[:x0_rat])
variable_diagnostics[:m0_rat_max] = findmax(variable_diagnostics[:m0_rat])
variable_diagnostics[:md_rat_max] = findmax(variable_diagnostics[:md_rat])

variable_diagnostics[:ys_rat_min] = findmin(variable_diagnostics[:ys_rat])
variable_diagnostics[:id_rat_min] = findmin(variable_diagnostics[:id_rat])
variable_diagnostics[:fs_rat_min] = findmin(variable_diagnostics[:fs_rat])
variable_diagnostics[:ms_rat_min] = findmin(variable_diagnostics[:ms_rat])
variable_diagnostics[:y0_rat_min] = findmin(variable_diagnostics[:y0_rat])
variable_diagnostics[:fd_rat_min] = findmin(variable_diagnostics[:fd_rat])
variable_diagnostics[:va_rat_min] = findmin(variable_diagnostics[:va_rat])
variable_diagnostics[:a0_rat_min] = findmin(variable_diagnostics[:a0_rat])
variable_diagnostics[:x0_rat_min] = findmin(variable_diagnostics[:x0_rat])
variable_diagnostics[:m0_rat_min] = findmin(variable_diagnostics[:m0_rat])
variable_diagnostics[:md_rat_min] = findmin(variable_diagnostics[:md_rat])






################################
# -- Constraint diagnostics --
################################

constraint_diagnostic = Dict()

constraint_diagnostic[:mkt_py] = Dict()
constraint_diagnostic[:mkt_pa] = Dict()
constraint_diagnostic[:mkt_pm] = Dict()
constraint_diagnostic[:prf_y] = Dict()
constraint_diagnostic[:prf_a] = Dict()

for i in i_set
  push!(constraint_diagnostic[:mkt_py],i=>sum(JuMP.value(ys0_est[j,i]) for j in j_set) + JuMP.value(fs0_est[i])  - (sum(JuMP.value(ms0_est[i,m]) for m in m_set) + JuMP.value(y0_est[i])))
  push!(constraint_diagnostic[:mkt_pa],i=>JuMP.value(a0_est[i])  - (sum(JuMP.value(id0_est[i,j]) for j in j_set) + sum(JuMP.value(fd0_est[i,fd]) for fd in fd_set)))
  push!(constraint_diagnostic[:prf_a],i=>JuMP.value(a0_est[i]) * (1-cal[:ta0][i]) + JuMP.value(x0_est[i]) - ( JuMP.value(y0_est[i]) + JuMP.value(m0_est[i])*(1+cal[:tm0][i]) + sum(JuMP.value(md0_est[m,i]) for m in m_set) )  )
end

for m in m_set
  push!(constraint_diagnostic[:mkt_pm],m=>sum(JuMP.value(ms0_est[i,m]) for i in i_set)  - (sum(JuMP.value(md0_est[m,i]) for i in i_set)))
end

for j in j_set
  push!(constraint_diagnostic[:prf_y],j=>sum(JuMP.value(ys0_est[j,i]) for i in i_set)  - (sum(JuMP.value(id0_est[i,j]) for i in i_set) + sum(JuMP.value(va0_est[va,j]) for va in va_set)))
end





