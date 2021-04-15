"""
    calibrate_regional(io::Dict, set::Dict, year::Integer)

# Arguments
- `d::Dict` of DataFrames containing the model data.
- `set::Dict` of Arrays describing region, sector, final demand, etc.
- `year::Int`: year for which to perform calibration

# Returns
- `d::Dict` of DataFrames containing the model data at the calibration step.
"""
function calibrate_regional(
    io::Dict,
    set::Dict,
    year::Int;
    # zeropenalty::AbstractFloat=SLiDE.DEFAULT_PENALTY_NOKEY,
    zeropenalty::AbstractFloat=1E7,
    # !!!! define as SLiDE constants
    lower_bound=0.25,
    upper_bound=1.75,
    lower_bound_seds=0.75,
    upper_bound_seds=1.25,
    optimize::Bool=true,
)
    @info("Calibrating $year data")

    SLiDE._calibration_set!(set; region=true, energy=true)
    d = _energy_calibration_input(io, set, year, Dict;
        lower_bound=lower_bound,
        upper_bound=upper_bound,
    )

    S, G, M, R, NAT = set[:s], set[:g], set[:m], set[:r], set[:nat]
    
    calib = Model(optimizer_with_attributes(Ipopt.Optimizer, "max_cpu_time"=>120.0))

    # ----- INITIALIZE VARIABLES -----------------------------------------------------------
    @variables(calib, begin
        # production
        ys0[r in R, s in S, g in G], (start=d[:ys0][r,s,g], lower_bound=d[:ys0_lb][r,s,g])
        id0[r in R, s in G, g in S], (start=d[:id0][r,g,s], lower_bound=d[:id0_lb][r,g,s])
        ld0[r in R, s in S], (start=d[:ld0][r,s], lower_bound=0)
        kd0[r in R, s in S], (start=d[:kd0][r,s], lower_bound=0)
        # trade
        a0[r in R, g in G],  (start=d[:a0 ][r,g], lower_bound=d[:a0_lb][r,g])
        nd0[r in R, g in G], (start=d[:nd0][r,g], lower_bound=d[:nd0_lb][r,g])
        dd0[r in R, g in G], (start=d[:dd0][r,g], lower_bound=d[:dd0_lb][r,g])
        m0[r in R, g in G],  (start=d[:m0 ][r,g], lower_bound=d[:m0_lb][r,g])
        # supply
        s0[r in R, g in G],  (start=d[:s0 ][r,g], lower_bound=d[:s0_lb][r,g])
        xd0[r in R, g in G], (start=d[:xd0][r,g], lower_bound=d[:xd0_lb][r,g])
        xn0[r in R, g in G], (start=d[:xn0][r,g], lower_bound=d[:xn0_lb][r,g])
        x0[r in R, g in G],  (start=d[:x0 ][r,g], lower_bound=d[:x0_lb][r,g])
        rx0[r in R, g in G], (start=d[:rx0][r,g], lower_bound=d[:rx0_lb][r,g])
        # demand
        yh0[r in R, g in G], (start=d[:yh0][r,g], lower_bound=0)
        cd0[r in R, g in G], (start=d[:cd0][r,g], lower_bound=0)
        i0[r in R, g in G],  (start=d[:i0 ][r,g], lower_bound=d[:i0_lb][r,g])
        g0[r in R, g in G] , (start=d[:g0 ][r,g], lower_bound=d[:g0_lb][r,g])
        # margin
        nm0[r in R, g in G, m in M], (start=d[:nm0][r,g,m], lower_bound=d[:nm0_lb][r,g,m])
        dm0[r in R, g in G, m in M], (start=d[:dm0][r,g,m], lower_bound=d[:dm0_lb][r,g,m])
        md0[r in R, m in M, g in G], (start=d[:md0][r,m,g], lower_bound=d[:md0_lb][r,m,g])
        # balance of payments
        bopdef0[r in R] >= 0, (start=d[:bopdef0][r])
    end)

    [set_upper_bound(i0[r,g], upper_bound*d[:i0][r,g]) for (r,g) in set[:r,:g] if d[:i0][r,g]!==0.0]

    # --- DEFINE CONSTRAINTS ---------------------------------------------------------------

    # Zero profit conditions
    @constraints(calib, begin
        PROFIT_A[r in R, g in G], (
            (1 - d[:ta0][r,g])*a0[r,g] + rx0[r,g] ==
            (1 + d[:tm0][r,g])*m0[r,g] + nd0[r,g] + dd0[r,g] + sum(md0[r,m,g] for m in M)
        )
        PROFIT_Y[r in R, s in S], (
            (1 - d[:ty0][r,s]) * sum(ys0[r,s,g] for g in G) ==
            ld0[r,s] + kd0[r,s] + sum(id0[r,g,s] for g in G)
        )
        PROFIT_MS[r in R, m in M], (
            sum(nm0[r,s,m] + dm0[r,s,m] for s in S) ==
            sum(md0[r,m,g] for g in G)
        )
        PROFIT_X[r in R, g in G], s0[r,g] + rx0[r,g] == x0[r,g] + xn0[r,g] + xd0[r,g]
    end)
    
    # Market clearing conditions
    @constraints(calib, begin
        MARKET_PY[r in R, g in G], s0[r,g]  == sum(ys0[r,s,g] for s in S) + yh0[r,g]
        MARKET_PA[r in R, g in G], a0[r,g]  == sum(id0[r,g,s] for s in S) + cd0[r,g] + g0[r,g] + i0[r,g]
        MARKET_PD[r in R, g in G], xd0[r,g] == sum(dm0[r,g,m] for m in M) + dd0[r,g]
        MARKET_PN[g in G], (
            sum(xn0[r,g] for r in R) ==
            sum(nd0[r,g] + sum(nm0[r,g,m] for m in M) for r in R)
        )
        MARKET_PFX, (
            sum(m0[r,g] for (r,g) in set[:r,:g]) ==
            sum(bopdef0[r] + d[:hhadj][r] + sum(x0[r,g] for g in G) for r in R)
        )
    end)

    # Gross exports > re-exports
    @constraint(calib, EXPDEF[r in R, g in G], x0[r,g] >= rx0[r,g])

    # Income balance
    @constraint(calib, INCBAL[r in R],
        sum(cd0[r,g] + g0[r,g] + i0[r,g] for g in G) == (
        sum(yh0[r,g] for g in G) + bopdef0[r] + d[:hhadj][r]
        + sum(ld0[r,s]+kd0[r,s] for s in S)
        + sum(d[:ta0][r,g]*a0[r,g] + d[:tm0][r,g]*m0[r,g] for g in G)
        + sum(d[:ty0][r,s] * sum(ys0[r,s,g] for g in G) for s in S)
        )
    )

    # Value share conditions
    @constraints(calib, begin
        LVSHR[r in R, s in S], ld0[r,s] >= 0.5*d[:fvs_ld0][r,s] * sum(ys0[r,s,g] for g in G)
        KVSHR[r in R, s in S], kd0[r,s] >= 0.5*d[:fvs_kd0][r,s] * sum(ys0[r,s,g] for g in G)
    end)

    # Net generation of electricity balancing
    @constraints(calib, begin
        NETGEN_POS[r in R; d[:netgen][r]>0], 0.8*d[:netgen][r] <= nd0[r,"ele"]-xn0[r,"ele"] <= 1.2*d[:netgen][r]
        NETGEN_NEG[r in R; d[:netgen][r]<0], 1.2*d[:netgen][r] <= nd0[r,"ele"]-xn0[r,"ele"] <= 0.8*d[:netgen][r]
    end)

    # Verify regional totals equal national totals.
    @constraints(calib, begin
        NATIONAL_X0[s in NAT], sum(x0[r,s] for r in R) == d[:x0_nat][s]
        NATIONAL_M0[s in NAT], sum(m0[r,s] for r in R) == d[:m0_nat][s]
        NATIONAL_G0[s in NAT], sum(g0[r,s] for r in R) == d[:g0_nat][s]
        NATIONAL_I0[s in NAT], sum(i0[r,s] for r in R) == d[:i0_nat][s]
        NATIONAL_C0[s in NAT], sum(cd0[r,s] for r in R) == d[:cd0_nat][s]
        NATIONAL_VA0[s in NAT], sum(ld0[r,s] + kd0[r,s] for r in R) == d[:va0_nat][s]
        NATIONAL_YS0[s in NAT], (
            sum(ys0[r,s,g] for (r,g) in set[:r,:nat]) ==
            sum(d[:ys0_nat][s,g] for g in NAT)
        )
    end)

    # --- DEFINE OBJECTIVE -----------------------------------------------------------------
    @objective(calib, Min,
        # production
        + sum(abs(d[:ys0][r,s,g]) * (ys0[r,s,g]/d[:ys0][r,s,g] - 1)^2 for (r,s,g) in set[:r,:s,:g] if d[:ys0][r,s,g] != 0)
        + sum(abs(d[:id0][r,g,s]) * (id0[r,g,s]/d[:id0][r,g,s] - 1)^2 for (r,g,s) in set[:r,:g,:s] if d[:id0][r,g,s] != 0)
        + sum(abs(d[:ld0][r,s]) * (ld0[r,s]/d[:ld0][r,s] - 1)^2 for (r,s) in set[:r,:s] if d[:ld0][r,s] != 0)
        + sum(abs(d[:kd0][r,s]) * (kd0[r,s]/d[:kd0][r,s] - 1)^2 for (r,s) in set[:r,:s] if d[:kd0][r,s] != 0)
        # trade
        + sum(abs(d[:a0][r,g])  * (a0[r,g] /d[:a0][r,g]  - 1)^2 for (r,g) in set[:r,:g] if d[:a0][r,g]  != 0)
        + sum(abs(d[:nd0][r,g]) * (nd0[r,g]/d[:nd0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:nd0][r,g] != 0)
        + sum(abs(d[:dd0][r,g]) * (dd0[r,g]/d[:dd0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:dd0][r,g] != 0)
        + sum(abs(d[:m0][r,g])  * (m0[r,g] /d[:m0][r,g]  - 1)^2 for (r,g) in set[:r,:g] if d[:m0][r,g]  != 0)
        # supply
        + sum(abs(d[:s0][r,g])  * (s0[r,g] /d[:s0][r,g]  - 1)^2 for (r,g) in set[:r,:g] if d[:s0][r,g]  != 0)
        + sum(abs(d[:xd0][r,g]) * (xd0[r,g]/d[:xd0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:xd0][r,g] != 0)
        + sum(abs(d[:xn0][r,g]) * (xn0[r,g]/d[:xn0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:xn0][r,g] != 0)
        + sum(abs(d[:x0][r,g])  * (x0[r,g] /d[:x0][r,g]  - 1)^2 for (r,g) in set[:r,:g] if d[:x0][r,g]  != 0)
        + sum(abs(d[:rx0][r,g]) * (rx0[r,g]/d[:rx0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:rx0][r,g] != 0)
        # demand
        + sum(abs(d[:yh0][r,g]) * (yh0[r,g]/d[:yh0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:yh0][r,g] != 0)
        + sum(abs(d[:cd0][r,g]) * (cd0[r,g]/d[:cd0][r,g] - 1)^2 for (r,g) in set[:r,:g] if d[:cd0][r,g] != 0)
        + sum(abs(d[:i0][r,g])  * (i0[r,g] /d[:i0][r,g]  - 1)^2 for (r,g) in set[:r,:g] if d[:i0][r,g]  != 0)
        + sum(abs(d[:g0][r,g])  * (g0[r,g] /d[:g0][r,g]  - 1)^2 for (r,g) in set[:r,:g] if d[:g0][r,g]  != 0)
        + sum(abs(d[:bopdef0][r]) * (bopdef0[r]/d[:bopdef0][r] - 1)^2 for r in R if d[:bopdef0][r] != 0)
        # margin
        + sum(abs(d[:nm0][r,g,m]) * (nm0[r,g,m]/d[:nm0][r,g,m] - 1)^2 for (r,g,m) in set[:r,:g,:m] if d[:nm0][r,g,m] != 0)
        + sum(abs(d[:dm0][r,g,m]) * (dm0[r,g,m]/d[:dm0][r,g,m] - 1)^2 for (r,g,m) in set[:r,:g,:m] if d[:dm0][r,g,m] != 0)
        + sum(abs(d[:md0][r,m,g]) * (md0[r,m,g]/d[:md0][r,m,g] - 1)^2 for (r,m,g) in set[:r,:m,:g] if d[:md0][r,m,g] != 0)

    + zeropenalty * (
        # production
        + sum(ys0[r,s,g] for (r,s,g) in set[:r,:s,:g] if d[:ys0][r,s,g] == 0)
        + sum(id0[r,g,s] for (r,g,s) in set[:r,:g,:s] if d[:id0][r,g,s] == 0)
        + sum(ld0[r,s] for (r,s) in set[:r,:s] if d[:ld0][r,s] == 0)
        + sum(kd0[r,s] for (r,s) in set[:r,:s] if d[:kd0][r,s] == 0)
        # trade
        + sum(a0[r,g]  for (r,g) in set[:r,:g] if d[:a0][r,g]  == 0)
        + sum(nd0[r,g] for (r,g) in set[:r,:g] if d[:nd0][r,g] == 0)
        + sum(dd0[r,g] for (r,g) in set[:r,:g] if d[:dd0][r,g] == 0)
        + sum(m0[r,g]  for (r,g) in set[:r,:g] if d[:m0][r,g]  == 0)
        # supply
        + sum(s0[r,g]  for (r,g) in set[:r,:g] if d[:s0][r,g]  == 0)
        + sum(xd0[r,g] for (r,g) in set[:r,:g] if d[:xd0][r,g] == 0)
        + sum(xn0[r,g] for (r,g) in set[:r,:g] if d[:xn0][r,g] == 0)
        + sum(x0[r,g]  for (r,g) in set[:r,:g] if d[:x0][r,g]  == 0)
        + sum(rx0[r,g] for (r,g) in set[:r,:g] if d[:rx0][r,g] == 0)
        # demand
        + sum(yh0[r,g] for (r,g) in set[:r,:g] if d[:yh0][r,g] == 0)
        + sum(cd0[r,g] for (r,g) in set[:r,:g] if d[:cd0][r,g] == 0)
        + sum(i0[r,g]  for (r,g) in set[:r,:g] if d[:i0][r,g]  == 0)
        + sum(g0[r,g]  for (r,g) in set[:r,:g] if d[:g0][r,g]  == 0)
        # margin
        + sum(nm0[r,g,m] for (r,g,m) in set[:r,:g,:m] if d[:nm0][r,g,m] == 0)
        + sum(dm0[r,g,m] for (r,g,m) in set[:r,:g,:m] if d[:dm0][r,g,m] == 0)
        + sum(md0[r,m,g] for (r,m,g) in set[:r,:m,:g] if d[:md0][r,m,g] == 0)
        )
    )

    # ----- SET BOUNDS AND FIX ZEROS -------------------------------------------------------
    # Fix international electricity imports/exports to zero (subject to SEDS data).
    # Fix international electricity imports/exports to zero (subject to SEDS data).
    [d[:x0][r,"ele"]>0 ? set_lower_bound(x0[r,"ele"], lower_bound_seds*d[:x0][r,"ele"]) : fix(x0[r,"ele"],0,force=true) for r in R]
    [d[:m0][r,"ele"]>0 ? set_lower_bound(m0[r,"ele"], lower_bound_seds*d[:m0][r,"ele"]) : fix(m0[r,"ele"],0,force=true) for r in R]

    # Adjust upper and lower bounds to allow SEDS data to shift.
    [set_lower_bound(cd0[r,e], lower_bound_seds*d[:cd0][r,e]) for (r,e) in set[:r,:e] if d[:cd0][r,e]!==0]
    [set_lower_bound(ys0[r,e,e], lower_bound_seds*d[:ys0][r,e,e]) for (r,e) in set[:r,:e] if d[:ys0][r,e,e]!==0]
    [set_lower_bound(id0[r,e,s], lower_bound_seds*d[:id0][r,e,s]) for (r,e,s) in set[:r,:e,:s] if d[:id0][r,e,s]!==0]
    [set_lower_bound(md0[r,m,e], lower_bound_seds*d[:md0][r,m,e]) for (r,m,e) in set[:r,:m,:e] if d[:md0][r,m,e]!==0]

    [set_upper_bound(cd0[r,e], upper_bound_seds*d[:cd0][r,e]) for (r,e) in set[:r,:e] if d[:cd0][r,e]!==0]
    [set_upper_bound(ys0[r,e,e], upper_bound_seds*d[:ys0][r,e,e]) for (r,e) in set[:r,:e] if d[:ys0][r,e,e]!==0]
    [set_upper_bound(id0[r,e,s], upper_bound_seds*d[:id0][r,e,s]) for (r,e,s) in set[:r,:e,:s] if d[:id0][r,e,s]!==0]
    [set_upper_bound(md0[r,m,e], upper_bound_seds*d[:md0][r,m,e]) for (r,m,e) in set[:r,:m,:e] if d[:md0][r,m,e]!==0]

    # Restrict some parameters to zero.
    [fix(id0[r,g,e], 0, force=true) for (r,g,e) in set[:r,:g,:e] if d[:id0][r,g,e]==0]
    [fix(ys0[r,e,g], 0, force=true) for (r,e,g) in set[:r,:e,:g] if d[:ys0][r,e,g]==0]
    [fix(md0[r,m,g], 0, force=true) for (r,m,g) in set[:r,:m,:g] if d[:md0][r,m,g]==0]
    [fix(nm0[r,g,m], 0, force=true) for (r,g,m) in set[:r,:g,:m] if d[:nm0][r,g,m]==0]
    [fix(dm0[r,g,m], 0, force=true) for (r,g,m) in set[:r,:g,:m] if d[:dm0][r,g,m]==0]
    [fix(rx0[r,g], 0, force=true) for (r,g) in set[:r,:g] if d[:rx0][r,g]==0]
    [fix(yh0[r,g], 0, force=true) for (r,g) in set[:r,:g] if d[:yh0][r,g]==0]

    # Set electricity imports from the national market to Alaska and Hawaii to zero.
    [fix(nd0[r,"ele"], 0, force=true) for r in ["ak","hi"]]
    [fix(xn0[r,"ele"], 0, force=true) for r in ["ak","hi"]]

    # --- OPTIMIZE AND SAVE RESULTS --------------------------------------------------------
    if optimize
        JuMP.optimize!(calib)
        return calib
        cal = SLiDE._calibration_output(calib, set, year; region=true)
        [cal[k] = filter_with(io[k],(yr=year,)) for k in setdiff(keys(io),keys(cal))]
        # return Dict{Any,Any}(cal)
    else
        return calib
    end
    # return calib
end


"""
    _energy_calibration_input(d::Dict, set::Dict, year::Int)
    _energy_calibration_input(d::Dict, set::Dict)
This function prepares input for the EEM calibration routine. The indices of the output
parameters will include ``yr`` only if `year` is included as an input parameter.
1. Drop "small" values from input data.
2. Calculate additional values for constraints:
    - Define ``va_{yr,r,s} = ld_{yr,r,s} + kd_{yr,r,s}``
    - Aggregate regionally: ``\\tilde{ys}_{yr,s,g}``, ``\\tilde{x}_{yr,g}``,
        ``\\tilde{m}_{yr,g}``, ``\\tilde{va}_{yr,s}``, ``\\tilde{g}_{yr,g}``,
        ``\\tilde{i}_{yr,g}``, ``\\tilde{cd}_{yr,g}``.
        For any parameter ``\\bar{z}_{yr,r,s,g}``,
            ```math
            \\tilde{z}_{yr,s,g} = \\sum_{r} \\bar{z}_{yr,r,s,g}
            ```
    - Separate ``fvs_{yr,r,s}`` for labor (`fvs_ld0`) and capital (`fvs_kd0`).
    - Filter ``netgen_{yr,r}`` to include only values from SEDS input data.
3. Set electricity imports/exports from/to the national market to/from Alaska and Hawaii to zero.
4. (If `T==Dict`), fill zeros.
5. Set lower bounds for all variables except for ``\\bar{ld}_{yr,r,s}``, `\\bar{kd}_{yr,r,s}`,
    `\\bar{yh}_{yr,r,g}`, and ``\\bar{cd}_{yr,r,g}``.
6. (If `T==Dict`), convert to dictionary.
"""
function _energy_calibration_input(d, set, ::Type{T};
    lower_bound::Real=NaN,
    upper_bound::Real=NaN,
    allow_negative::Bool=true,
) where T <: Union{DataFrame,Dict}

    # Filter the DataFrame.
    parameters = SLiDE.list_parameters!(set,:parameters)
    variables = setdiff(parameters, SLiDE.list_parameters!(set,:taxes))
    variables_nat = [:ys0,:x0,:m0,:va0,:g0,:i0,:cd0]
    
    [d[k] = SLiDE.drop_small(copy(d[k])) for k in variables]
    # ** Validated against bluenote

    # Calculate additional values for constraints.
    d[:va0] = d[:ld0] + d[:kd0]
    [d[append(k,:nat)] = combine_over(d[k],:r) for k in variables_nat]
    [d[append(:fvs,k)] = filter_with(d[:fvs], (parameter=k,); drop=true) for k in ["ld0","kd0"]]
    d[:netgen] = filter_with(d[:netgen], (dataset="seds",); drop=true)

    # Set some values to zero.
    [d[k] = filter_with(d[k], Not(DataFrame(r=["ak","hi"],g="ele"))) for k in [:nd0,:xn0]]

    # If returning a dictionary, fill zeros and convert output to a dictionary.
    # Set upper and lower bounds regardless, but do so *after* filling zeros (if required)
    # to save some time.
    if T==Dict
        d = Dict(k => fill_zero(d[k]; with=set) for k in
            [parameters; append.(:fvs,[:ld0,:kd0]); append.(variables_nat,:nat); :netgen])
            # !!!! if d is already filtered, this shouldn't be necessary.
    end

    SLiDE.set_lower_bound!(d, setdiff(variables, [:ld0,:kd0,:yh0,:cd0]); factor=lower_bound)
    SLiDE.set_upper_bound!(d, :i0; factor=upper_bound)

    if T==Dict
        d = Dict{Symbol,Dict}(k => convert_type(Dict, df) for (k,df) in d)
    end

    return d
end


function _energy_calibration_input(d, set, year, ::Type{T};
    lower_bound::Real=NaN,
    upper_bound::Real=NaN,
    allow_negative::Bool=true,
) where T <: Union{DataFrame,Dict}
    d = Dict(k => filter_with(df, (yr=year,); drop=true) for (k,df) in d)
    d = _energy_calibration_input(d, set, T;
        lower_bound=lower_bound,
        upper_bound=upper_bound,
        allow_negative=allow_negative,
    )
    return d
end

# ----- JuMP SYNTAX (without SLiDE functions) ----------------------------------------------
# @variables(calib, begin
#     # production
#     ys0[r in R, s in S, g in G], (start=d[:ys0][r,s,g], lower_bound=lower_bound*d[:ys0][r,s,g])
#     id0[r in R, s in G, g in S], (start=d[:id0][r,g,s], lower_bound=lower_bound*d[:id0][r,g,s])
#     ld0[r in R, s in S], (start=d[:ld0][r,s], lower_bound=0)
#     kd0[r in R, s in S], (start=d[:kd0][r,s], lower_bound=0)
#     # trade
#     a0[r in R, g in G],  (start=d[:a0 ][r,g], lower_bound=lower_bound*d[:a0 ][r,g])
#     nd0[r in R, g in G], (start=d[:nd0][r,g], lower_bound=lower_bound*d[:nd0][r,g])
#     dd0[r in R, g in G], (start=d[:dd0][r,g], lower_bound=lower_bound*d[:dd0][r,g])
#     m0[r in R, g in G],  (start=d[:m0 ][r,g], lower_bound=lower_bound*d[:m0 ][r,g])
#     # supply
#     s0[r in R, g in G],  (start=d[:s0 ][r,g], lower_bound=lower_bound*d[:s0 ][r,g])
#     xd0[r in R, g in G], (start=d[:xd0][r,g], lower_bound=lower_bound*d[:xd0][r,g])
#     xn0[r in R, g in G], (start=d[:xn0][r,g], lower_bound=lower_bound*d[:xn0][r,g])
#     x0[r in R, g in G],  (start=d[:x0 ][r,g], lower_bound=lower_bound*d[:x0 ][r,g])
#     rx0[r in R, g in G], (start=d[:rx0][r,g], lower_bound=lower_bound*d[:rx0][r,g])
#     # demand
#     yh0[r in R, g in G], (start=d[:yh0][r,g], lower_bound=0)
#     cd0[r in R, g in G], (start=d[:cd0][r,g], lower_bound=0)
#     i0[r in R, g in G],  (start=d[:i0 ][r,g], lower_bound=lower_bound*d[:i0 ][r,g], upper_bound=upper_bound*d[:i0][r,g])
#     g0[r in R, g in G] , (start=d[:g0 ][r,g], lower_bound=lower_bound*d[:g0 ][r,g])
#     # margin
#     nm0[r in R, g in G, m in M], (start=d[:nm0][r,g,m], lower_bound=lower_bound*d[:nm0][r,g,m])
#     dm0[r in R, g in G, m in M], (start=d[:dm0][r,g,m], lower_bound=lower_bound*d[:dm0][r,g,m])
#     md0[r in R, m in M, g in G], (start=d[:md0][r,m,g], lower_bound=lower_bound*d[:md0][r,m,g])
#     # balance of payments
#     bopdef0[r in R] >= 0, (start=d[:bopdef0][r])
# end)

# ----- SET BOUNDS AND FIX ZEROS -----------------------------------------------------------
# Fix international electricity imports/exports to zero (subject to SEDS data).
# [d[:x0][r,"ele"]>0 ? set_lower_bound(x0[r,"ele"], lower_bound_seds*d[:x0][r,"ele"]) : fix(x0[r,"ele"],0,force=true) for r in R]
# [d[:m0][r,"ele"]>0 ? set_lower_bound(m0[r,"ele"], lower_bound_seds*d[:m0][r,"ele"]) : fix(m0[r,"ele"],0,force=true) for r in R]

# Adjust upper and lower bounds to allow SEDS data to shift.
# [set_lower_bound(cd0[r,e], lower_bound_seds*d[:cd0][r,e]) for (r,e) in set[:r,:e]]
# [set_upper_bound(cd0[r,e], upper_bound_seds*d[:cd0][r,e]) for (r,e) in set[:r,:e]]
# [set_lower_bound(ys0[r,e,e], lower_bound_seds*d[:ys0][r,e,e]) for (r,e) in set[:r,:e]]
# [set_upper_bound(ys0[r,e,e], upper_bound_seds*d[:ys0][r,e,e]) for (r,e) in set[:r,:e]]
# [set_lower_bound(id0[r,e,s], lower_bound_seds*d[:id0][r,e,s]) for (r,e,s) in set[:r,:e,:s]]
# [set_upper_bound(id0[r,e,s], upper_bound_seds*d[:id0][r,e,s]) for (r,e,s) in set[:r,:e,:s]]
# [set_lower_bound(md0[r,m,e], lower_bound_seds*d[:md0][r,m,e]) for (r,m,e) in set[:r,:m,:e]]
# [set_upper_bound(md0[r,m,e], upper_bound_seds*d[:md0][r,m,e]) for (r,m,e) in set[:r,:m,:e]]

# Restrict some parameters to zero.
# [fix(id0[r,g,e], 0, force=true) for (r,g,e) in set[:r,:g,:e] if d[:id0][r,g,e]==0]
# [fix(ys0[r,e,g], 0, force=true) for (r,e,g) in set[:r,:e,:g] if d[:ys0][r,e,g]==0]
# [fix(md0[r,m,g], 0, force=true) for (r,m,g) in set[:r,:m,:g] if d[:md0][r,m,g]==0]
# [fix(nm0[r,g,m], 0, force=true) for (r,g,m) in set[:r,:g,:m] if d[:nm0][r,g,m]==0]
# [fix(dm0[r,g,m], 0, force=true) for (r,g,m) in set[:r,:g,:m] if d[:dm0][r,g,m]==0]
# [fix(rx0[r,g], 0, force=true) for (r,g) in set[:r,:g] if d[:rx0][r,g]==0]
# [fix(yh0[r,g], 0, force=true) for (r,g) in set[:r,:g] if d[:yh0][r,g]==0]

# Set electricity imports from the national market to Alaska and Hawaii to zero.
# [fix(nd0[r,"ele"], 0, force=true) for r in ["ak","hi"]]
# [fix(xn0[r,"ele"], 0, force=true) for r in ["ak","hi"]]