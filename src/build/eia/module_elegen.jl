"""
Electricity generation by source.

```math
\\tilde{ele}_{yr,r,src,sec} = \\left\\{\\tilde{seds}\\left( yr,r,src,sec \\right)
\\;\\vert\\; yr, \\, r, \\, (ff,re) \\in src, \\, sec = ele \\right\\}
```

For fossil fuels, use heatrate to convert as follows:

```math
\\tilde{ele}_{yr,r,ff\\in src,sec} \\text{ [billion kWh]}
= 10^3 \\cdot
\\dfrac{\\tilde{ele}_{yr,r,ff\\in src,sec} \\text{ [trillion btu]}}
      {\\bar{heatrate}_{yr,src} \\text{ [btu/kWh]}}
```
"""
function module_elegen!(d::Dict, maps::Dict)
    id = [:elegen,:heatrate]

    df = indexjoin(d[:seds], maps[:elegen]; kind=:inner)
    df = convertjoin(df, d[:heatrate]; id=id)
    df = operate_with(df, maps[:operate]; id=id)
    d[:elegen] = edit_with(df, Deselect([:sec],"=="))
    return d[:elegen]
end