"""
Carbon dioxide emissions in million metric tons of CO$_2$.
Use SEDS data to calculate emissions by sectoral use where possible:

```math
\\tilde{btu}_{yr,r,src,sec} = \\left\\{\\tilde{energy}\\left( yr,r,src,sec \\right)
\\;\\vert\\; yr, \\, r, \\, e \\in src, \\, sec \\right\\}
```

```math
\\tilde{co_2}_{yr,r,src,sec} \\text{ [million metric tons of CO$_2$]}
= 10^{-3} \\cdot
\\dfrac{\\tilde{btu}_{yr,r,src,sec} \\text{ [trillion btu]}}
      {{co_2/btu}_{src} \\text{ [kg CO$_2$/million btu]}}
```

Use EPA emissions data for total emissions by source.
"""
function module_co2emis!(d::Dict, set::Dict, maps::Dict)
    set[:co2dim] = unique(d[:emissions][:,:src])

    id=[:btu,:co2perbtu]

    df = filter_with(d[:energy], (src=set[:e], sec=set[:sec], units=BTU))
    df = convertjoin(df, maps[:co2perbtu]; id=id)
    df = operate_with(df, maps[:operate]; id=id)
    idx = setdiff([findindex(df);:dataset],[:pq])

    d[:co2emis] = vcat(
        edit_with(df, Add(:dataset,"seds"))[:,[idx;:value]],
        edit_with(d[:emissions], [
            Drop(:yr, 2013, ">"),   # !!!! dropping for now for consistency with bluenote.
            Add(:sec,"total"),
            Add(:dataset,"epa"),
        ])[:,[idx;:value]],
    )

    return d[:co2emis]
end