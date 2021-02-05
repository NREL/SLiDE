"""
    share_labor!(d::Dict, set::Dict)
"""
function share_labor!(d::Dict, set::Dict)
    println("  Calculating labor(yr,r,s), labor share")

    !(:region in collect(keys(d))) && share_region!(d, set)
    _share_lshr0!(d, set)

    cols = propertynames(d[:region])

    df = copy(d[:gsp])
    df[!,:value] .= df[:,:cmp] ./ df[:,:comp]
    df = dropnan(df[:,cols])

    # Begin summary DataFrame.
    df = indexjoin([df, d[:region], d[:lshr0]]; id=[:value,:region,:lshr0])

    # Use the national average labor share (calculated when partitioning)
    # in cases where the labor share is zero (e.g. banking, finance, etc.).
    ii = .&(df[:,:value] .== 0.0, df[:,:region] .> 0.0)
    df[ii,:value] .= df[ii,:lshr0]
    df = fill_zero(df)

    # d[:labor_temp] = copy(d[:labor])
    # Save labor to input in functions to calculate annual and regional average wage shares.
    df[!,:labor_shr_pre_avg] .= df[:,:value]
    d[:labor] = df[:,cols]

    df[!,:wg] .= _share_wg!(d, set)[:,:value]
    df[!,:hw] .= _share_hw!(d, set)[:,:value]
    df[!,:avg_wg] = _share_avg_wg!(d)[:,:value]
    df[!,:sec_labor] = _share_sec_labor!(d)[:,:value]
    
    wg = .&(df[:,:wg], df[:,:avg_wg] .!== 0.0)
    df[wg,:value] .= df[wg,:avg_wg]
    df[df[:,:hw],:value] .= df[df[:,:hw],:sec_labor]
    d[:labor] = dropnan(df[:, cols])
    d[:labor_calc] = df
    return d[:labor]
end


"""
`region(yr,r,s)`: Regional share of value added

```math
\\alpha_{yr,r,s}^{gsp}
=
\\begin{cases}
\\dfrac{           \\bar{gdp}_{yr,r,s}}
       {\\sum_{s'} \\bar{gdp}_{yr,r,s'}}      & \\sum_{s'} \\bar{gdp}_{yr,r,s'} \\neq 0
\\\\
\\dfrac{\\sum_{s}    \\bar{gdp}_{yr,r ,s}}
       {\\sum_{r',s} \\bar{gdp}_{yr,r',s}}    & \\sum_{s'} \\bar{gdp}_{yr,r,s'} = 0
\\end{cases}
```
"""
function share_region!(d::Dict, set::Dict)
    println("  Calculating region(yr,r,s), regional share of value added")
    :gdpcat in propertynames(d[:gsp]) && _share_gsp!(d, set)

    cols = [findindex(d[:gsp]); :value]
    df = edit_with(copy(d[:gsp]), Rename(:gdp, :value))[:,cols]
    df = df / transform_over(df, :r)
    
    # JUST IN CASE we switch back to g here..
    s = intersect(cols, [:s,:g])[1]
    
    # Let the used and scrap sectors be an average of other sectors.
    # These are the only sectors that have NaN values.
    df = df[.!isnan.(df[:,:value]),:]
    df_s  = combine_over(df, s)
    df_s /= transform_over(df_s, :r)

    df_s = crossjoin(DataFrame(s => set[:oth,:use]), df_s)

    d[:region] = dropnan(dropmissing(sort([df; df_s])))
    verify_over(d[:region], :r) !== true && @error("Regional shares don't sum to 1.")
    return d[:region]
end


"""
`gsp`: Calculated gross state product.

Calculate factor totals:
```math
\\begin{aligned}
\\bar{sudo}_{yr,r,s} &= \\bar{gdp}_{yr,r,s} - \\bar{taxsbd}_{yr,r,s}
\\\\
\\bar{comp}_{yr,r,s} &= \\bar{cmp}_{yr,r,s} - \\bar{gos}_{yr,r,s}
\\end{aligned}
```
"""
function _share_gsp!(d::Dict, set::Dict)
    df = copy(d[:gsp])
    :gdpcat in propertynames(d[:gsp]) && (df = unstack(dropzero(d[:gsp]), :gdpcat, :value))
    
    df = edit_with(df, Replace.(Symbol.(set[:gdpcat]), missing, 0.0))

    df[!,:sudo] .= df[:,:gdp] - df[:,:taxsbd]
    df[!,:comp] .= df[:,:cmp] + df[:,:gos]

    df[!,:calc] .= df[:,:cmp] + df[:,:gos] + df[:,:taxsbd]
    df[!,:diff] .= df[:,:calc] - df[:,:gdp]

    d[:gsp] = df
end


"`lshr0`: Labor share of value added"
function _share_lshr0!(d::Dict, set::Dict)
    va0 = edit_with(unstack(copy(d[:va0]), :va, :value),
        Replace.(Symbol.(set[:va]), missing, 0.0))
    idx = findindex(va0)
    
    d[:lshr0] = va0[:,[idx;:compen]]
    d[:lshr0] /= (va0[:,[idx;:compen]] + va0[:,[idx;:surplus]])

    d[:lshr0][va0[:,:surplus] .< 0,:value] .= 1.0
    return dropmissing!(dropnan!(d[:lshr0]))
end


"`wg(yr,r,s)`: Index pairs with high wage shares (>1)"
function _share_wg!(d::Dict, set::Dict)
    d[:wg] = copy(d[:labor])
    d[:wg][!,:value] .= d[:wg][:,:value] .> 1
    set[:wg] = values.(eachrow(d[:wg][d[:wg][:,:value], find_oftype(d[:wg], Not(Bool))]))
    return d[:wg] # must return the DataFrame
end


"`hw(r,s)`: (region,sector) pairings with ALL wage shares > 1"
function _share_hw!(d::Dict, set::Dict)
    # (!!!!) When WiNDC calculates this, years with all wage shares = 0 are included.
    # So I'm ok with this difference.
    !(:wg in collect(keys(d))) && _share_wg!(d, set)

    df = copy(d[:wg])
    d[:hw] = combine_over(df, :yr; fun=prod)
    set[:hw] = values.(eachrow(d[:hw][d[:hw][:,:value], find_oftype(d[:hw], String)]))
    return transform_over(df, :yr; fun=prod) # must return the DataFrame
end


"""
"""
function _share_avg_wg!(d::Dict)
    # Here, WiNDC uses .!wg, which DOES include labor = 1.
    !(:wg in collect(keys(d))) && _share_wg!(d, set)
    not_wg = edit_with(copy(d[:wg]), Replace(:value, Bool, Not))
    
    df = copy(d[:labor]) * not_wg
    d[:avg_wg] = edit_with(combine_over(df, :yr) / combine_over(not_wg, :yr), Replace(:value, NaN, 0.0))
    return edit_with(transform_over(df, :yr) / transform_over(not_wg, :yr), Replace(:value, NaN, 0.0))
end


"""
"""
function _share_sec_labor!(d::Dict)
    # Cannot use .!wg because this will include labor = 1.
    not_wg = copy(d[:labor])
    not_wg[!,:value] .= not_wg[:,:value] .< 1
    
    df = copy(d[:labor]) * not_wg
    d[:sec_labor] = combine_over(df, :r) / combine_over(not_wg, :r)
    return transform_over(df, :r) / transform_over(not_wg, :r)
end