"""
```math
\\bar{energy}_{yr,r,src,sec} = \\left\\{seds\\left( yr,r,src,sec \\right)
\\;\\vert\\; yr, \\, r, \\, e \\in src, \\, ed \\in sec \\right\\}
```

[`SLiDE._partition_energy_supply`](@ref) adds supply information from the electricity
generation dataset output by [`SLiDE.eem_elegen!`](@ref). The following functions are
used to calculate values or make adjustments to values in the energy dataset.
These operations must occur in the following order:
1. [`SLiDE._partition_energy_ref`](@ref)
2. [`SLiDE._partition_energy_ind`](@ref)
3. [`SLiDE._partition_energy_price`](@ref)
"""
function partition_energy!(d::Dict, set::Dict, maps::Dict)
    println("  Generating energy data set: energy(yr,r,src,sec)")
    
    df = copy(d[:seds])
    df = filter_with(df, (src=set[:e], sec=set[:ed],))

    df_elegen = _partition_energy_supply(d)
    
    df = _partition_energy_ref(df, maps)
    df = _partition_energy_ind(df, set, maps)
    df = _partition_energy_price(df, set, maps)

    df = vcat(df, df_elegen; cols=:intersect)
    df = indexjoin(df, filter_with(maps[:pq], (pq=["p","q"],)); kind=:inner)
    
    d[:energy] = dropzero(df)
    return d[:energy]
end


"""
```math
\\bar{supply}_{yr,r,src=ele} = \\sum_{src} \\bar{ele}_{yr,r,src}
```
"""
function _partition_energy_supply(d::Dict)
    idx = DataFrame(src="ele", sec="supply")
    df = combine_over(d[:elegen], :src)
    df = indexjoin(idx, df)
    return select(df, propertynames(d[:seds]))
end


"""
```math
\\bar{ref}_{yr,r,src=ele} \\text{ [billion kWh]}
=
\\bar{ref}_{yr,r,src=ele} \\text{ [trillion btu]}
\\cdot
\\dfrac{\\bar{ind}_{yr,r,src=ele} \\text{ [billion kWh]}}
      {\\bar{ind}_{yr,r,src=ele} \\text{ [trillion btu]}}
```
"""
function _partition_energy_ref(df::DataFrame, maps::Dict)
    var = [:sec,:base]
    val = [:units,:value]

    splitter = DataFrame(permute((
        src = "ele",
        sec = ["ind","ref"],
        base = ["btu","kwh"],
    )))
    splitter = indexjoin(splitter, maps[:units]; kind=:left)

    df, df_out = split_fill_unstack(df, splitter, var, val)

    df[!,:ref_kwh] .= df[:,:ref_btu] .* (df[:,:ind_kwh] ./ df[:,:ind_btu])

    return stack_append(df, df_out, var, val; ensure_finite=false)
end


"""
```math
\\bar{ind}_{yr,r,src=(ff,ele)}
= \\bar{ind}_{yr,r,src=(ff,ele)}
- \\bar{ref}_{yr,r,src=(ff,ele)}
```
"""
function _partition_energy_ind(df::DataFrame, set::Dict, maps::Dict)
    var = :sec
    val = :value
    
    splitter = DataFrame(permute((
        src = [set[:ff];"ele"],
        sec = ["ind","ref"],
        pq = "q",
    )))
    splitter = indexjoin(splitter, maps[:pq]; kind=:inner)

    df, df_out = split_fill_unstack(df, splitter, var, val)

    df[!,:ind] .= df[:,:ind] .- df[:,:ref]

    return stack_append(df, df_out, var, val)
end


"""
```math
\\begin{aligned}
\\bar{ff}_{yr,r,sec=ele} \\text{ [USD/million btu]}
&= 10^3 \\cdot
\\dfrac{\\bar{ff}_{yr,r,sec=ele} \\text{ [billion USD]}}
      {\\bar{ff}_{yr,r,sec=ele} \\text{ [trillion btu]}}
\\\\
\\bar{ele}_{yr,r,sec} \\text{ [USD/thousand kWh]}
&= 10^3 \\cdot
\\dfrac{\\bar{ele}_{yr,r,sec} \\text{ [billion USD]}}
      {\\bar{ele}_{yr,r,sec} \\text{ [billion kWh]}}
\\end{aligned}
```
"""
function _partition_energy_price(df::DataFrame, set::Dict, maps::Dict)
    var, val = :pq, [:units,:value]
    
    splitter = vcat(
        DataFrame(permute((src=set[:ff], sec="ele",     pq=["p","q","v"]))),
        DataFrame(permute((src="ele",    sec=set[:sec], pq=["p","q","v"]))),
    )
    splitter = indexjoin(splitter, maps[:pq]; kind=:left)

    df, df_out = split_fill_unstack(df, splitter, var, val)
    col = propertynames(df)

    df = operate_over(df;
        id=[:v,:q]=>:p,
        units=maps[:operate],
    )

    # Save the reported price. If no price was reported, use the calculated value instead.
    df[!,:reported] .= df[:,:p]
    df[!,:calculated] .= df[:,:factor] .* df[:,:v] ./ df[:,:q]

    ii = isfinite.(df[:,:calculated])
    df[ii,:p] .= df[ii,:calculated]

    return stack_append(df[:,col], df_out, var, val; ensure_finite=false)
end