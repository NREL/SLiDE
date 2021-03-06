"""
    function disagg!(d::Dict, set::Dict; save_build = true, overwrite = false)

# Arguments
- `d::Dict` of DataFrames containing the model data.
- `set::Dict` of Arrays describing region, sector, final demand, etc.

# Keywords
- `save_build = true`
- `overwrite = false`
See [`SLiDE.build`](@ref) for keyword argument descriptions.

# Returns
- `d::Dict` of DataFrames containing the model data at the disaggregation step
"""
function disagg(
    dataset::String,
    d::Dict,
    set::Dict;
    save_build::Bool = DEFAULT_SAVE_BUILD,
    overwrite::Bool = DEFAULT_OVERWRITE
    )
    CURR_STEP = "disagg"

    d = merge(d, Dict(
        :r => fill_with((r = set[:r],), 1.0),
        (:yr,:r,:g) => fill_with((yr = set[:yr], r = set[:r], g = set[:g]), 1.0)))

    # If there is already disaggregation data, read it and return.
    d_read = read_build(dataset, CURR_STEP; overwrite = overwrite)
    !(isempty(d_read)) && (return (d_read, set))
    
    # Run all disaggregation calculations.
    _set_gm!(d, set)
    
    d[:region] = edit_with(d[:region], Rename(:g,:s))
    _disagg_ys0!(d)
    _disagg_id0!(d)
    _disagg_ty0!(d, set)
    _disagg_va0!(d, set)
    _disagg_ld0!(d)
    _disagg_kd0!(d)

    d[:region] = edit_with(d[:region], Rename(:s,:g))
    _disagg_fdcat!(d)
    _disagg_g0!(d)
    _disagg_i0!(d)
    _disagg_cd0!(d)
    _disagg_c0!(d)

    d[:yh0_temp] = _disagg_yh0!(d)
    _disagg_fe0!(d)
    d[:x0_temp] = _disagg_x0!(d, set)
    d[:s0_temp] = _disagg_s0!(d)
    _disagg_a0!(d)

    _disagg_ta0!(d)
    _disagg_tm0!(d)

    _disagg_thetaa!(d)
    _disagg_m0!(d)
    _disagg_md0!(d)
    d[:rx0_temp] = _disagg_rx0!(d)

    _disagg_diff!(d)
    _apply_diff!(d, set)

    _disagg_bop!(d)
    _disagg_pt0!(d)
    _disagg_dc0!(d)

    _disagg_dd0!(d)
    _disagg_nd0!(d)

    _disagg_dm0!(d)
    _disagg_nm0!(d)
    _disagg_xd0!(d)
    _disagg_xn0!(d)
    _disagg_hhadj!(d)

    # Should other
    d[:xn0][d[:xn0][:,:value] .< 1e-8,:value] .= 0;
    d[:xd0][d[:xd0][:,:value] .< 1e-8,:value] .= 0;

    write_build!(dataset, CURR_STEP, d; save_build = save_build)
    write_build!(dataset, SET_DIR, Dict(k => set[k] for k in [:gm]))
    return (d, set)
end


"""
`ys(yr,r,s,g)`, regional sectoral output

```math
\\bar{ys}_{yr,r,s,g} = \\alpha_{yr,r,s}^{gsp} \\tilde{ys}_{yr,s,g}
```
"""
function _disagg_ys0!(d::Dict)
    println("  Disaggregating ys0(yr,r,s,g), regional sectoral output")
    :r in propertynames(d[:ys0]) && (return d[:ys0])

    d[:ys0] = d[:region] * d[:ys0]
    return d[:ys0]
end

"""
`id(yr,r,g,s)`, regional intermediate demand

```math
\\bar{id}_{yr,r,g,s} = \\alpha_{yr,r,s}^{gsp} \\tilde{id}_{yr,g,s}
```
"""
function _disagg_id0!(d::Dict)
    println("  Disaggregating id0(yr,r,g,s), regional intermediate demand")
    :r in propertynames(d[:id0]) && (return d[:id0])

    d[:id0] = d[:region] * d[:id0]
    return d[:id0]
end


"""
`ty(yr,r,s)`, production tax rate

```math
\\begin{aligned}
\\bar{ty}_{yr,r,s}^{rev} &= \\alpha_{yr,r,s}^{gsp} \\tilde{va}_{yr,va,s} \\;\\forall\\; va = othtax \\\\
\\bar{ty}_{yr,r,s} &= \\frac{\\tilde{ty}_{yr,r,s}}{\\sum_{g} \\bar{ys}_{yr,r,s,g}}
\\end{aligned}
```
"""
function _disagg_ty0!(d::Dict, set::Dict)
    println("  Disaggregating ty0(yr,r,s), production tax rate")
    :va in propertynames(d[:va0]) && _unstack_va0!(d, set)
    idx = findindex(d[:va0])

    ty0_rev = d[:region] * d[:va0][:,[idx;:othtax]]
    d[:ty0] = dropnan(ty0_rev / combine_over(d[:ys0], :g))
    return d[:ty0]
end


"""
`va(yr,va,s)`, regional value added

```math
\\bar{va}_{yr,r,s} = \\alpha_{yr,r,s}^{gsp} \\sum_{va = compen,surplus} \\tilde{va}_{yr,va,s}
```
"""
function _disagg_va0!(d::Dict, set::Dict)
    println("  Disaggregating va0(yr,r,s), regional share of value added.")
    :r in propertynames(d[:va0])  && (return d[:va0])
    :va in propertynames(d[:va0]) && (_unstack_va0!(d, set))
    idx = findindex(d[:va0])

    df = d[:va0][:,[idx;:compen]] + d[:va0][:,[idx;:surplus]]
    d[:va0] = d[:region] * df
    return d[:va0]
end


"""
`ld0(yr,r,s)`, labor demand

```math
\\bar{ld}_{yr,r,s} = \\theta_{yr,r,s}^{ls} \\bar{va}_{yr,s,g}
```
"""
function _disagg_ld0!(d::Dict)
    println("  Disaggregating ld0(yr,r,s), labor demand")
    !(:r in propertynames(d[:va0])) && _disagg_va0!(d, set)
    d[:ld0] = d[:labor] * d[:va0]
    return d[:ld0]
end


"""
`kd0(yr,r,s)`, capital demand

```math
\\bar{kd}_{yr,r,s} = \\bar{va}_{yr,r,s} - \\bar{ld}_{yr,r,s}
```
"""
function _disagg_kd0!(d::Dict)
    println("  Disaggregating kd0(yr,r,s), capital demand")
    d[:kd0] = d[:va0] - d[:ld0]
end


"""
    _disagg_fdcat!(d::Dict)
This function aggregates final demand categories into national consumption (`C`), government
(`G`), and investment (`I`) demand.
"""
function _disagg_fdcat!(d::Dict)
    if "pce" in d[:fd0][:,:fd]
        x = [
            Map(joinpath("crosswalk","fd.csv"), [:fd], [:fdcat], [:fd], [:fd], :inner),
            Combine("sum",propertynames(d[:fd0])),
        ]
        d[:fd0] = edit_with(d[:fd0], x)
        # d[:fd0] = combine_over(d[:fd0], :fd)
    end
    return d[:fd0]
end


"""
`g0(yr,r,g)`, national government demand

```math
\\bar{g}_{yr,r,g} = \\alpha_{yr,r,g}^{sgf} \\sum_{G \\in fd} \\tilde{fd}_{yr,g,fd}
```
"""
function _disagg_g0!(d::Dict)
    println("  Disaggregating g0(yr,r,g), national government demand")
    ("pce" in d[:fd0][:,:fd]) && (_disagg_fdcat!(d))

    df = filter_with(d[:fd0], (fd="G",); drop = true)
    d[:g0] = d[:sgf] * df
    return d[:g0]
end


"""
`i0(yr,r,g)`, national investment demand

```math
\\bar{i}_{yr,r,g} = \\alpha_{yr,r,g}^{gsp} \\sum_{I \\in fd} \\tilde{fd}_{yr,g,fd}
```
"""
function _disagg_i0!(d::Dict)
    println("  Disaggregating i0(yr,r,g), national investment demand")
    !("pce" in d[:fd0][:,:fd]) && (_disagg_fdcat!(d))

    df = filter_with(d[:fd0], (fd="I",); drop = true)
    d[:i0] = d[:region] * df
    return d[:i0]
end


"""
`cd0(yr,r,g)`, national final consumption

```math
\\bar{cd}_{yr,r,g} = \\alpha_{yr,r,g}^{pce} \\sum_{C \\in fd} \\tilde{fd}_{yr,g,fd}
```
"""
function _disagg_cd0!(d::Dict)
    println("  Disaggregating cd0(yr,r,g), national final consumption")
    !("pce" in d[:fd0][:,:fd]) && (_disagg_fdcat!(d))

    df = filter_with(d[:fd0], (fd="C",); drop = true)
    d[:cd0] = d[:pce] * df
    return d[:cd0]
end


"""
`c0(yr,r)`, total final household consumption

```math
\\bar{c}_{yr,r} = \\sum_{g} \\bar{cd}_{yr,r,g}
```
"""
function _disagg_c0!(d::Dict)
    println("  Disaggregating c0(yr,r), total final household consumption")
    !(:cd0 in keys(d)) && _disagg_cd0!(d)
    d[:c0] = combine_over(d[:cd0], :g)
    return d[:c0]
end


"""
`yh0(yr,r,g)`, household production

```math
\\bar{yh}_{yr,r,g} = \\alpha_{yr,r,g} \\tilde{fs}_{yr,g}
```
"""
function _disagg_yh0!(d::Dict)
    if !(:diff in keys(d))
        println("  Disaggregating yh0(yr,r,g), household production")
        d[:yh0] = d[:region] * d[:fs0]
    else
        println("  Applying difference to yh0(yr,r,g), household production")
        d[:yh0] = d[:yh0] + d[:diff]
    end
    return dropmissing!(d[:yh0])
end


"""
`fe0(yr,r)`, total factor supply

```math
\\bar{fe}_{yr,r} = \\sum_{s} \\bar{va}_{yr,r,s}
```
"""
function _disagg_fe0!(d::Dict)
    println("  Disaggregating fe0(yr,r), total factor supply")
    d[:fe0] = combine_over(d[:va0], :s)
    return d[:fe0]
end


"""
`x0(yr,r,g)`, foreign exports

```math
\\bar{x}_{yr,r,g} = \\alpha_{yr,r,g}^{utd} \\tilde{x}_{yr,g}
```
"""
function _disagg_x0!(d::Dict, set::Dict)
    if !(:diff in keys(d))
        println("  Disaggregating x0(yr,r,g), foreign exports")
        !(:notrd in keys(set)) && _set_notrd!(d, set)

        df_exports = filter_with(d[:utd], (t = "exports",); drop = true)
        df_region = filter_with(d[:region], (g = set[:notrd],))

        df_trd = dropmissing(df_exports * d[:x0])
        df_notrd = dropmissing(df_region * d[:x0])

        d[:x0] = [df_trd; df_notrd]
    else
        println("  Applying difference to x0(yr,r,g), foreign exports")
        d[:x0] = d[:x0] + d[:diff]
    end

    return dropmissing!(d[:x0])
end


"""
`s0(yr,r,g)`, total supply

```math
\\bar{s}_{yr,r,g} = \\sum_{s} \\bar{ys}_{yr,r,s,g} + \\bar{yh}_{yr,r,g}
```
"""
function _disagg_s0!(d::Dict)
    if !(:diff in keys(d))
        println("  Disaggregating s0(yr,r,g), total supply")
        d[:s0] = combine_over(d[:ys0], :s) + d[:yh0]
    else
        println("  Applying difference to s0(yr,r,g), total supply")
        d[:s0] = d[:s0] + d[:diff]
    end
    return dropmissing!(d[:s0])
end


"""
`a0(yr,r,g)`, domestic absorption

```math
a_{yr,r,g} = \\bar{cd}_{yr,r,g} + \\bar{g}_{yr,r,g} + \\bar{i}_{yr,r,g} + \\sum_{s}\\bar{id}_{yr,r,g}
```
"""
function _disagg_a0!(d::Dict)
    println("  Disaggregating a0(yr,r,g), domestic absorption")

    d[:a0] = dropmissing(d[:cd0] + d[:g0] + d[:i0] + combine_over(d[:id0], :s))
    return d[:a0]
end


"`ta0(yr,r,g)`: Absorption taxes"
function _disagg_ta0!(d::Dict)
    println("  Disaggregating ta0(yr,r,g), absorption taxes")
    d[:ta0] = d[:ta0] * d[:r]
    return d[:ta0]
end


"`tm0(yr,r,g)`: Import taxes"
function _disagg_tm0!(d::Dict)
    println("  Disaggregating tm0(yr,r,g), import taxes")
    d[:tm0] = d[:tm0] * d[:r]
    return d[:tm0]
end


"""
`thetaa(yr,r,g)`, share of regional absorption

```math
\\alpha_{yr,r,g}^{abs} = \\frac{\\bar{a}_{yr,r,g}}{\\sum_{rr}\\bar{a}_{yr,r,g}}
```
"""
function _disagg_thetaa!(d::Dict)
    println("  Disaggregating thetaa(yr,r,g), share of regional absorption")
    d[:thetaa] = dropnan(d[:a0] / transform_over(d[:a0], :r))
    return d[:thetaa]
end


"""
`m0(yr,r,g)`, foreign Imports

```math
\\bar{m}_{yr,r,g} = \\alpha_{yr,r,g}^{abs} \\tilde{m}_{yr,g}
```
"""
function _disagg_m0!(d::Dict)
    println("  Disaggregating m0(yr,r,g), foreign imports")
    d[:m0] = d[:thetaa] * d[:m0]
    return d[:m0]
end


"""
`md0(yr,r,m,g)`, margin demand

```math
\\bar{md}_{yr,r,m,g} = \\alpha_{yr,r,g}^{abs} \\tilde{md}_{yr,m,g}
```
"""
function _disagg_md0!(d::Dict)
    println("  Disaggregating md0(yr,r,m,g), margin demand")
    d[:md0] = dropmissing(d[:thetaa] * d[:md0])
    return d[:md0]
end


"""
`rx0(yr,r,g)`, re-exports

```math
\\bar{rx}_{yr,r,g} = \\bar{x}_{yr,r,g} - \\bar{s}_{yr,r,g}
```
"""
function _disagg_rx0!(d::Dict; round_digits = DEFAULT_ROUND_DIGITS)
    if !(:diff in keys(d))
        println("  Disaggregating rx0(yr,r,g), re-exports")
        d[:rx0] = d[:x0] - d[:s0]

        if round_digits !== false
            d[:rx0][round.(d[:rx0][:,:value]; digits = round_digits) .< 0, :value] .= 0.0
        end
    else
        println("  Applying difference to rx0(yr,r,g), re-exports")
        d[:rx0] = d[:rx0] + d[:diff]
    end

    return dropmissing(d[:rx0])
end


"""
`dc0`, 

```math
\\bar{dc}_{yr,r,g} = \\bar{s}_{yr,r,g} - \\bar{x}_{yr,r,g} + \\bar{rx}_{yr,r,g}
```
"""
function _disagg_dc0!(d::Dict; round_digits = DEFAULT_ROUND_DIGITS)
    # (!!!!) name for this?
    d[:dc0] = dropmissing((d[:s0] - d[:x0] + d[:rx0]))

    # if round_digits !== false
    #     d[:dc0][!,:value] .= round.(d[:dc0][:,:value]; digits = round_digits)
    # end
    (round_digits !== false) && (d[:dc0] = round!(d[:dc0], :value; digits = round_digits))
    return d[:dc0]
end


"""
`pt0`, 

```math
\\begin{aligned}
\\bar{pt}_{yr,r,g} = &\\left(1 - \\bar{ta}_{yr,r,g} \\right) \\bar{a}_{yr,r,g} + \\bar{rx}_{yr,r,g}
\\\\               - &\\left(1 + \\bar{tm}_{yr,r,g} \\right) \\bar{m}_{yr,r,g} - \\sum_{m} \\bar{md}_{yr,r,m,g}
\\end{aligned}
```
"""
function _disagg_pt0(d::Dict; round_digits = DEFAULT_ROUND_DIGITS)
    df_pta0 = dropmissing(((d[:yr,:r,:g] - d[:ta0]) * d[:a0]) + d[:rx0])
    df_ptm0 = dropmissing(((d[:yr,:r,:g] + d[:tm0]) * d[:m0]) + combine_over(d[:md0], :m))

    df = df_pta0 - df_ptm0
    (round_digits !== false) && round!(df, :value; digits = round_digits)
    return df
end


function _disagg_pt0!(d::Dict; round_digits = DEFAULT_ROUND_DIGITS)
    d[:pt0] = _disagg_pt0(d, round_digits = round_digits)
    return d[:pt0]
end


"`diff`:"
function _disagg_diff!(d::Dict; round_digits = DEFAULT_ROUND_DIGITS)
    # df = _disagg_pt0!(d)
    df = _disagg_pt0(d; round_digits = DEFAULT_ROUND_DIGITS)

    df[!,:value] .= - min.(0, df[:,:value])
    d[:diff] = dropzero!(df)
end


"""
Add an adjustment to `rx_{yr,r,g}`, `s_{yr,r,g}`, `x_{yr,r,g}`, and `yh_{yr,r,g}`.
"""
function _apply_diff!(d::Dict, set::Dict)
    _disagg_rx0!(d)
    _disagg_s0!(d)
    _disagg_x0!(d, set)
    _disagg_yh0!(d)
end


"""
`bopdef0(yr,r)`, balance of payments (closure parameter)

```math
\\bar{bop}_{yr,r} = \\sum_{g} \\left( \\bar{m}_{yr,r,g} - \\bar{x}_{yr,r,g} \\right)
```
"""
function _disagg_bop!(d::Dict)
    println("  Disaggregating bopdef0(yr,r), balance of payments (closure parameter)")
    d[:bopdef0] = combine_over((d[:m0] - d[:x0]), :g)
    return d[:bopdef0]
end


"`gm`: Commodities employed in margin supply"
function _set_gm!(d::Dict, set::Dict)
    ms0_sum = combine_over(d[:ms0], [:yr,:m])
    md0_sum = combine_over(d[:md0], [:yr,:m])

    ms0_sum[!,:value] .= ms0_sum[:,:value] .!= 0.0
    md0_sum[!,:value] .= md0_sum[:,:value] .!= 0.0

    gm = ms0_sum + md0_sum
    set[:gm] = gm[gm[:,:value] .> 0, :g]
    return set[:gm]
end


"""
`dd0max(yr,r,g)`, maximum regional demand from local market

```math
\\hat{dd}_{yr,r,g} = \\min\\left\\{\\bar{pt}_{yr,r,g}, \\bar{dc}_{yr,r,g} \\right\\}
```
"""
function _disagg_dd0max!(d::Dict)
    println("  Disaggregating dd0max(yr,r,g), maximum regional demand from local market")
    cols = propertynames(d[:pt0])
    df = indexjoin(d[:pt0], d[:dc0]; id = [:pt0,:dc0])
    df[!,:value] = min.(df[:,:pt0], df[:,:dc0])
    
    d[:dd0max] = df[:,cols]
    return d[:dd0max]
end


"`nd0max(yr,r,g)`, maximum regional demand from national market"
function _disagg_nd0max!(d::Dict)
    println("  Disaggregating nd0max(yr,r,g), maximum regional demand from national market")
    cols = propertynames(d[:pt0])
    df = indexjoin(d[:pt0], d[:dc0]; id = [:pt0,:dc0])
    df[!,:value] = min.(df[:,:pt0], df[:,:dc0])

    d[:nd0max] = df[:,cols]
    return d[:nd0max]
end


"`dd0min(yr,r,g)`, minimum regional demand from local market"
_disagg_dd0min(d::Dict) = d[:pt0] - d[:dd0max]

"`nd0min(yr,r,g)`, minimum regional demand from national market"
_disagg_nd0min(d::Dict) = d[:pt0] - d[:nd0max]


"""
`dd0(yr,r,g)`, regional demand from local market

```math
\\bar{dd}_{yr,r,g} = \\rho_{r,g}^{cfs} \\hat{dd}_{yr,r,g}
```
"""
function _disagg_dd0!(d::Dict)
    println("  Disaggregating dd(yr,r,g), regional demand from local market")
    !(:dd0max in keys(d)) && _disagg_dd0max!(d)
    d[:dd0] = d[:dd0max] * d[:rpc]
    return d[:dd0]
end


"""
`nd0_(yr,r,g)`, regional demand from national market

```math
\\bar{nd}_{yr,r,g} = \\bar{pt}_{yr,r,g} - \\bar{dd}_{yr,r,g}
```
"""
function _disagg_nd0!(d::Dict; round_digits = DEFAULT_ROUND_DIGITS)
    println("  Disaggregating nd(yr,r,g), regional demand from national market")
    df_pt0 = _disagg_pt0(d; round_digits = false)

    d[:nd0] = df_pt0 - d[:dd0]
    # (round_digits !== false) && (d[:nd0][!,:value] .= round.(d[:nd0][:,:value]; digits = round_digits))
    (round_digits !== false) && (d[:nd0] = round!(d[:nd0], :value; digits = round_digits))
    return d[:nd0]
end

# ##########################################################################################

"""
`mrgshr(yr,r,m)`, share of margin demand by region

```math
\\alpha_{yr,r,m}^{md} = \\frac{\\sum_{g}\\bar{md}_{yr,r,m,g}}{\\sum_{r,g}\\bar{md}_{yr,r,m,g}}
```
"""
function _disagg_mrgshr(d::Dict)
    # (!!!!) notation alpha^{md} to match thetaa, alpha^a
    df = combine_over(d[:md0], :g)
    df = df / transform_over(df, :r)
    return df
end


"""
`ms0tot(yr,r,m,g)`, designate total supply of margins

```math
\\hat{ms}_{yr,r,m,g} = \\alpha_{yr,r,m}^{md} \\bar{ms}_{yr,g,m}
```
"""
function _disagg_ms0tot!(d::Dict)
    d[:ms0tot] = _disagg_mrgshr(d) * d[:ms0]
    return d[:ms0tot]
end


"""
`shrtrd(yr,r,g,m)`, share of margin total by margin type

```math
\\beta_{yr,r,g,m}^{mar} = \\frac{\\hat{ms}_{yr,r,g,m}}{\\sum_{m}\\hat{ms}_{yr,r,g,m}}
```
"""
function _disagg_shrtrd!(d::Dict)
    !(:ms0tot in keys(d)) && _disagg_ms0tot!(d)

    df = d[:ms0tot]
    d[:shrtrd] = dropnan(df / transform_over(df, :m))
    return d[:shrtrd]
end


"""
`dm0(yr,r,g,m)`, margin supply from the local market

```math
\\bar{dm}_{yr,r,g,m} = \\min\\left\\{ \\rho_{r,g}^{cfs}\\hat{ms}_{yr,r,g,m},
    \\beta_{yr,r,m,g}^{mar} \\left(\\bar{dc}_{yr,r,g} - \\bar{dd}_{yr,r,g}\\right) \\right\\}
```
"""
function _disagg_dm0!(d::Dict)
    println("  Disaggregating dm0(yr,r,g,m), margin supply from the local market")
    !(:ms0tot in keys(d)) && _disagg_ms0tot!(d)
    !(:shrtrd in keys(d)) && _disagg_shrtrd!(d)

    cols = propertynames(d[:ms0tot])
    dm1 = dropmissing(d[:ms0tot] * d[:rpc])
    dm2 = dropmissing((d[:shrtrd] * d[:dc0]) - d[:dd0])

    df = indexjoin(dm1, dm2; id = [:dm1,:dm2])
    df[!,:value] .= min.(df[:,:dm1], df[:,:dm2])
    d[:dm0] = df[:,cols]
    return d[:dm0]
end


"""
`nm0(yr,r,g,m)`, margin demand from the national market

```math
\\bar{nm}_{yr,r,g,m} = \\hat{ms}_{yr,r,g,m} - \\bar{dm}_{yr,r,g,m}
```
"""
function _disagg_nm0!(d::Dict)
    println("  Disaggregating nm0(yr,r,g,m), margin demand from the national market")
    d[:nm0] = d[:ms0tot] - d[:dm0]
    return d[:nm0]
end


"""
`xd0(yr,r,g)`, regional supply to local market

```math
\\bar{xd}_{yr,r,g} = \\sum_{m}\\bar{dm}_{yr,r,g,m} + \\bar{dd}_{yr,r,g}
```
"""
function _disagg_xd0!(d::Dict)
    println("  Disaggregating xd0(yr,r,g), regional supply to local market")
    d[:xd0] = combine_over(d[:dm0], :m) + d[:dd0]
    return d[:xd0]
end


"""
`xn0(yr,r,g)`, regional supply to national market

```math
\\bar{xn}_{yr,r,g} = \\bar{s}_{yr,r,g} + \\bar{rx}_{yr,r,g} - \\bar{xd}_{yr,r,g} - \\bar{x}_{yr,r,g}
```
"""
function _disagg_xn0!(d::Dict)
    println("  Disaggregating xn0(yr,r,g), regional supply to national market")
    d[:xn0] = d[:s0] + d[:rx0] - d[:xd0] - d[:x0]
    return d[:xn0]
end


"""
`hhadj(yr,r)`, household adjustment

```math
\\begin{aligned}
\\bar{adj^{hh}}_{yr,r} = &\\bar{c}_{yr,r}
\\\\ &- \\sum_{s}\\left( \\bar{ld}_{yr,r,s} + \\bar{kd}_{yr,r,s} + \\bar{yh}_{yr,r,s} \\right) - \\bar{bop}_{yr,r}
\\\\ &- \\sum_{s}\\left( \\bar{ta}_{yr,r,s}\\bar{a0}_{yr,r,s} + \\bar{tm}_{yr,r,s}\\bar{m}_{yr,r,s} + \\bar{ty}_{yr,r,s}\\sum_{g}\\bar{ys}_{yr,r,s,g} \\right)
\\\\ &+ \\sum_{s}\\left( \\bar{g}_{yr,r,s} + \\bar{i}_{yr,r,s} \\right)
\\end{aligned}
```
"""
function _disagg_hhadj!(d::Dict)
    println("  Disaggregating hhadj(yr,r), household adjustment")
    dh = Dict(k => edit_with(copy(d[k]), Rename(:g,:s))
        for k in [:c0,:ld0,:kd0,:yh0,:bopdef0,:ta0,:a0,:tm0,:ty0,:g0,:i0,:m0])
    dh[:ys0] = copy(d[:ys0])

    d[:hhadj] = dh[:c0] -
        combine_over(dh[:ld0] + dh[:kd0] + dh[:yh0], :s) - dh[:bopdef0] -
        combine_over(dh[:ta0]*dh[:a0] + dh[:tm0]*dh[:m0] + dh[:ty0]*combine_over(dh[:ys0],:g), :s) +
        combine_over(dh[:g0] + dh[:i0], :s)
    
    return d[:hhadj]
end


function _unstack_va0!(d::Dict, set::Dict)
    if :va in propertynames(d[:va0])
        d[:va0] = edit_with(unstack(d[:va0], :va, :value),
            Replace.(Symbol.(set[:va]), missing, 0.0))
    end
    return d[:va0]
end