"""
    calibrate(d::Dict, set::Dict; save = true, overwrite = false)
    calibrate(year::Int, d::Dict, set::Dict)

# Arguments
- `d::Dict` of DataFrames containing the model data.
- `set::Dict` of Arrays describing region, sector, final demand, etc.
- `year::Int`: year for which to perform calibration

# Keywords
- `save = true`
- `overwrite = false`
See [`SLiDE.build_data`](@ref) for keyword argument descriptions.

# Returns
- `d::Dict` of DataFrames containing the model data at the calibration step.
"""
function calibrate(d::Dict, set::Dict; save = true, overwrite = false)

    io_cal = read_build("calibrate"; save = save, overwrite = overwrite)
    !isempty(io_cal) && (return io_cal)

    # Copy the relevant input DataFrames before making any changes.
    set[:cal] = [:a0,:fd0,:fs0,:id0,:m0,:md0,:ms0,:ta0,:tm0,:va0,:x0,:y0,:ys0]
    d = Dict(k => copy(d[k]) for k in set[:cal])
    
    # Set all values to be at least zero for final demand and tax rates.
    [d[k][d[k][:,:value] .< 0, :value] .= 0 for k in [:fd0, :ta0, :tm0]]
    
    # Initialize a DataFrame to contain results.
    # io_cal = Dict(k => DataFrame() for k in setdiff(set[:cal], [:ta0,:tm0]))
    io_cal = Dict(k => DataFrame() for k in set[:cal])

    for year in set[:yr]
        io_cal_temp = calibrate(year, d, set)
        [io_cal[k] = [io_cal[k]; io_cal_temp[k]] for k in keys(io_cal)]
    end

    write_build("calibrate", io_cal; save = save)

    return io_cal
end

function calibrate(year::Int, d::Dict, set::Dict)
    println("  Calibrating $year data")

    # Initialize resultant DataFrame.
    io_cal = Dict(k => edit_with(filter_with(copy(d[k]), (yr = year,)),
        Rename(:i,:g)) for k in [:ta0,:tm0])

    cal = Dict(k => convert_type(Dict, edit_with(filter_with(d[k],
        (yr = year,)), Drop.([:yr,:value], ["all", 0.0], "=="))) for k in set[:cal])
    cal[:tm0] = fill_zero((set[:i],), cal[:tm0])
    cal[:ta0] = fill_zero((set[:i],), cal[:tm0])

    # with_optimizer(Ipopt.Optimizer, max_cpu_time=60.0)` becomes `optimizer_with_attributes(Ipopt.Optimizer, "max_cpu_time" => 60.0)
    # calib = Model(with_optimizer(Ipopt.Optimizer, nlp_scaling_method="gradient-based"))
    calib = Model(optimizer_with_attributes(Ipopt.Optimizer, "max_cpu_time" => 60.0))

    @variable(calib,ys0_est[j in set[:j], i in set[:i]] >= 0,start = 0);
    @variable(calib,fs0_est[i in set[:i]] >= 0,start = 0);
    @variable(calib,ms0_est[i in set[:i],m in set[:m]] >= 0,start = 0);
    @variable(calib,y0_est[i in set[:i]] >= 0,start = 0);
    @variable(calib,id0_est[i in set[:i],j in set[:j]] >= 0,start = 0);
    @variable(calib,fd0_est[i in set[:i],fd in set[:fd]] >= 0,start = 0);
    @variable(calib,va0_est[va in set[:va],j in set[:j]] >= 0,start = 0);
    @variable(calib,a0_est[i in set[:i]] >= 0,start = 0);
    @variable(calib,x0_est[i in set[:i]] >= 0,start = 0);
    @variable(calib,m0_est[i in set[:i]] >= 0,start = 0);
    @variable(calib,md0_est[m in set[:m],i in set[:i]] >= 0,start = 0);

    # ```
    # mkt_py(i)..	sum(j, ys0_(j,i)) +  fs0_(i) =E= sum(m, ms0_(i,m)) + y0_(i);
    # mkt_pa(i)..	a0_(i) =E= sum(j, id0_(i,j)) + sum(fd,fd0_(i,fd));
    # mkt_pm(m)..	sum(i,ms0_(i,m)) =E= sum(i, md0_(m,i));
    # prf_y(j)..	sum(i, ys0_(j,i)) =E= sum(i, id0_(i,j)) + sum(va,va0_(va,j));
    # prf_a(i)..	a0_(i)*(1-ta0(i)) + x0_(i) =E= y0_(i) + m0_(i)*(1+tm0(i)) + sum(m, md0_(m,i));
    # ```

    @constraint(calib,mkt_py[i in set[:i]],
        sum(ys0_est[j,i] for j in set[:j]) + fs0_est[i] == sum(ms0_est[i,m] for m in set[:m]) + y0_est[i]
    );

    @constraint(calib,mkt_pa[i in set[:i]],
        a0_est[i] == sum(id0_est[i,j] for j in set[:j]) + sum(fd0_est[i,fd] for fd in set[:fd])
    );

    @constraint(calib,mkt_pm[m in set[:m]],
        sum(ms0_est[i,m] for i in set[:i]) == sum(md0_est[m,i] for i in set[:i])
    );

    @constraint(calib,prf_y[j in set[:j]],
        sum(ys0_est[j,i] for i in set[:i]) == sum(id0_est[i,j] for i in set[:i]) + sum(va0_est[va,j] for va in set[:va])
    );

    @constraint(calib,prf_a[i in set[:i]],
        a0_est[i] * (1 - cal[:ta0][i]) + x0_est[i] == y0_est[i] + m0_est[i] * (1 + cal[:tm0][i]) + sum(md0_est[m,i] for m in set[:m])
    );

    penalty_nokey = 1e4

    @objective(calib, Min,
        + sum(abs(cal[:ys0][j,i]) * (ys0_est[j,i] / cal[:ys0][j,i] - 1)^2 for i in set[:i] for j in set[:j] if haskey(cal[:ys0], (j, i)))
        + sum(abs(cal[:id0][i,j]) * (id0_est[i,j] / cal[:id0][i,j] - 1)^2 for i in set[:i] for j in set[:j] if haskey(cal[:id0], (i, j)))
        + sum(abs(cal[:fs0][i]) * (fs0_est[i] / cal[:fs0][i] - 1)^2 for i in set[:i] if haskey(cal[:fs0], i))
        + sum(abs(cal[:ms0][i,m]) * (ms0_est[i,m] / cal[:ms0][i,m] - 1)^2 for i in set[:i] for m in set[:m] if haskey(cal[:ms0], (i, m)))
        + sum(abs(cal[:y0][i]) * (y0_est[i] / cal[:y0][i] - 1)^2 for i in set[:i] if haskey(cal[:y0], i))
        + sum(abs(cal[:fd0][i,fd]) * (fd0_est[i,fd] / cal[:fd0][i,fd] - 1)^2 for i in set[:i] for fd in set[:fd] if haskey(cal[:fd0], (i, fd)))
        + sum(abs(cal[:va0][va,j]) * (va0_est[va,j] / cal[:va0][va,j] - 1)^2 for va in set[:va] for j in set[:j] if haskey(cal[:va0], (va, j)))
        + sum(abs(cal[:a0][i]) * (a0_est[i] / cal[:a0][i] - 1)^2  for i in set[:i] if haskey(cal[:a0], i))
        + sum(abs(cal[:x0][i]) * (x0_est[i] / cal[:x0][i] - 1)^2  for i in set[:i] if haskey(cal[:x0], i))
        + sum(abs(cal[:m0][i]) * (m0_est[i] / cal[:m0][i] - 1)^2  for i in set[:i] if haskey(cal[:m0], i))
        + sum(abs(cal[:md0][m,i]) * (md0_est[m,i] / cal[:md0][m,i] - 1)^2 for m in set[:m] for i in set[:i] if haskey(cal[:md0], (m, i))) 

    + penalty_nokey * (
        + sum(ys0_est[j,i]^2 for i in set[:i] for j in set[:j] if !haskey(cal[:ys0], (j, i)))
        + sum(id0_est[i,j]^2  for i in set[:i] for j in set[:j] if !haskey(cal[:id0], (i, j)))
        + sum(fs0_est[i]^2  for i in set[:i] if !haskey(cal[:fs0], i))
        + sum(ms0_est[i,m]^2  for i in set[:i] for m in set[:m] if !haskey(cal[:ms0], (i, m)))
        + sum(y0_est[i]^2 for i in set[:i] if !haskey(cal[:y0], i))
        + sum(fd0_est[i,fd]^2 for i in set[:i] for fd in set[:fd] if !haskey(cal[:fd0], (i, fd)))
        + sum(va0_est[va,j]^2 for va in set[:va] for j in set[:j] if !haskey(cal[:va0], (va, j)))
        + sum(a0_est[i]^2 for i in set[:i] if !haskey(cal[:a0], i))
        + sum(x0_est[i]^2 for i in set[:i] if !haskey(cal[:x0], i))
        + sum(m0_est[i]^2 for i in set[:i] if !haskey(cal[:m0], i))
        + sum(md0_est[m,i]^2  for m in set[:m] for i in set[:i] if !haskey(cal[:md0], (m, i)))
        )
    );

    [set_start_value(ys0_est[j,i], cal[:ys0][j,i]) for i in set[:i] for j in set[:j] if haskey(cal[:ys0], (j, i)) ] ;
    [set_start_value(id0_est[i,j], cal[:id0][i,j]) for i in set[:i] for j in set[:j] if haskey(cal[:id0], (i, j)) ] ;
    [set_start_value(fs0_est[i],   cal[:fs0][i]) for i in set[:i] if haskey(cal[:fs0], i) ];
    [set_start_value(ms0_est[i,m], cal[:ms0][i,m]) for i in set[:i] for m in set[:m] if haskey(cal[:ms0], (i, m)) ];
    [set_start_value(y0_est[i],    cal[:y0][i]) for i in set[:i] if haskey(cal[:y0], i) ];
    [set_start_value(fd0_est[i,fd],cal[:fd0][i,fd]) for i in set[:i] for fd in set[:fd] if haskey(cal[:fd0], (i, fd)) ];
    [set_start_value(va0_est[va,j],cal[:va0][va,j]) for va in set[:va] for j in set[:j] if haskey(cal[:va0], (va, j)) ];
    [set_start_value(a0_est[i],    cal[:a0][i]) for i in set[:i] if haskey(cal[:a0], (i)) ];
    [set_start_value(x0_est[i],    cal[:x0][i]) for i in set[:i] if haskey(cal[:x0], i) ];
    [set_start_value(m0_est[i],    cal[:m0][i]) for i in set[:i] if haskey(cal[:m0], i) ];
    [set_start_value(md0_est[m,i], cal[:md0][m,i]) for m in set[:m] for i in set[:i] if haskey(cal[:md0], (m, i)) ] ;

    # multipliers for lower and upper bound relative
    # to each respective variables reference parameter
    lb = 0.1
    ub = 5

    [set_lower_bound(ys0_est[j,i], max(0, lb * cal[:ys0][j,i])) for i in set[:i] for j in set[:j] if haskey(cal[:ys0], (j, i)) ] ;
    [set_lower_bound(id0_est[i,j], max(0, lb * cal[:id0][i,j])) for i in set[:i] for j in set[:j] if haskey(cal[:id0], (i, j)) ] ;
    [set_lower_bound(fs0_est[i], max(0, lb * cal[:fs0][i])) for i in set[:i] if haskey(cal[:fs0], i) ];
    [set_lower_bound(ms0_est[i,m], max(0, lb * cal[:ms0][i,m])) for i in set[:i] for m in set[:m] if haskey(cal[:ms0], (i, m)) ];
    [set_lower_bound(y0_est[i], max(0, lb * cal[:y0][i])) for i in set[:i] if haskey(cal[:y0], i) ];
    [set_lower_bound(fd0_est[i,fd], max(0, lb * cal[:fd0][i,fd])) for i in set[:i] for fd in set[:fd] if haskey(cal[:fd0], (i, fd)) ];
    [set_lower_bound(va0_est[va,j], max(0, lb * cal[:va0][va,j])) for va in set[:va] for j in set[:j] if haskey(cal[:va0], (va, j)) ];
    [set_lower_bound(a0_est[i], max(0, lb * cal[:a0][i])) for i in set[:i] if haskey(cal[:a0], (i)) ];
    [set_lower_bound(x0_est[i], max(0, lb * cal[:x0][i])) for i in set[:i] if haskey(cal[:x0], i) ];
    [set_lower_bound(m0_est[i], max(0, lb * cal[:m0][i])) for i in set[:i] if haskey(cal[:m0], i) ];
    [set_lower_bound(md0_est[m,i], max(0, lb * cal[:md0][m,i])) for m in set[:m] for i in set[:i] if haskey(cal[:md0], (m, i)) ] ;

    [set_upper_bound(ys0_est[j,i], abs(ub * cal[:ys0][j,i])) for i in set[:i] for j in set[:j] if haskey(cal[:ys0], (j, i)) ] ;
    [set_upper_bound(id0_est[i,j], abs(ub * cal[:id0][i,j])) for i in set[:i] for j in set[:j] if haskey(cal[:id0], (i, j)) ] ;
    [set_upper_bound(fs0_est[i], abs(ub * cal[:fs0][i])) for i in set[:i] if haskey(cal[:fs0], i) ];
    [set_upper_bound(ms0_est[i,m], abs(ub * cal[:ms0][i,m])) for i in set[:i] for m in set[:m] if haskey(cal[:ms0], (i, m)) ];
    [set_upper_bound(y0_est[i], abs(ub * cal[:y0][i])) for i in set[:i] if haskey(cal[:y0], i) ];
    [set_upper_bound(fd0_est[i,fd], abs(ub * cal[:fd0][i,fd])) for i in set[:i] for fd in set[:fd] if haskey(cal[:fd0], (i, fd)) ];
    [set_upper_bound(va0_est[va,j], abs(ub * cal[:va0][va,j])) for va in set[:va] for j in set[:j] if haskey(cal[:va0], (va, j)) ];
    [set_upper_bound(a0_est[i], abs(ub * cal[:a0][i])) for i in set[:i] if haskey(cal[:a0], (i)) ];
    [set_upper_bound(x0_est[i], abs(ub * cal[:x0][i])) for i in set[:i] if haskey(cal[:x0], i) ];
    [set_upper_bound(m0_est[i], abs(ub * cal[:m0][i])) for i in set[:i] if haskey(cal[:m0], i) ];
    [set_upper_bound(md0_est[m,i], abs(ub * cal[:md0][m,i])) for m in set[:m] for i in set[:i] if haskey(cal[:md0], (m, i)) ] ;

    [fix(fs0_est[i], cal[:fs0][i], force=true) for i in set[:i] if haskey(cal[:fs0], i)];
    [fix(fs0_est[i], 0, force=true) for i in set[:i] if !haskey(cal[:fs0], i)];

    [fix(va0_est[va,j], cal[:va0][va,j], force=true) for va in set[:va] for j in set[:j] if haskey(cal[:va0], (va, j))];
    [fix(va0_est[va,j], 0, force=true) for va in set[:va] for j in set[:j] if !haskey(cal[:va0], (va, j))];

    [fix(m0_est[i], cal[:m0][i], force=true) for i in set[:i] if haskey(cal[:m0], i)];
    [fix(m0_est[i], 0, force=true) for i in set[:i] if !haskey(cal[:m0], i)];

    # fd_temp = filter!(x->x≠"pce",set[:fd])
    # [fix(fd0_est[i,fd],cal[:fd0][i,fd],force=true) for i in set[:i] for fd in fd_temp if haskey(cal[:fd0],(i,fd))]
    # [fix(fd0_est[i,fd],0,force=true) for i in set[:i] for fd in fd_temp if !haskey(cal[:fd0],(i,fd))]

    [fix(ys0_est[j,i], 0, force=true) for j in set[:oth,:use] for i in set[:i]]

    JuMP.optimize!(calib)

    # Populate resultant Dictionary.
    # io_cal = Dict()
    
    # Using original (i,j) notation...
    # io_cal[:ys0] = convert_type(DataFrame, ys0_est; cols=[:j,:i])
    # io_cal[:fs0] = convert_type(DataFrame, fs0_est; cols=[:i])
    # io_cal[:ms0] = convert_type(DataFrame, ms0_est; cols=[:i,:m])
    # io_cal[:y0]  = convert_type(DataFrame, y0_est;  cols=[:i])
    # io_cal[:id0] = convert_type(DataFrame, id0_est; cols=[:i,:j])
    # io_cal[:fd0] = convert_type(DataFrame, fd0_est; cols=[:i,:fd])
    # io_cal[:va0] = convert_type(DataFrame, va0_est; cols=[:va,:j])
    # io_cal[:a0]  = convert_type(DataFrame, a0_est;  cols=[:i])
    # io_cal[:x0]  = convert_type(DataFrame, x0_est;  cols=[:i])
    # io_cal[:m0]  = convert_type(DataFrame, m0_est;  cols=[:i])
    # io_cal[:md0] = convert_type(DataFrame, md0_est; cols=[:m,:i])
    
    # Using (g,s) notation...
    io_cal[:ys0] = convert_type(DataFrame, ys0_est; cols=[:s,:g])
    io_cal[:fs0] = convert_type(DataFrame, fs0_est; cols=[:g])
    io_cal[:ms0] = convert_type(DataFrame, ms0_est; cols=[:s,:m])
    io_cal[:y0]  = convert_type(DataFrame, y0_est;  cols=[:s])
    io_cal[:id0] = convert_type(DataFrame, id0_est; cols=[:g,:s])
    io_cal[:fd0] = convert_type(DataFrame, fd0_est; cols=[:s,:fd])
    io_cal[:va0] = convert_type(DataFrame, va0_est; cols=[:va,:s])
    io_cal[:a0]  = convert_type(DataFrame, a0_est;  cols=[:g])
    io_cal[:x0]  = convert_type(DataFrame, x0_est;  cols=[:g])
    io_cal[:m0]  = convert_type(DataFrame, m0_est;  cols=[:g])
    io_cal[:md0] = convert_type(DataFrame, md0_est; cols=[:m,:g])

    [io_cal[k] = edit_with(df, Add(:yr, year))[:,unique([:yr; propertynames(df)])]
        for (k, df) in io_cal]
    return io_cal
end