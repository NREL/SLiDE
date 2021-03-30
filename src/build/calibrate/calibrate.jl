function calibrate_national(
    dataset::String,
    io::Dict,
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
        cal_yr = calibrate_national(io, set, year; penalty_nokey=penalty_nokey)
        [cal[k] = [cal[k]; cal_yr[k]] for k in keys(cal_yr)]
    end
    
    # If no DataFrame was returned by the annual calibrations, replace this with the input.
    [cal[k] = io[k] for (k,df) in cal if isempty(df)]

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

    # Save relevant sets to simplify things a little.
    S, G, M, VA, FD = set[:s], set[:g], set[:m], set[:va], set[:fd]
    
    SLiDE._calibration_set!(set; final_demand=true, value_added=true)
    d = SLiDE._national_calibration_input(io, set, year;
        lower_bound=lower_bound,
        upper_bound=upper_bound,
    )
    
    calib = Model(optimizer_with_attributes(Ipopt.Optimizer, "max_cpu_time"=>60.0))
    
    @variables(calib, begin
        fd0[g in G, fd in FD], (start=d[:fd0][g,fd], lower_bound=d[:fd0_lb][g,fd], upper_bound=d[:fd0_ub][g,fd])
        va0[va in VA, s in S], (start=d[:va0][va,s], lower_bound=d[:va0_lb][va,s], upper_bound=d[:va0_ub][va,s])
        id0[g in G, s in S], (start=d[:id0][g,s], lower_bound=d[:id0_lb][g,s], upper_bound=d[:id0_ub][g,s])
        ys0[s in S, g in G], (start=d[:ys0][s,g], lower_bound=d[:ys0_lb][s,g], upper_bound=d[:ys0_ub][s,g])
        md0[m in M, g in G], (start=d[:md0][m,g], lower_bound=d[:md0_lb][m,g], upper_bound=d[:md0_ub][m,g])
        ms0[g in G, m in M], (start=d[:ms0][g,m], lower_bound=d[:ms0_lb][g,m], upper_bound=d[:ms0_ub][g,m])
        a0[g in G],  (start=d[:a0][g], lower_bound=d[:a0_lb][g],  upper_bound=d[:a0_ub][g])
        m0[g in G],  (start=d[:m0][g], lower_bound=d[:m0_lb][g],  upper_bound=d[:m0_ub][g])
        x0[g in G],  (start=d[:x0][g], lower_bound=d[:x0_lb][g],  upper_bound=d[:x0_ub][g])
        y0[g in G],  (start=d[:y0][g], lower_bound=d[:y0_lb][g],  upper_bound=d[:y0_ub][g])
        fs0[g in G], (start=d[:fs0][g],lower_bound=d[:fs0_lb][g], upper_bound=d[:fs0_ub][g])
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
        prf_a[g in G], a0[g] * (1 - d[:ta0][g]) + x0[g] == y0[g] + m0[g] * (1 + d[:tm0][g]) + sum(md0[m,g] for m in set[:m])
    end)
    
    # --- DEFINE OBJECTIVE -----------------------------------------------------------------
    @objective(calib, Min,
        + sum(abs(d[:fd0][g,fd])* (fd0[g,fd]/d[:fd0][g,fd] - 1)^2 for (g,fd) in set[:g,:fd] if d[:fd0][g,fd] != 0)
        + sum(abs(d[:va0][va,s])* (va0[va,s]/d[:va0][va,s] - 1)^2 for (va,s) in set[:va,:s] if d[:va0][va,s] != 0)
        + sum(abs(d[:id0][g,s]) * (id0[g,s]/d[:id0][g,s] - 1)^2 for (g,s) in set[:g,:s] if d[:id0][g,s] != 0)
        + sum(abs(d[:ys0][s,g]) * (ys0[s,g]/d[:ys0][s,g] - 1)^2 for (s,g) in set[:s,:g] if d[:ys0][s,g] != 0)
        + sum(abs(d[:ms0][g,m]) * (ms0[g,m]/d[:ms0][g,m] - 1)^2 for (g,m) in set[:g,:m] if d[:ms0][g,m] != 0)
        + sum(abs(d[:md0][m,g]) * (md0[m,g]/d[:md0][m,g] - 1)^2 for (m,g) in set[:m,:g] if d[:md0][m,g] != 0)
        + sum(abs(d[:fs0][g]) * (fs0[g]/d[:fs0][g] - 1)^2 for g in G if d[:fs0][g] != 0)
        + sum(abs(d[:a0][g])  * (a0[g] /d[:a0][g]  - 1)^2 for g in G if d[:a0][g]  != 0)
        + sum(abs(d[:m0][g])  * (m0[g] /d[:m0][g]  - 1)^2 for g in G if d[:m0][g]  != 0)
        + sum(abs(d[:x0][g])  * (x0[g] /d[:x0][g]  - 1)^2 for g in G if d[:x0][g]  != 0)
        + sum(abs(d[:y0][g])  * (y0[g] /d[:y0][g]  - 1)^2 for g in G if d[:y0][g]  != 0)
    + penalty_nokey * (
        + sum(fd0[g,fd] for (g,fd) in set[:g,:fd] if d[:fd0][g,fd] == 0)
        + sum(va0[va,s] for (va,s) in set[:va,:s] if d[:va0][va,s] == 0)
        + sum(id0[g,s] for (g,s) in set[:g,:s] if d[:id0][g,s] == 0)
        + sum(ys0[s,g] for (s,g) in set[:s,:g] if d[:ys0][s,g] == 0)
        + sum(ms0[g,m] for (g,m) in set[:g,:m] if d[:ms0][g,m] == 0)
        + sum(md0[m,g] for (m,g) in set[:m,:g] if d[:md0][m,g] == 0)
        + sum(fs0[g] for g in G if d[:fs0][g] == 0)
        + sum(a0[g]  for g in G if d[:a0][g]  == 0)
        + sum(m0[g]  for g in G if d[:m0][g]  == 0)
        + sum(x0[g]  for g in G if d[:x0][g]  == 0)
        + sum(y0[g]  for g in G if d[:y0][g]  == 0)
        )
    )
    
    # Fix "certain parameters" to their original values: fs0, va0, m0.
    fix!(calib, d, set, :va0, (:va,:s))
    fix!(calib, d, set, [:fs0,:m0], :g)
    
    # Fix other/use sector output to zero.
    fix!(calib, d, :ys0, [set[:oth,:use], G]; value=0)
    
    # --- OPTIMIZE AND SAVE RESULTS --------------------------------------------------------
    JuMP.optimize!(calib)

    return _calibration_output(calib, set, year; region=false)
    # return calib
end


"""
This function prepares
- Filling zeros
- 

```math
\\begin{aligned}
x = max\\left\\{0, x\\right\\}
fd_{g,fd} = max\\{0, fd_{g,fd}\\}
```

# Arguments
- `d::Dict{Symbol,DataFrame}`: all input *parameters*
- `set::Dict`
- `year::Int` overwhich to calibrate

# Returns
- `d::Dict{Symbol, Dict}`: input *variables*. Input *variables* include all input parameters
    with the exception of taxes (`ta0`,`tm0`,`ty0`).
"""
function _national_calibration_input(d, set;
    lower_bound=SLiDE.DEFAULT_CALIBRATE_LOWER_BOUND,
    upper_bound=SLiDE.DEFAULT_CALIBRATE_UPPER_BOUND,
    zero_negative::Bool=true,
)
    variables = setdiff(SLiDE.list_parameters!(set,:calibrate), SLiDE.list_parameters!(set,:taxes))

    # Fill zeros.
    d = Dict(k => fill_zero(df; with=set) for (k,df) in d)
    
    # Handle negatives.
    if haskey(d,:fd0)
        SLiDE.zero_negative!(d[:fd0], :fd=>"pce")
        SLiDE.zero_negative!(d[:fd0], :fd=>"C")
    end
    SLiDE.zero_negative!(d, setdiff(variables, [:fd0]))

    # Set bounds.
    SLiDE.set_lower_bound!(d, variables; factor=lower_bound, zero_negative=zero_negative)
    SLiDE.set_upper_bound!(d, variables; factor=upper_bound, zero_negative=zero_negative)

    d = Dict{Symbol,Dict}(k => convert_type(Dict, df) for (k,df) in d)
    return d
end


function _national_calibration_input(d, set, year;
    lower_bound=SLiDE.DEFAULT_CALIBRATE_LOWER_BOUND,
    upper_bound=SLiDE.DEFAULT_CALIBRATE_UPPER_BOUND,
    zero_negative::Bool=true,
)
    d = Dict(k => filter_with(df, (yr=year,); drop=true) for (k,df) in d)
    d = _national_calibration_input(d, set;
        lower_bound=lower_bound,
        upper_bound=upper_bound,
        zero_negative=zero_negative,
    )
    return d
end