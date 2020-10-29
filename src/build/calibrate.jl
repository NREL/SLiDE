"""
    calibrate(d::Dict, set::Dict; save_build = true, overwrite = false)
    calibrate(year::Int, d::Dict, set::Dict)

# Arguments
- `d::Dict` of DataFrames containing the model data.
- `set::Dict` of Arrays describing region, sector, final demand, etc.
- `year::Int`: year for which to perform calibration

# Keywords
- `save_build = true`
- `overwrite = false`
See [`SLiDE.build_data`](@ref) for keyword argument descriptions.

# Returns
- `d::Dict` of DataFrames containing the model data at the calibration step.
"""
function calibrate(
    dataset::String,
    d::Dict,
    set::Dict;
    save_build::Bool = DEFAULT_SAVE_BUILD,
    overwrite::Bool = DEFAULT_OVERWRITE,
    penalty_nokey = DEFAULT_PENALTY_NOKEY
    )
    CURR_STEP = "calibrate"

    # If there is already calibration data, read it and return.
    d_read = read_build(dataset, CURR_STEP; overwrite = overwrite)
    !(isempty(d_read)) && (return d_read)
    
    # Copy the relevant input DataFrames before making any changes.
    set[:cal] = Symbol.(read_file([SLIDE_DIR,"src","build","parameters"],
        SetInput("list_calibrate.csv", :cal)))
    d = Dict(k => copy(d[k]) for k in set[:cal])
    
    # Initialize a DataFrame to contain results and do the calibration iteratively.
    cal = Dict(k => DataFrame() for k in set[:cal])

    for year in set[:yr]
        cal_yr = calibrate(year, d, set; penalty_nokey = penalty_nokey)
        [cal[k] = [cal[k]; cal_yr[k]] for k in set[:cal]]
    end

    write_build!(dataset, CURR_STEP, cal; save_build = save_build)
    return cal
end


function calibrate(year::Int, io::Dict, set::Dict; penalty_nokey = DEFAULT_PENALTY_NOKEY)
    @info("Calibrating $year data")

    set[:i] = set[:g]   # (!!!!) should just replace in usage.
    set[:j] = set[:s]

    # Prepare the data and initialize the model.
    (cal, idx) = _calibration_input(year, io, set);
    calib = Model(optimizer_with_attributes(Ipopt.Optimizer, "max_cpu_time" => 60.0))

    @variable(calib, ys0_est[j in set[:j], i in set[:i]]   >= 0, start = 0);
    @variable(calib, fs0_est[i in set[:i]]                 >= 0, start = 0);
    @variable(calib, ms0_est[i in set[:i], m in set[:m]]   >= 0, start = 0);
    @variable(calib, y0_est[i in set[:i]]                  >= 0, start = 0);
    @variable(calib, id0_est[i in set[:i],j in set[:j]]    >= 0, start = 0);
    @variable(calib, fd0_est[i in set[:i], fd in set[:fd]] >= 0, start = 0);
    @variable(calib, va0_est[va in set[:va], j in set[:j]] >= 0, start = 0);
    @variable(calib, a0_est[i in set[:i]]                  >= 0, start = 0);
    @variable(calib, x0_est[i in set[:i]]                  >= 0, start = 0);
    @variable(calib, m0_est[i in set[:i]]                  >= 0, start = 0);
    @variable(calib, md0_est[m in set[:m], i in set[:i]]   >= 0, start = 0);

    # --- DEFINE CONSTRAINTS ---------------------------------------------------------------
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

    # --- DEFINE OBJECTIVE -----------------------------------------------------------------
    @objective(calib,Min,
        + sum(abs(cal[:ys0][j,i]) * (ys0_est[j,i] / cal[:ys0][j,i]   - 1)^2 for i in set[:i] for j in set[:j]   if haskey(cal[:ys0], (j,i)))
        + sum(abs(cal[:id0][i,j]) * (id0_est[i,j] / cal[:id0][i,j]   - 1)^2 for i in set[:i] for j in set[:j]   if haskey(cal[:id0], (i,j)))
        + sum(abs(cal[:fs0][i])   * (fs0_est[i]/ cal[:fs0][i]        - 1)^2 for i in set[:i]                    if haskey(cal[:fs0], i))
        + sum(abs(cal[:ms0][i,m]) * (ms0_est[i,m]/ cal[:ms0][i,m]    - 1)^2 for i in set[:i] for m in set[:m]   if haskey(cal[:ms0], (i, m)))
        + sum(abs(cal[:y0][i])    * (y0_est[i]/ cal[:y0][i]          - 1)^2 for i in set[:i]                    if haskey(cal[:y0], i))
        + sum(abs(cal[:fd0][i,fd])* (fd0_est[i,fd] / cal[:fd0][i,fd] - 1)^2 for i in set[:i] for fd in set[:fd] if haskey(cal[:fd0], (i,fd)))
        + sum(abs(cal[:va0][va,j])* (va0_est[va,j] / cal[:va0][va,j] - 1)^2 for va in set[:va] for j in set[:j] if haskey(cal[:va0], (va,j)))
        + sum(abs(cal[:a0][i])    * (a0_est[i] / cal[:a0][i]         - 1)^2 for i in set[:i]                    if haskey(cal[:a0], i))
        + sum(abs(cal[:x0][i])    * (x0_est[i] / cal[:x0][i]         - 1)^2 for i in set[:i]                    if haskey(cal[:x0], i))
        + sum(abs(cal[:m0][i])    * (m0_est[i] / cal[:m0][i]         - 1)^2 for i in set[:i]                    if haskey(cal[:m0], i))
        + sum(abs(cal[:md0][m,i]) * (md0_est[m,i] / cal[:md0][m,i]   - 1)^2 for m in set[:m] for i in set[:i]   if haskey(cal[:md0], (m,i))) 

    + penalty_nokey * (
        + sum(ys0_est[j,i]  for i in set[:i] for j in set[:j]   if !haskey(cal[:ys0], (j,i)))
        + sum(id0_est[i,j]  for i in set[:i] for j in set[:j]   if !haskey(cal[:id0], (i,j)))
        + sum(fs0_est[i]    for i in set[:i]                    if !haskey(cal[:fs0], i))
        + sum(ms0_est[i,m]  for i in set[:i] for m in set[:m]   if !haskey(cal[:ms0], (i, m)))
        + sum(y0_est[i]     for i in set[:i]                    if !haskey(cal[:y0], i))
        + sum(fd0_est[i,fd] for i in set[:i] for fd in set[:fd] if !haskey(cal[:fd0], (i,fd)))
        + sum(va0_est[va,j] for va in set[:va] for j in set[:j] if !haskey(cal[:va0], (va,j)))
        + sum(a0_est[i]     for i in set[:i]                    if !haskey(cal[:a0], i))
        + sum(x0_est[i]     for i in set[:i]                    if !haskey(cal[:x0], i))
        + sum(m0_est[i]     for i in set[:i]                    if !haskey(cal[:m0], i))
        + sum(md0_est[m,i]  for m in set[:m] for i in set[:i]   if !haskey(cal[:md0], (m,i))) 
        )
    );

    # --- SET START VALUE ------------------------------------------------------------------
    [set_start_value(ys0_est[j,i], cal[:ys0][j,i])  for i in set[:i] for j in set[:j]   if haskey(cal[:ys0], (j,i))];
    [set_start_value(id0_est[i,j], cal[:id0][i,j])  for i in set[:i] for j in set[:j]   if haskey(cal[:id0], (i,j))];
    [set_start_value(fs0_est[i],   cal[:fs0][i])    for i in set[:i]                    if haskey(cal[:fs0], i) ];
    [set_start_value(ms0_est[i,m], cal[:ms0][i,m])  for i in set[:i] for m in set[:m]   if haskey(cal[:ms0], (i,m))];
    [set_start_value(y0_est[i],    cal[:y0][i])     for i in set[:i]                    if haskey(cal[:y0], i) ];
    [set_start_value(fd0_est[i,fd],cal[:fd0][i,fd]) for i in set[:i] for fd in set[:fd] if haskey(cal[:fd0], (i,fd))];
    [set_start_value(va0_est[va,j],cal[:va0][va,j]) for va in set[:va] for j in set[:j] if haskey(cal[:va0], (va,j)) ];
    [set_start_value(a0_est[i],    cal[:a0][i])     for i in set[:i]                    if haskey(cal[:a0], (i)) ];
    [set_start_value(x0_est[i],    cal[:x0][i])     for i in set[:i]                    if haskey(cal[:x0], i) ];
    [set_start_value(m0_est[i],    cal[:m0][i])     for i in set[:i]                    if haskey(cal[:m0], i) ];
    [set_start_value(md0_est[m,i], cal[:md0][m,i])  for m in set[:m] for i in set[:i]   if haskey(cal[:md0], (m,i)) ] ;

    # --- SET BOUNDS -----------------------------------------------------------------------
    # multipliers for lower and upper bound relative
    # to each respective variables reference parameter
    lb = 0.1
    ub = 5

    [set_lower_bound(ys0_est[j,i], max(0, lb * cal[:ys0][j,i]))  for i in set[:i] for j in set[:j]   if haskey(cal[:ys0], (j,i))];
    [set_lower_bound(id0_est[i,j], max(0, lb * cal[:id0][i,j]))  for i in set[:i] for j in set[:j]   if haskey(cal[:id0], (i,j))];
    [set_lower_bound(fs0_est[i],   max(0, lb * cal[:fs0][i]))    for i in set[:i]                    if haskey(cal[:fs0], i) ];
    [set_lower_bound(ms0_est[i,m], max(0, lb * cal[:ms0][i,m]))  for i in set[:i] for m in set[:m]   if haskey(cal[:ms0], (i,m))];
    [set_lower_bound(y0_est[i],    max(0, lb * cal[:y0][i]))     for i in set[:i]                    if haskey(cal[:y0], i) ];
    [set_lower_bound(fd0_est[i,fd],max(0, lb * cal[:fd0][i,fd])) for i in set[:i] for fd in set[:fd] if haskey(cal[:fd0], (i,fd))];
    [set_lower_bound(va0_est[va,j],max(0, lb * cal[:va0][va,j])) for va in set[:va] for j in set[:j] if haskey(cal[:va0], (va,j)) ];
    [set_lower_bound(a0_est[i],    max(0, lb * cal[:a0][i]))     for i in set[:i]                    if haskey(cal[:a0], (i)) ];
    [set_lower_bound(x0_est[i],    max(0, lb * cal[:x0][i]))     for i in set[:i]                    if haskey(cal[:x0], i) ];
    [set_lower_bound(m0_est[i],    max(0, lb * cal[:m0][i]))     for i in set[:i]                    if haskey(cal[:m0], i) ];
    [set_lower_bound(md0_est[m,i], max(0, lb * cal[:md0][m,i]))  for m in set[:m] for i in set[:i]   if haskey(cal[:md0], (m,i)) ] ;

    [set_upper_bound(ys0_est[j,i], abs(ub * cal[:ys0][j,i]))  for i in set[:i] for j in set[:j]   if haskey(cal[:ys0],(j,i))];
    [set_upper_bound(id0_est[i,j], abs(ub * cal[:id0][i,j]))  for i in set[:i] for j in set[:j]   if haskey(cal[:id0],(i,j))];
    [set_upper_bound(fs0_est[i],   abs(ub * cal[:fs0][i]))    for i in set[:i]                    if haskey(cal[:fs0], i) ];
    [set_upper_bound(ms0_est[i,m], abs(ub * cal[:ms0][i,m]))  for i in set[:i] for m in set[:m]   if haskey(cal[:ms0],(i,m))];
    [set_upper_bound(y0_est[i],    abs(ub * cal[:y0][i]))     for i in set[:i]                    if haskey(cal[:y0],  i) ]
    [set_upper_bound(fd0_est[i,fd],abs(ub * cal[:fd0][i,fd])) for i in set[:i] for fd in set[:fd] if haskey(cal[:fd0],(i,fd))]
    [set_upper_bound(va0_est[va,j],abs(ub * cal[:va0][va,j])) for va in set[:va] for j in set[:j] if haskey(cal[:va0],(va,j))]
    [set_upper_bound(a0_est[i],    abs(ub * cal[:a0][i]))     for i in set[:i]                    if haskey(cal[:a0], (i))]
    [set_upper_bound(x0_est[i],    abs(ub * cal[:x0][i]))     for i in set[:i]                    if haskey(cal[:x0],  i)]
    [set_upper_bound(m0_est[i],    abs(ub * cal[:m0][i]))     for i in set[:i]                    if haskey(cal[:m0],  i)]
    [set_upper_bound(md0_est[m,i], abs(ub * cal[:md0][m,i]))  for m in set[:m] for i in set[:i]   if haskey(cal[:md0],(m,i))]

    [fix(fs0_est[i],    cal[:fs0][i],    force=true) for i in set[:i]                    if haskey(cal[:fs0], i)];
    [fix(va0_est[va,j], cal[:va0][va,j], force=true) for va in set[:va] for j in set[:j] if haskey(cal[:va0], (va,j))];
    [fix(m0_est[i],     cal[:m0][i],     force=true) for i in set[:i]                    if haskey(cal[:m0], i)];
    
    [fix(ys0_est[j,i], 0, force = true) for j in set[:oth,:use] for i in set[:i]]

    # fd_temp = setdiff(set[:fd],["pce"])
    # [fix(fd0_est[i,fd], 0, force=true) for i in set[:i] for fd in set[:fd] if !haskey(cal[:fd0],(i,fd))]
    # [fix(fs0_est[i],    0, force=true) for i in set[:i]                    if !haskey(cal[:fs0], i)];
    # [fix(va0_est[va,j], 0, force=true) for va in set[:va] for j in set[:j] if !haskey(cal[:va0],(va,j))]
    # [fix(m0_est[i],     0, force=true) for i in set[:i]                    if !haskey(cal[:m0],  i)];
    # [fix(id0_est[i,j],  0, force=true) for i in set[:i] for j in set[:j]   if !haskey(cal[:id0],(i,j))]

    # [fix(fd_est[i], 0, force=true) for i in set[:i] if !haskey(cal[:m0], i)];

    # fd_temp = filter!(x->x≠"pce",set[:fd])
    # [fix(fd0_est[i,fd],cal[:fd0][i,fd],force=true) for i in set[:i] for fd in fd_temp if haskey(cal[:fd0],(i,fd))]

    
    # --- OPTIMIZE AND SAVE RESULTS --------------------------------------------------------
    JuMP.optimize!(calib)

    # Populate resultant Dictionary.
    cal = Dict(k => filter_with(io[k], (yr = year,); drop = true) for k in [:ta0,:tm0])
    cal[:ys0] = convert_type(DataFrame, ys0_est; cols=idx[:ys0])
    cal[:fs0] = convert_type(DataFrame, fs0_est; cols=idx[:fs0])
    cal[:ms0] = convert_type(DataFrame, ms0_est; cols=idx[:ms0])
    cal[:y0]  = convert_type(DataFrame, y0_est;  cols=idx[:y0])
    cal[:id0] = convert_type(DataFrame, id0_est; cols=idx[:id0])
    cal[:fd0] = convert_type(DataFrame, fd0_est; cols=idx[:fd0])
    cal[:va0] = convert_type(DataFrame, va0_est; cols=idx[:va0])
    cal[:a0]  = convert_type(DataFrame, a0_est;  cols=idx[:a0])
    cal[:x0]  = convert_type(DataFrame, x0_est;  cols=idx[:x0])
    cal[:m0]  = convert_type(DataFrame, m0_est;  cols=idx[:m0])
    cal[:md0] = convert_type(DataFrame, md0_est; cols=idx[:md0])

    # Add the year back to the DataFrame and return.
    x = Add(:yr, year)
    [cal[k] = edit_with(df, x)[:, [:yr; idx[k]; :value]] for (k, df) in cal]
    return cal
end


"""
    _calibration_input(year::Int, d::Dict, set::Dict)
This function prepares the input for the calibration routine.

# Arguments
- `yr::Int`
- `d::Dict{Symbol,DataFrame}` of input DataFrames.

# Returns
- `cal::Dict{Symbol,Dict}`
"""
function _calibration_input(year::Int, d::Dict{Symbol,DataFrame}, set::Dict)
    param = Dict()
    param[:cal] = set[:cal]
    param[:tax] = [:ta0, :tm0]
    param[:var] = setdiff(param[:cal], param[:tax])

    # Isolate the current year.
    d = Dict(k => fill_zero(set, filter_with(d[k], (yr = year,); drop = true))
        for k in set[:cal])

    # Save the DataFrame indices in correct order. This will be used to convert the
    # calibration output back into DataFrames.
    idx = Dict(k => findindex(df) for (k,df) in d)

    # Set negative values to zero. In the case of final demand,
    # only set negative values to zero for fd = pce.
    #  d[:fd0][.&(d[:fd0][:,:fd] .== "pce", d[:fd0][:,:value] .< 0),:value] .= 0.0
    # [d[k][d[k][:,:value] .< 0, :value] .= 0.0 for k in param[:var] if k !== :fd0]
    [d[k][d[k][:,:value] .< 0, :value] .= 0.0 for k in param[:var]]

    # Convert the calibration input into DataFrames. Fill zeros for taxes; drop otherwise. 
    cal = Dict{Symbol,Dict}()
    [cal[k] = convert_type(Dict, dropzero(d[k])) for k in param[:var]]
    [cal[k] = fill_zero((set[:g],), convert_type(Dict, d[k])) for k in param[:tax]]
    return (cal, idx)
end