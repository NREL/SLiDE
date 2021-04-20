"""
Electricity generation by source.

```math
\\bar{ele}_{yr,r,src,sec} = \\left\\{seds\\left( yr,r,src,sec \\right)
\\;\\vert\\; yr, \\, r, \\, (ff,re) \\in src, \\, sec = ele \\right\\}
```

For fossil fuels, use heatrate to convert as follows:

```math
\\bar{ele}_{yr,r,ff\\in src,sec} \\text{ [billion kWh]}
= 10^3 \\cdot
\\dfrac{\\bar{ele}_{yr,r,ff\\in src,sec} \\text{ [trillion btu]}}
      {\\bar{heatrate}_{yr,src} \\text{ [btu/kWh]}}
```
"""
function partition_elegen!(d::Dict, maps::Dict)
    println("  Generating electricity data set: elegen(yr,r,src)")

    df = filter_with(d[:seds], maps[:elegen]; drop=:sec)

    df = operate_over(df, d[:heatrate];
        id=[:elegen,:heatrate] => :elegen,
        units=maps[:operate]
    )
    ii = df[:,:complete]
    df[ii,:value] .= df[ii,:factor] .* df[ii,:elegen] ./ df[ii,:heatrate]
    
    d[:elegen] = operation_output(df)
    return d[:elegen]
end