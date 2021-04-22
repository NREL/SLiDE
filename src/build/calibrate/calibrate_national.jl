"""
    calibrate_national(dataset::Dataset, io::Dict, set::Dict)
    calibrate_national(io::Dict, set::Dict, year::Integer)

# Arguments
- `d::Dict` of DataFrames containing the model data.
- `set::Dict` of Arrays describing region, sector, final demand, etc.
- `year::Int`: year for which to perform calibration

# Returns
- `d::Dict` of DataFrames containing the model data at the calibration step.
"""
function calibrate_national(
    io::Dict,
    set::Dict,
    year::Int;
    zeropenalty=DEFAULT_CALIBRATE_ZEROPENALTY[:io],
    lower_factor=DEFAULT_CALIBRATE_BOUND[:io,:lower],
    upper_factor=DEFAULT_CALIBRATE_BOUND[:io,:upper],
)
    @info("Calibrating $year data")

    d, set = _national_calibration_input(io, set, year, Dict)
    S, G, M, VA, FD = set[:s], set[:g], set[:m], set[:va], set[:fd]
    
    calib = Model(optimizer_with_attributes(Ipopt.Optimizer, "max_cpu_time"=>60.0))
    
    @variables(calib, begin
        fd0[g in G, fd in FD]>=0, (start=d[:fd0][g,fd])
        va0[va in VA, s in S]>=0, (start=d[:va0][va,s])
        id0[g in G, s in S]>=0, (start=d[:id0][g,s])
        ys0[s in S, g in G]>=0, (start=d[:ys0][s,g])
        md0[m in M, g in G]>=0, (start=d[:md0][m,g])
        ms0[g in G, m in M]>=0, (start=d[:ms0][g,m])
        a0[g in G]>=0,  (start=d[:a0][g])
        m0[g in G]>=0,  (start=d[:m0][g])
        x0[g in G]>=0,  (start=d[:x0][g])
        y0[g in G]>=0,  (start=d[:y0][g])
        fs0[g in G]>=0, (start=d[:fs0][g])
    end)

    set_bounds!(calib; lower_factor=lower_factor, upper_factor=upper_factor, allow_negative=false)
    
    # --- DEFINE CONSTRAINTS ---------------------------------------------------------------
    # Zero profit conditions
    @constraints(calib, begin
        PROFIT_A[g in G], (
            (1 - d[:ta0][g])*a0[g] + x0[g] ==
            (1 + d[:tm0][g])*m0[g] + y0[g] + sum(md0[m,g] for m in M)
        )
        PROFIT_Y[s in S], (
            sum(ys0[s,g] for g in G) ==
            sum(id0[g,s] for g in G) + sum(va0[va,s] for va in VA)
        )
    end)

    # Market clearing conditions
    @constraints(calib, begin
        MARKET_PY[g in G], (
            sum(ms0[g,m] for m in M) + y0[g] ==
            sum(ys0[s,g] for s in S) + fs0[g]
        )
        MARKET_PA[g in G], a0[g] == sum(id0[g,s] for s in S) + sum(fd0[g,fd] for fd in FD)
        MARKET_PM[m in M], sum(ms0[g,m] for g in G) == sum(md0[m,g] for g in G)
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
    + zeropenalty * (
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
    # Fix other/use sector output to zero.
    fix!(calib; condition=iszero)
    fix!(calib, [:fs0,:m0,:va0])
    fix!(calib, :ys0, [set[:oth,:use], G]; value=0)

    # --- OPTIMIZE AND SAVE RESULTS --------------------------------------------------------
    JuMP.optimize!(calib)
    cal = _calibration_output(calib, set, year; region=false)
    [cal[k] = filter_with(io[k],(yr=year,)) for k in setdiff(keys(io),keys(cal))]
    return cal
end


calibrate_national(args...; kwargs...) = calibrate(calibrate_national, args...; kwargs...)



"""
    _national_calibration_input(d::Dict, set::Dict, year::Int)
    _national_calibration_input(d::Dict, set::Dict)
This function prepares the input for the calibration routine:
1. Select parameters relevant to the calibration routine.
2. For all parameters except taxes (ta0, tm0), set negative values to zero.
    In the case of final demand, only set negative values to zero for `fd = pce`.
    ```math
    \\begin{aligned}
    x = max\\left\\{0, x\\right\\}
    fd_{g,fd} = max\\{0, fd_{g,fd}\\}
    ```
3. Fill all "missing" values with zeros to generate a complete dataset. This is relevant
    to how the penalty for missing keys is applied in the objective function.

# Arguments
- `d::Dict{Symbol,DataFrame}`: all input *parameters*
- `set::Dict`
- `year::Int` overwhich to calibrate

# Returns
- `d::Dict{Symbol, Dict}`: input *variables*
"""
function _national_calibration_input(d, set)
    variables = setdiff(list!(set, Dataset(""; build="io", step="calibrate")), list("taxes"))
    
    # Handle negatives.
    if haskey(d,:fd0)
        zero_negative!(d[:fd0], :fd=>"pce")
        zero_negative!(d[:fd0], :fd=>"C")
    end
    
    zero_negative!(d, setdiff(variables,[:fd0]))
    
    # Finally, add appropriate index permutations to the set list.
    _calibration_set!(set; final_demand=true, value_added=true)

    return d, set
end


function _national_calibration_input(args...; kwargs...)
    return _calibration_input(_national_calibration_input, args...; kwargs...)
end