"""
Carbon dioxide emissions in million metric tons of carbon dioxide.
Use SEDS data to calculate emissions by sectoral use where possible:

```math
\\bar{btu}_{yr,r,src,sec} = \\left\\{\\bar{energy}\\left( yr,r,src,sec \\right)
\\;\\vert\\; yr, \\, r, \\, e \\in src, \\, sec \\right\\}
```

```math
\\bar{co_2}_{yr,r,src,sec} \\text{ [million metric tons of CO2]}
= 10^{-3} \\cdot
\\dfrac{\\bar{btu}_{yr,r,src,sec} \\text{ [trillion btu]}}
      {{co_2/btu}_{src} \\text{ [kg CO2/million btu]}}
```

Use EPA emissions data for total emissions by source.
"""
function eem_co2emis!(d::Dict, set::Dict, maps::Dict)
    println("  Generating emissions data set")

    _set_co2dim!(d, set)    # !!!! is this where this is relevant?

    id = [:btu,:co2perbtu] => :value
    
    col = propertynames(d[:energy])
    df = filter_with(d[:energy], (src=set[:e], sec=set[:sec], units=BTU))
    df = operate_over(df, maps[:co2perbtu]; id=id, units=maps[:operate])

    df[!,:value] .= df[!,:factor] .* df[!,:co2perbtu] .* df[!,:btu]

    d[:co2emis] = vcat(
        edit_with(df, Add(:dataset,"seds")),
        edit_with(d[:emissions], Add.([:sec,:dataset], ["total","epa"]));
    cols=:intersect)

    return d[:co2emis]
end


"""
"""
function _set_co2dim!(d, set)
    set[:co2dim] = unique(d[:emissions][:,:src])
    return set[:co2dim]
end