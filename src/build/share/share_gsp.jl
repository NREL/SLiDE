"""
```math
\\begin{aligned}
\\alpha^{gdp}_{yr,r,s} &= \\dfrac{gdp(yr,r,s)}{\\sum_{r} gdp{yr,r,s}}
\\\\
\\hat{\\alpha}^{gdp}_{yr,r} &= \\dfrac
    {\\sum_{s} \\alpha^{gdp}_{yr,r,s}}
    {\\sum_{r',s} \\alpha^{gdp}_{yr,r',s}}
\\\\
\\alpha_{yr,r,s} &=
\\begin{cases}
\\alpha^{gdp}_{yr,r,s}                                       & [oth,use]\\notin s
\\\\
\\hat{\\alpha}^{gdp}_{yr,r} \\cdot \\vec{1}_{[oth,use]\\in s}    & [oth,use]\\in s
\\end{cases}
\\end{aligned}
```
"""
function share_gdp!(d::Dict, set::Dict)
    k = :gdp
    if !haskey(d, k)
        df = copy(_share_gsp!(d))
        df = select(rename(df, :gdp=>:value), [findindex(df);:value])
        
        begin idxshr = :r; idximp = :s end
        
        df = df / transform_over(df, idxshr)
        
        dfavg = combine_over(df, idximp)
        dfavg = dfavg / transform_over(dfavg, idxshr)
        dfavg = crossjoin(dfavg, DataFrame(s=set[:oth,:use]))
        
        d[k] = dropzero(vcat(df, dfavg))
    end

    return d[k]
end


"""
```math
\\begin{aligned}
\\theta^{gsp}_{yr,r,s} &= \\dfrac{cmp(yr,r,s)}{comp(yr,r,s)}
\\\\\\\\
\\theta^{labor}_{yr,r,s} &= 
\\begin{cases}
\\theta^{gsp}_{yr,r,s}   & \\exists\\; \\theta^{gsp}_{yr,r,s}
\\\\
\\theta^{va}_{yr,s}      & \\nexists\\, \\theta^{gsp}_{yr,r,s},\\; \\exists\\; \\alpha^{gdp}_{yr,r,s}
\\end{cases}
\\end{aligned}
```

with
- ``comp_{yr,r,s}`` calculated using [`SLiDE._share_gsp!`](@ref)
- ``\\theta^{gsp}_{yr,r,s}`` calculated using [`SLiDE._share_labor_va0!`](@ref)
- ``\\alpha^{gdp}_{yr,r,s}`` calculated using [`SLiDE.share_region!`](@ref)

Labor shares that are still undefined are calculated:

```math
\\begin{aligned}
\\bar{\\theta}^{labor}_{\\bullet, r,s} &= \\dfrac{1}{N_{\\bullet, r, s}} \\sum_{yr}
    \\left\\{ \\theta^{labor}_{yr,r,s} \\;\\vert\\; (yr,r,s) \\;\\exists\\; \\theta^{labor}_{yr,r,s} \\leq 1 \\right\\}
\\\\
\\bar{\\theta}^{labor}_{yr, \\bullet, s} &= \\dfrac{1}{N_{yr, \\bullet, s}} \\sum_{r}
    \\left\\{ \\theta^{labor}_{yr,r,s} \\;\\vert\\; (yr,r,s) \\;\\exists\\; \\theta^{labor}_{yr,r,s} < 1 \\right\\}
\\end{aligned}
```

```math
\\theta^{labor}_{yr,r,s} =
\\begin{cases}
\\theta^{labor}_{yr,r,s}             & \\exists\\; \\theta^{\\star\\,labor}_{yr,r,s} \\leq 1
\\\\&\\\\
\\bar{\\theta}^{labor}_{\\bullet,r,s}  & \\exists\\; \\theta^{\\star\\,labor}_{yr,r,s} > 1
\\\\&\\\\
\\bar{\\theta}^{labor}_{yr,\\bullet,s} & \\exists\\; \\theta^{\\star\\,labor}_{\\bullet,r,s} > 1
\\end{cases}
```

with
- ``\\theta^{labor\\star}`` calculated  by [`SLiDE.condition_wg`](@ref)
- ``\\theta^{labor\\star}_{\\bullet,r,s}`` calculated  by [`SLiDE.condition_hw`](@ref)
"""
function share_labor!(d::Dict, set::Dict)
    if !haskey(d,:labor)
        df = copy(_share_gsp!(d))
        df[!,:value] .= df[:,:cmp] ./ df[:,:comp]
        dropzero!(dropnan!(select!(df, [findindex(df);:value])))

        dfavg = _share_labor_va0!(d)

        condition, df, kind = split_condition(df, d[:gdp])
        dfavg = indexjoin(condition, dfavg; kind=:inner)

        df = vcat(df, dfavg)

        # Address high-wage cases.
        idx_wg = condition_wg(df, >)
        idx_hw = condition_hw(df)
        df0 = fill_zero(df; with=set)
        
        # Imput year.
        high_wg = condition_wg(df0, >)
        df_not_high = filter_with(df0, Not(high_wg))
        df_yr = dropzero(combine_over(df_not_high, :yr; fun=Statistics.mean))
        
        # Impute region.
        low_wg = condition_wg(df0, <)
        df_low = filter_with(df0, low_wg)
        df_r = dropzero(combine_over(df_low, :r; fun=Statistics.mean))
        
        # Filter.
        df = filter_with(df, Not(idx_wg))
        df_yr = filter_with(df_yr, idx_wg)
        df_r = filter_with(df_r, idx_hw)

        d[:labor] = vcat(df, df_yr, df_r)
    end

    return d[:labor]
end


"""
`labor_va(yr,s)`, labor share of value added

```math
\\bar{\\theta}^{labor}_{yr,s} =
\\begin{cases}
\\dfrac{compen(yr,s)}{compen(yr,s) + surplus(yr,s)}
    & surplus(yr,s) \\geq 0
\\\\
1
    & surplus(yr,s) < 0
\\end{cases}
```
"""
function _share_labor_va0!(d::Dict)
    k = :labor_va0

    if !haskey(d,k)
        df = _unstack(d[:va0], :va, :value; fillmissing=0.0)

        df[!,:value] .= df[:,:compen] ./ (df[:,:compen] .+ df[:,:surplus])
        df[df[:,:surplus] .< 0,:value] .= 1.0

        d[k] = dropzero!(dropnan!(select!(df, [findindex(df);:value])))
    end

    return d[k]
end


"""
`gsp(yr,r,s)`, calculated gross state product

Calculate factor totals:
```math
\\begin{aligned}
sudo_{yr,r,s} &= gdp_{yr,r,s} - taxsbd_{yr,r,s}
\\\\
comp_{yr,r,s} &= cmp_{yr,r,s} - gos_{yr,r,s}
\\end{aligned}
```
"""
function _share_gsp!(d::Dict)
    if :gdpcat in propertynames(d[:gsp])
        df = _unstack(d[:gsp], :gdpcat, :value; fillmissing=0.0)

        df[!,:sudo] .= df[:,:gdp] - df[:,:taxsbd]
        df[!,:comp] .= df[:,:cmp] + df[:,:gos]

        df[!,:calc] .= df[:,:cmp] + df[:,:gos] + df[:,:taxsbd]
        df[!,:diff] .= df[:,:calc] - df[:,:gdp]

        d[:gsp] = df
    end

    return d[:gsp]
end


"""
`wg(yr,r,s)`, (year,region,sector) indices with high wage shares (>1)

```math
\\theta^{labor\\star}_{yr,r,s} = \\left\\{(yr,r,s) \\;\\vert\\; (yr,r,s) \\;\\exists\\; \\theta^{labor}_{yr,r,s} > 1 \\right\\}
```
"""
function condition_wg(df::DataFrame, fun::Function)
    return df[broadcast(fun, df[:,:value],1.0), findindex(df)]
end


"""
`hw(r,s)`, (region,sector) pairings with ALL wage shares > 1

```math
\\theta^{\\labor\\star}_{\\bullet,r,s} = \\left\\{(r,s) \\;\\big\\vert\\; (r,s) \\;\\exists\\; \\sum_{yr} \\theta^{labor}_{yr,r,s} > 1 \\right\\}
```
"""
function condition_hw(df::DataFrame)
    df = copy(df)
    df[!,:value] .= df[:,:value] .> 1
    df = combine_over(df,:yr; fun=prod)

    return df[df[:,:value], findindex(df)]
end