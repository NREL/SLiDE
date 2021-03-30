# include(joinpath(SLIDE_DIR,"src","build","calibrate","calibrate_utils.jl"))

function calibrate_national(
    dataset::String,
    d::Dict,
    set::Dict;
    save_build::Bool=SLiDE.DEFAULT_SAVE_BUILD,
    overwrite::Bool=SLiDE.DEFAULT_OVERWRITE,
    penalty_nokey::AbstractFloat=SLiDE.DEFAULT_PENALTY_NOKEY,
)
    subset = "calibrate"

    # If there is already calibration data, read it and return.
    d_read = SLiDE.read_build(dataset, subset; overwrite=overwrite)
    !(isempty(d_read)) && (return d_read)
    
    # Initialize a DataFrame to contain results and do the calibration iteratively.
    cal = Dict(k => DataFrame() for k in list_parameters!(set, :calibrate))

    for year in set[:yr]
        cal_yr = calibrate_national(d, set, year; penalty_nokey=penalty_nokey)
        [cal[k] = [cal[k]; cal_yr[k]] for k in keys(cal_yr)]
    end
    
    # If no DataFrame was returned by the annual calibrations, replace this with the input.
    [cal[k] = d[k] for (k,df) in cal if isempty(df)]

    SLiDE.write_build!(dataset, subset, cal; save_build=save_build)
    return cal
end


function calibrate_national(
    io::Dict,
    set::Dict,
    year::Int;
    penalty_nokey::AbstractFloat=SLiDE.DEFAULT_PENALTY_NOKEY,
    # multipliers for lower and upper bound relative
    # to each respective variables reference parameter
    lower_bound = SLiDE.DEFAULT_CALIBRATE_LOWER_BOUND,
    upper_bound = SLiDE.DEFAULT_CALIBRATE_UPPER_BOUND,
)
    @info("Calibrating $year data")

    # Save relevant sets to simplify things a little. Then
    S, G, M, VA, FD = set[:s], set[:g], set[:m], set[:va], set[:fd]

    _calibration_set!(set; final_demand=true, value_added=true)
    cal = _calibration_input(io, set, year;
        lower_bound=lower_bound,
        upper_bound=upper_bound,
        zero_negative=true,
    )
    
    calib = Model(optimizer_with_attributes(Ipopt.Optimizer, "max_cpu_time" => 60.0))
    
    @variables(calib, begin
        fd0[g in G, fd in FD], (start=cal[:fd0][g,fd], lower_bound=cal[:fd0_lb][g,fd], upper_bound=cal[:fd0_ub][g,fd])
        va0[va in VA, s in S], (start=cal[:va0][va,s], lower_bound=cal[:va0_lb][va,s], upper_bound=cal[:va0_ub][va,s])
        id0[g in G, s in S], (start=cal[:id0][g,s], lower_bound=cal[:id0_lb][g,s], upper_bound=cal[:id0_ub][g,s])
        ys0[s in S, g in G], (start=cal[:ys0][s,g], lower_bound=cal[:ys0_lb][s,g], upper_bound=cal[:ys0_ub][s,g])
        md0[m in M, g in G], (start=cal[:md0][m,g], lower_bound=cal[:md0_lb][m,g], upper_bound=cal[:md0_ub][m,g])
        ms0[g in G, m in M], (start=cal[:ms0][g,m], lower_bound=cal[:ms0_lb][g,m], upper_bound=cal[:ms0_ub][g,m])
        fs0[g in G], (start=cal[:fs0][g],lower_bound=cal[:fs0_lb][g], upper_bound=cal[:fs0_ub][g])
        a0[g in G],  (start=cal[:a0][g], lower_bound=cal[:a0_lb][g],  upper_bound=cal[:a0_ub][g])
        m0[g in G],  (start=cal[:m0][g], lower_bound=cal[:m0_lb][g],  upper_bound=cal[:m0_ub][g])
        x0[g in G],  (start=cal[:x0][g], lower_bound=cal[:x0_lb][g],  upper_bound=cal[:x0_ub][g])
        y0[g in G],  (start=cal[:y0][g], lower_bound=cal[:y0_lb][g],  upper_bound=cal[:y0_ub][g])
    end)

    # --- DEFINE CONSTRAINTS ---------------------------------------------------------------
    # Market clearing conditions
    @constraints(calib, begin
        mkt_py[g in G], sum(ys0[s,g] for s in S) + fs0[g] == sum(ms0[g,m] for m in set[:m]) + y0[g]
        mkt_pa[g in G], a0[g] == sum(id0[g,s] for s in S) + sum(fd0[g,fd] for fd in FD)
        mkt_pm[m in set[:m]], sum(ms0[g,m] for g in G) == sum(md0[m,g] for g in G)
    end)

    # Zero profit conditions
    @constraints(calib, begin
        prf_y[s in S], sum(ys0[s,g] for g in G) == sum(id0[g,s] for g in G) + sum(va0[va,s] for va in VA)
        prf_a[g in G], a0[g] * (1 - cal[:ta0][g]) + x0[g] == y0[g] + m0[g] * (1 + cal[:tm0][g]) + sum(md0[m,g] for m in set[:m])
    end)

    # --- DEFINE OBJECTIVE -----------------------------------------------------------------
    @objective(calib, Min,
        + sum(abs(cal[:fd0][g,fd])* (fd0[g,fd] / cal[:fd0][g,fd] - 1)^2 for (g,fd) in set[:g,:fd] if cal[:fd0][g,fd] != 0)
        + sum(abs(cal[:va0][va,s])* (va0[va,s] / cal[:va0][va,s] - 1)^2 for (va,s) in set[:va,:s] if cal[:va0][va,s] != 0)
        + sum(abs(cal[:id0][g,s]) * (id0[g,s] / cal[:id0][g,s] - 1)^2 for (g,s) in set[:g,:s] if cal[:id0][g,s] != 0)
        + sum(abs(cal[:ys0][s,g]) * (ys0[s,g] / cal[:ys0][s,g] - 1)^2 for (s,g) in set[:s,:g] if cal[:ys0][s,g] != 0)
        + sum(abs(cal[:ms0][g,m]) * (ms0[g,m] / cal[:ms0][g,m] - 1)^2 for (g,m) in set[:g,:m] if cal[:ms0][g,m] != 0)
        + sum(abs(cal[:md0][m,g]) * (md0[m,g] / cal[:md0][m,g] - 1)^2 for (m,g) in set[:m,:g] if cal[:md0][m,g] != 0)
        + sum(abs(cal[:fs0][g]) * (fs0[g]/ cal[:fs0][g] - 1)^2 for g in G if cal[:fs0][g] != 0)
        + sum(abs(cal[:a0][g])  * (a0[g] / cal[:a0][g]  - 1)^2 for g in G if cal[:a0][g]  != 0)
        + sum(abs(cal[:m0][g])  * (m0[g] / cal[:m0][g]  - 1)^2 for g in G if cal[:m0][g]  != 0)
        + sum(abs(cal[:x0][g])  * (x0[g] / cal[:x0][g]  - 1)^2 for g in G if cal[:x0][g]  != 0)
        + sum(abs(cal[:y0][g])  * (y0[g] / cal[:y0][g]  - 1)^2 for g in G if cal[:y0][g]  != 0)

    + penalty_nokey * (
        + sum(fd0[g,fd] for (g,fd) in set[:g,:fd] if cal[:fd0][g,fd] == 0)
        + sum(va0[va,s] for (va,s) in set[:va,:s] if cal[:va0][va,s] == 0)
        + sum(id0[g,s] for (g,s) in set[:g,:s] if cal[:id0][g,s] == 0)
        + sum(ys0[s,g] for (s,g) in set[:s,:g] if cal[:ys0][s,g] == 0)
        + sum(ms0[g,m] for (g,m) in set[:g,:m] if cal[:ms0][g,m] == 0)
        + sum(md0[m,g] for (m,g) in set[:m,:g] if cal[:md0][m,g] == 0)
        + sum(fs0[g] for g in G if cal[:fs0][g] == 0)
        + sum(a0[g]  for g in G if cal[:a0][g]  == 0)
        + sum(m0[g]  for g in G if cal[:m0][g]  == 0)
        + sum(x0[g]  for g in G if cal[:x0][g]  == 0)
        + sum(y0[g]  for g in G if cal[:y0][g]  == 0)
        )
    )
    
    # Fix "certain parameters" to their original values: fs0, va0, m0.
    [fix(va0[va,s], cal[:va0][va,s], force=true) for (va,s) in set[:va,:s]]
    [fix(fs0[g], cal[:fs0][g], force=true) for g in G]
    [fix(m0[g],  cal[:m0][g],  force=true) for g in G]
    
    # Fix other/use sector output to zero.
    [fix(ys0[s,g], 0, force = true) for s in set[:oth,:use] for g in G]
    
    # --- OPTIMIZE AND SAVE RESULTS --------------------------------------------------------
    JuMP.optimize!(calib)

    return _calibration_output(calib, set, year; region=false)
end


# set = merge(Dict(), read_from(joinpath("src","build","readfiles","setlist.yml")))
# SLiDE._set_sector!(set, set[:summary])

# io = read_from("data/state_model/build/partition")

# year = 1997

# cal = read_from("data/state_model/build/calibrate");
# [cal[k] = filter_with(df, (yr=year,); drop=false) for (k,df) in cal]

# cal3 = calibrate_national(io, set, year)
# dcomp = benchmark_against(cal3, cal)