"""
    calibrate(d::Dict, set::Dict; save_build=true, overwrite=false)
    calibrate(year::Int, d::Dict, set::Dict)

# Arguments
- `d::Dict` of DataFrames containing the model data.
- `set::Dict` of Arrays describing region, sector, final demand, etc.
- `year::Int`: year for which to perform calibration

# Keywords
- `save_build = true`
- `overwrite = false`
See [`SLiDE.build`](@ref) for keyword argument descriptions.

# Returns
- `d::Dict` of DataFrames containing the model data at the calibration step.
"""
function calibrate(
    dataset::String,
    d::Dict,
    set::Dict;
    save_build::Bool=DEFAULT_SAVE_BUILD,
    overwrite::Bool=DEFAULT_OVERWRITE,
    penalty_nokey::AbstractFloat=DEFAULT_PENALTY_NOKEY,
)
    CURR_STEP = "calibrate"

    # If there is already calibration data, read it and return.
    d_read = read_build(dataset, CURR_STEP; overwrite = overwrite)
    !(isempty(d_read)) && (return d_read)
    
    # Copy the relevant input DataFrames before making any changes.
    _calibration_set!(set)
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


function calibrate(
    year::Int,
    io::Dict,
    set::Dict;
    penalty_nokey::AbstractFloat=DEFAULT_PENALTY_NOKEY,
)
    @info("Calibrating $year data")

    # Prepare the data and initialize the model.
    _calibration_set!(set)
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
        sum(ys0_est[j,i] for j in set[:j]) + fs0_est[i] ==
        sum(ms0_est[i,m] for m in set[:m]) + y0_est[i]
    );

    @constraint(calib,mkt_pa[i in set[:i]],
        a0_est[i] ==
        sum(id0_est[i,j] for j in set[:j]) + sum(fd0_est[i,fd] for fd in set[:fd])
    );

    @constraint(calib,mkt_pm[m in set[:m]],
        sum(ms0_est[i,m] for i in set[:i]) ==
        sum(md0_est[m,i] for i in set[:i])
    );

    @constraint(calib,prf_y[j in set[:j]],
        sum(ys0_est[j,i] for i in set[:i]) ==
        sum(id0_est[i,j] for i in set[:i]) + sum(va0_est[va,j] for va in set[:va])
    );

    @constraint(calib,prf_a[i in set[:i]],
        a0_est[i] * (1 - cal[:ta0][i]) + x0_est[i] ==
        y0_est[i] + m0_est[i] * (1 + cal[:tm0][i]) + sum(md0_est[m,i] for m in set[:m])
    );

    # --- DEFINE OBJECTIVE -----------------------------------------------------------------
    @objective(calib,Min,
        + sum(abs(cal[:ys0][j,i]) * (ys0_est[j,i] / cal[:ys0][j,i]   - 1)^2 for (j,i)  in set[:j,:i]  if cal[:ys0][j,i]  != 0)
        + sum(abs(cal[:id0][i,j]) * (id0_est[i,j] / cal[:id0][i,j]   - 1)^2 for (i,j)  in set[:i,:j]  if cal[:id0][i,j]  != 0)
        + sum(abs(cal[:fs0][i])   * (fs0_est[i]/ cal[:fs0][i]        - 1)^2 for  i     in set[:i]     if cal[:fs0][i]    != 0)
        + sum(abs(cal[:ms0][i,m]) * (ms0_est[i,m]/ cal[:ms0][i,m]    - 1)^2 for (i,m)  in set[:i,:m]  if cal[:ms0][i,m]  != 0)
        + sum(abs(cal[:y0][i])    * (y0_est[i]/ cal[:y0][i]          - 1)^2 for  i     in set[:i]     if cal[:y0][i]     != 0)
        + sum(abs(cal[:fd0][i,fd])* (fd0_est[i,fd] / cal[:fd0][i,fd] - 1)^2 for (i,fd) in set[:i,:fd] if cal[:fd0][i,fd] != 0)
        + sum(abs(cal[:va0][va,j])* (va0_est[va,j] / cal[:va0][va,j] - 1)^2 for (va,j) in set[:va,:j] if cal[:va0][va,j] != 0)
        + sum(abs(cal[:a0][i])    * (a0_est[i] / cal[:a0][i]         - 1)^2 for  i     in set[:i]     if cal[:a0][i]     != 0)
        + sum(abs(cal[:x0][i])    * (x0_est[i] / cal[:x0][i]         - 1)^2 for  i     in set[:i]     if cal[:x0][i]     != 0)
        + sum(abs(cal[:m0][i])    * (m0_est[i] / cal[:m0][i]         - 1)^2 for  i     in set[:i]     if cal[:m0][i]     != 0)
        + sum(abs(cal[:md0][m,i]) * (md0_est[m,i] / cal[:md0][m,i]   - 1)^2 for (m,i)  in set[:m,:i]  if cal[:md0][m,i]  != 0)

    + penalty_nokey * (
        + sum(ys0_est[j,i]  for (j,i)  in set[:j,:i]  if cal[:ys0][j,i]  == 0)
        + sum(id0_est[i,j]  for (i,j)  in set[:i,:j]  if cal[:id0][i,j]  == 0)
        + sum(fs0_est[i]    for  i     in set[:i]     if cal[:fs0][i]    == 0)
        + sum(ms0_est[i,m]  for (i,m)  in set[:i,:m]  if cal[:ms0][i,m]  == 0)
        + sum(y0_est[i]     for  i     in set[:i]     if cal[:y0][i]     == 0)
        + sum(fd0_est[i,fd] for (i,fd) in set[:i,:fd] if cal[:fd0][i,fd] == 0)
        + sum(va0_est[va,j] for (va,j) in set[:va,:j] if cal[:va0][va,j] == 0)
        + sum(a0_est[i]     for  i     in set[:i]     if cal[:a0][i]     == 0)
        + sum(x0_est[i]     for  i     in set[:i]     if cal[:x0][i]     == 0)
        + sum(m0_est[i]     for  i     in set[:i]     if cal[:m0][i]     == 0)
        + sum(md0_est[m,i]  for (m,i)  in set[:m,:i]  if cal[:md0][m,i]  == 0)
        )
    );

    # --- SET START VALUE ------------------------------------------------------------------
    [set_start_value(ys0_est[j,i], cal[:ys0][j,i])  for (j,i)  in set[:j,:i]  ]
    [set_start_value(id0_est[i,j], cal[:id0][i,j])  for (i,j)  in set[:i,:j]  ]
    [set_start_value(fs0_est[i],   cal[:fs0][i])    for  i     in set[:i]     ]
    [set_start_value(ms0_est[i,m], cal[:ms0][i,m])  for (i,m)  in set[:i,:m]  ]
    [set_start_value(y0_est[i],    cal[:y0][i])     for  i     in set[:i]     ]
    [set_start_value(fd0_est[i,fd],cal[:fd0][i,fd]) for (i,fd) in set[:i,:fd] ]
    [set_start_value(va0_est[va,j],cal[:va0][va,j]) for (va,j) in set[:va,:j] ]
    [set_start_value(a0_est[i],    cal[:a0][i])     for  i     in set[:i]     ]
    [set_start_value(x0_est[i],    cal[:x0][i])     for  i     in set[:i]     ]
    [set_start_value(m0_est[i],    cal[:m0][i])     for  i     in set[:i]     ]
    [set_start_value(md0_est[m,i], cal[:md0][m,i])  for (m,i)  in set[:m,:i]  ]

    # --- SET BOUNDS -----------------------------------------------------------------------
    # multipliers for lower and upper bound relative
    # to each respective variables reference parameter
    lb = DEFAULT_CALIBRATE_LOWER_BOUND
    ub = DEFAULT_CALIBRATE_UPPER_BOUND

    [set_lower_bound(ys0_est[j,i], max(0, lb * cal[:ys0][j,i]))  for (j,i)  in set[:j,:i]  ]
    [set_lower_bound(id0_est[i,j], max(0, lb * cal[:id0][i,j]))  for (i,j)  in set[:i,:j]  ]
    [set_lower_bound(fs0_est[i],   max(0, lb * cal[:fs0][i]))    for  i     in set[:i]     ]
    [set_lower_bound(ms0_est[i,m], max(0, lb * cal[:ms0][i,m]))  for (i,m)  in set[:i,:m]  ]
    [set_lower_bound(y0_est[i],    max(0, lb * cal[:y0][i]))     for  i     in set[:i]     ]
    [set_lower_bound(fd0_est[i,fd],max(0, lb * cal[:fd0][i,fd])) for (i,fd) in set[:i,:fd] ]
    [set_lower_bound(va0_est[va,j],max(0, lb * cal[:va0][va,j])) for (va,j) in set[:va,:j] ]
    [set_lower_bound(a0_est[i],    max(0, lb * cal[:a0][i]))     for  i     in set[:i]     ]
    [set_lower_bound(x0_est[i],    max(0, lb * cal[:x0][i]))     for  i     in set[:i]     ]
    [set_lower_bound(m0_est[i],    max(0, lb * cal[:m0][i]))     for  i     in set[:i]     ]
    [set_lower_bound(md0_est[m,i], max(0, lb * cal[:md0][m,i]))  for (m,i)  in set[:m,:i]  ]

    [set_upper_bound(ys0_est[j,i], abs(ub * cal[:ys0][j,i]))  for (i,j)  in set[:i,:j]  ]
    [set_upper_bound(id0_est[i,j], abs(ub * cal[:id0][i,j]))  for (i,j)  in set[:i,:j]  ]
    [set_upper_bound(fs0_est[i],   abs(ub * cal[:fs0][i]))    for  i     in set[:i]     ]
    [set_upper_bound(ms0_est[i,m], abs(ub * cal[:ms0][i,m]))  for (i,m)  in set[:i,:m]  ]
    [set_upper_bound(y0_est[i],    abs(ub * cal[:y0][i]))     for  i     in set[:i]     ]
    [set_upper_bound(fd0_est[i,fd],abs(ub * cal[:fd0][i,fd])) for (i,fd) in set[:i,:fd] ]
    [set_upper_bound(va0_est[va,j],abs(ub * cal[:va0][va,j])) for (va,j) in set[:va,:j] ]
    [set_upper_bound(a0_est[i],    abs(ub * cal[:a0][i]))     for  i     in set[:i]     ]
    [set_upper_bound(x0_est[i],    abs(ub * cal[:x0][i]))     for  i     in set[:i]     ]
    [set_upper_bound(m0_est[i],    abs(ub * cal[:m0][i]))     for  i     in set[:i]     ]
    [set_upper_bound(md0_est[m,i], abs(ub * cal[:md0][m,i]))  for (m,i)  in set[:m,:i]  ]

    # Fix "certain parameters" to their original values: fs0, va0, m0.
    [fix(fs0_est[i],    cal[:fs0][i],    force=true) for  i     in set[:i]     ]
    [fix(va0_est[va,j], cal[:va0][va,j], force=true) for (va,j) in set[:va,:j] ]
    [fix(m0_est[i],     cal[:m0][i],     force=true) for  i     in set[:i]     ]
    
    # Fix other/use sector output to zero.
    [fix(ys0_est[j,i], 0, force = true) for j in set[:oth,:use] for i in set[:i]]
    
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
This function prepares the input for the calibration routine:
    1. Select parameters relevant to the calibration routine.
    2. For all parameters except taxes (ta0, tm0), set negative values to zero.
        In the case of final demand, only set negative values to zero for
        `fd = pce`.
    3. Fill all "missing" values with zeros to generate a complete dataset. This is relevant
        to how the penalty for missing keys is applied in the objective function.

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
    d = Dict(k => fill_zero(filter_with(d[k], (yr=year,); drop=true); with=set)
        for k in param[:cal])

    # Save the DataFrame indices in correct order. This will be used to convert the
    # calibration output back into DataFrames.
    idx = Dict(k => findindex(df) for (k,df) in d)

    # Set negative values to zero. In the case of final demand,
    # only set negative values to zero for fd = pce.
     d[:fd0][.&(d[:fd0][:,:fd] .== "pce", d[:fd0][:,:value] .< 0),:value] .= 0.0
     d[:fd0][.&(d[:fd0][:,:fd] .== "C", d[:fd0][:,:value] .< 0),:value] .= 0.0
    [d[k][d[k][:,:value] .< 0, :value] .= 0.0 for k in param[:var] if k !== :fd0]

    # Convert the calibration input into DataFrames. Fill zeros for taxes; drop otherwise. 
    cal = Dict(k => convert_type(Dict, d[k]) for k in param[:cal])
    return (cal, idx)
end


"""
"""
function _calibration_set!(set)
    # !!!! replace in usage.
    !haskey(set, :i) && (set[:i] = set[:g])
    !haskey(set, :j) && (set[:j] = set[:s])

    !haskey(set, (:r,:m)) && SLiDE.add_permutation!(set, (:r,:m))
    !haskey(set, (:r,:g)) && SLiDE.add_permutation!(set, (:r,:g))
    !haskey(set, (:r,:s)) && SLiDE.add_permutation!(set, (:r,:s))
    !haskey(set, (:r,:g,:s)) && SLiDE.add_permutation!(set, (:r,:g,:s))
    !haskey(set, (:r,:s,:g)) && SLiDE.add_permutation!(set, (:r,:s,:g))
    !haskey(set, (:r,:g,:m)) && SLiDE.add_permutation!(set, (:r,:g,:m))
    !haskey(set, (:r,:m,:g)) && SLiDE.add_permutation!(set, (:r,:m,:g))
    
    !haskey(set, (:i,:j)) && SLiDE.add_permutation!(set, (:i,:j))
    !haskey(set, (:j,:i)) && SLiDE.add_permutation!(set, (:j,:i))
    !haskey(set, (:i,:m)) && SLiDE.add_permutation!(set, (:i,:m))
    !haskey(set, (:m,:i)) && SLiDE.add_permutation!(set, (:m,:i))
    !haskey(set, (:i,:fd)) && SLiDE.add_permutation!(set, (:i,:fd))
    !haskey(set, (:va,:j)) && SLiDE.add_permutation!(set, (:va,:j))

    if !haskey(set,:cal)
        set[:cal] = Symbol.(read_file([SLIDE_DIR,"src","build","parameters"],
            SetInput("list_calibrate.csv", :cal)))
    end
    return set
end