"""
This function prepares SEDS energy data for the EEM.

# Returns
- `d::Dict` of EIA data from the SLiDE input files,
    with the addition of the following data sets describing:
    1. Electricity - [`eem_elegen!`](@ref)
    1. Energy - [`eem_energy!`](@ref)
    3. CO2 Emissions - [`eem_co2emis!`](@ref)
"""
function partition_seds(dataset::Dataset, d::Dict, set::Dict)
    step = "partition"
    SLiDE.set!(dataset; build="eem", step=step)
    maps = SLiDE.read_map()

    d_read = SLiDE.read_input!(dataset)

    if dataset.step=="input"
        [d_read[k] = SLiDE.extrapolate_year(df, (yr=set[:yr],)) for (k,df) in d_read]
        merge!(d, d_read)

        SLiDE.partition_elegen!(d, maps)
        SLiDE.partition_energy!(d, set, maps)
        # SLiDE.partition_co2emis!(d, set, maps)

        d[:convfac] = SLiDE._partition_convfac(d)
        d[:cprice] = SLiDE._partition_cprice!(d, maps)
        d[:prodbtu] = SLiDE._partition_prodbtu!(d, set)
        d[:pedef] = SLiDE._partition_pedef!(d, set, maps)
        d[:pe0] = SLiDE._partition_pe0!(d, set, maps)
        d[:ps0] = SLiDE._partition_ps0!(d)
        d[:prodval] = SLiDE._partition_prodval!(d, set, maps)
        d[:shrgas] = SLiDE._partition_shrgas!(d)
        d[:netgen] = SLiDE._partition_netgen!(d, maps)
        d[:trdele] = SLiDE._partition_trdele!(d)
        d[:pctgen] = SLiDE._partition_pctgen!(d, set)
        d[:eq0] = SLiDE._partition_eq0!(d, set)
        d[:ed0] = SLiDE._partition_ed0!(d, set, maps)
        d[:emarg0] = SLiDE._partition_emarg0!(d, set, maps)
        d[:ned0] = SLiDE._partition_ned0!(d)

        # Drop units if they're not used later.
        [select!(d[k], Not(:units)) for k in [:ed0,:emarg0,:ned0,:trdele,:pctgen,:netgen]]
        SLiDE.write_build!(SLiDE.set!(dataset; step=step), copy(d))
    else
        merge!(d, d_read)
    end
    
    return d, set, maps
end


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
    var, val = [:sec,:base], [:units,:value]

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
    var, val = :sec, :value
    
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


"""
`convfac(yr,r)` [million btu per barrel],
conversion factor for USD per barrel ``\\longrightarrow`` USD per million btu

```math
\\tilde{convfac}_{yr,r} \\text{ [million btu/barrel]}
= \\left\\{
    seds \\left( yr, r, src, sec \\right) \\;\\vert\\; yr,\\, r,\\, src=cru,\\, sec=supply
\\right\\}
```
"""
function _partition_convfac(d::Dict)
    println("  Partitioning convfac(yr,r), conversion factor for USD per barrel")
    return filter_with(d[:seds], (src="cru", sec="supply", units=BTU_PER_BARREL); drop=:sec)
end


"""
`cprice(yr,r)` [USD per million btu], crude oil price

```math
\\tilde{cprice}_{yr,r} \\text{ [usd/million btu]}
=
\\dfrac{\\bar{crude oil}_{yr} \\text{ [usd/barrel]}}
        {\\tilde{convfac}_{yr,r} \\text{ [million btu/barrel]}}
```
"""
function _partition_cprice!(d::Dict, maps::Dict)
    println("  Partitioning cprice(yr,r), crude oil price")

    df = operate_over(d[:crude_oil], SLiDE._partition_convfac(d);
        id=[:usd_per_barrel,:btu_per_barrel]=>:usd_per_btu,
        units=maps[:operate],
    )
    df[!,:value] .= df[:,:factor] .* df[:,:usd_per_barrel] ./ df[:,:btu_per_barrel]

    d[:cprice] = operation_output(df)
    return d[:cprice]
end


"""
`prodbtu(yr,r,src)`
```math
\\tilde{prodbtu}_{yr,r} \\text{ [trillion btu]}
= \\left\\{
    seds \\left( yr, r, src, sec \\right) \\;\\vert\\; yr,\\, r,\\, as\\in src,\\, sec=supply
\\right\\}
```
"""
function _partition_prodbtu!(d::Dict, set::Dict)
    println("  Partitioning prodbtu(yr,r,src)")
    d[:prodbtu] = filter_with(d[:seds], (src=set[:as], sec="supply", units=BTU); drop=:sec)
    return d[:prodbtu]
end


"""
`pedef(yr,r,src)`, average energy demand price.
This parameter can be calculated from prices ``\\tilde{p}_{yr,r,src,sec}`` and quantities 
``\\tilde{q}_{yr,r,src,sec}`` for the following (``src``,``sec``).

```math
\\left(\\tilde{p}, \\tilde{q}\\right)_{yr,r,src,sec}
= \\left\\{
    seds \\left( yr, r, src, sec \\right) \\;\\vert\\; yr,\\, r,\\, (ff,ele)\\in src,\\, demsec\\in sec
\\right\\}
```

Average energy demand price ``\\tilde{pedef}_{yr,r,src}`` and its regional average
``\\hat{pedef}_{yr,src}`` are calculated as follows:

```math
\\begin{aligned}
\\tilde{pedef}_{yr,r,src}
&=
\\dfrac{\\sum_{sec} \\left( \\tilde{p}_{yr,r,src,sec} \\cdot \\tilde{q}_{yr,r,src,sec} \\right)}
      {\\sum_{sec} \\tilde{q}_{yr,r,src,sec}}
\\\\
\\hat{pedef}_{yr,src}
&=
\\dfrac{\\sum_{r} \\left( \\tilde{pedef}_{yr,r,src} \\cdot \\sum_{sec} \\tilde{q}_{yr,r,src,sec} \\right)}
      {\\sum_{r} \\sum_{sec} \\tilde{q}_{yr,r,src,sec}}
```
"""
function _partition_pedef!(d::Dict, set::Dict, maps::Dict)
    println("  Partitioning pedef(yr,r,src), average energy demand price")
    var, val = :pq, [:units,:value]

    splitter = DataFrame(permute((src=[set[:ff];"ele"], sec=set[:demsec], pq=["p","q"])))
    splitter = indexjoin(splitter, maps[:pq]; kind=:left)

    df, df_out = split_fill_unstack(copy(d[:energy]), splitter, var, val);

    df[!,:pq] .= df[:,:p] .* df[:,:q]
    
    df = combine_over(df,:sec)
    df[!,:value] .= df[:,:pq] ./ df[:,:q]
    df[!,:units] .= df[:,:units_p]
    
    # For missing or NaN results, replace with the average. NaN values are a result of an
    # aggregate q = 0 (stored here in pedef), so use this to identify.
    idx = intersect(findindex(df), propertynames(df_out))

    df_avg, df = SLiDE.impute_mean(df[:,[idx;:value]], :r; weight=df[:,[idx;:q]])

    d[:pedef] = sort(vcat(df_avg, df; cols=:intersect))
    return d[:pedef]
end


"""
`pe0(yr,r,src,sec)`
"""
function _partition_pe0!(d::Dict, set::Dict, maps::Dict)
    println("  Partitioning pe0(yr,r,src,sec)")
    df_demsec = DataFrame(sec=set[:demsec])
    df_energy = filter_with(d[:energy], (src=set[:e], sec=set[:demsec]))

    # Use average energy demand prices where available.
    df_p = filter_with(df_energy, (pq="p",); drop=true)
    df_pedef = crossjoin(d[:pedef], df_demsec)
    col = propertynames(df_p)
    idx = findindex(df_p)

    # !!!! Improvement to indexjoin where if fillmissing does some kind of column indicating,
    # (:pedef => :p could mean fill missing values in p with values from pedef --
    # I really like this approach)
    df = indexjoin(df_p, df_pedef; id=[:value,:pedef], fillmissing=false)
    df = edit_with(df, Replace(:value, missing, "pedef value"))

    # Use annual EIA data for crude oil averages.
    df_cprice = SLiDE._partition_cprice!(d, maps)

    idx_q = filter_with(df_energy, (src="cru", pq="q"); drop=:pq)[:,1:end-2]

    df_avg, df_cprice = SLiDE.impute_mean(df_cprice, :r; condition=idx_q)
    df_cprice = crossjoin(df_cprice, df_demsec)
    df_cprice = vcat(df_avg, df_cprice)

    d[:pe0] = [df[:,col]; df_cprice[:,col]]

    return d[:pe0]
end


"""
`ps0(yr,src)`
\\begin{aligned}
ps_{r,src} &= \\sum_{r,sec} pe_{yr,r,src,sec}
\\\\
ps_{r,src=cru} &= \\frac{1}{2}ps_{r,src=oil}
\\end{aligned}
"""
function _partition_ps0!(d::Dict)
    println("  Partitioning ps0(yr,src)")
    var, val = :src, [:units,:value]
    splitter = DataFrame(src=["cru","oil"])

    df = combine_over(d[:pe0], [:r,:sec]; fun=Statistics.minimum)
    df, df_out = split_fill_unstack(df, splitter, var, val)

    df[!,:cru] .= df[:,:oil] / 2

    d[:ps0] = stack_append(df, df_out, var, val; ensure_finite=false)
    return d[:ps0]
end


"""
`prodval(yr,r,src)`
"""
function _partition_prodval!(d::Dict, set::Dict, maps::Dict)
    println("  Partitioning prodval(yr,r,src)")
    
    df_ps0 = filter_with(d[:ps0], (src=set[:as],))

    df = operate_over(df_ps0, d[:prodbtu];
        id=[:usd_per_btu,:btu]=>:usd,
        units=maps[:operate],
    )
    df[!,:value] .= df[:,:factor] .* df[:,:usd_per_btu] .* df[:,:btu]
    
    d[:prodval] = operation_output(df)
    return d[:prodval]
end


"""
`shrgas(yr,r,src)`
"""
function _partition_shrgas!(d::Dict)
    println("  Partitioning shrgas(yr,r,src)")
    df = copy(d[:prodval])
    df = df / transform_over(df, :src)

    # Use ys0 to determine which indices to keep.
    idx_ys0 = crossjoin(
        filter_with(combine_over(d[:ys0], :g), (s="cng",); drop=true)[:,1:end-1],
        DataFrame(src=unique(df[:,:src])),
    )
    
    # Define indices where we need to calculate an average (that present for ys0 but not for
    # prodval), calculate REGIONAL average, and apply that to the determined index.
    df_avg, df = SLiDE.impute_mean(df, :r; condition=idx_ys0)
    df = vcat(df, df_avg)

    # Ensure all SECTORAL shares sum to one.
    df = df / combine_over(df, :src)
    d[:shrgas] = select(df, Not(:units))

    return d[:shrgas]
end


"""
`netgen(yr,r), net interstate electricity flow`
"""
function _partition_netgen!(d::Dict, maps::Dict)
    println("  Partitioning netgen(yr,r), net interstate electricity flow")
    # (1) Calculate for SEDS data
    df_ps0 = filter_with(d[:ps0], (src="ele",); drop=true)
    df_netgen = filter_with(d[:seds], (src="ele", sec="netgen", units=KWH); drop=true)

    df = operate_over(df_ps0, df_netgen;
        id=[:usd_per_kwh,:kwh]=>:value,
        units=maps[:operate],
    )
    df[!,:value] .= df[:,:factor] .* df[:,:usd_per_kwh] .* df[:,:kwh]
    operation_output!(df)

    # (2) Calculate for IO data.
    df_nd0 = filter_with(d[:nd0], (g="ele",); drop=true)
    df_xn0 = filter_with(d[:xn0], (g="ele",); drop=true)
    df_io = df_nd0 - df_xn0

    # (3) Label the data by its source and concatenate.
    df_seds = edit_with(df, Add(:dataset,"seds"))
    df_io = edit_with(df_io, [Add(:dataset,"io"), Add(:units, USD)])
    d[:netgen] = vcat(df_seds, df_io)
end


"""
`trdele(yr,r,g=ele,t)`, electricity imports-exports to/from U.S.
```math
\\tilde{trdele}_{yr,r,t} \\text{ [billion usd]}
= \\left\\{
    seds \\left( yr, r, src, sec \\right) \\;\\vert\\; yr,\\, r,\\, src=ele,\\, [imports,exports]\\in sec
\\right\\}
```
"""
function _partition_trdele!(d::Dict)
    println("  Partitioning trdele(yr,r,g=ele,t), electricity imports-exports to/from U.S.")
    df = filter_with(d[:seds], (src="ele", sec=["imports","exports"], units=USD))
    d[:trdele] = edit_with(df, Rename.([:src,:sec],[:g,:t]))
    return d[:trdele]
end


"""
`pctgen(yr,r,src,sec)`
"""
function _partition_pctgen!(d::Dict, set::Dict)
    println("  Partitioning pctgen(yr,r,src,sec)")
    df_ele = copy(d[:elegen])
    df_ele = df_ele / transform_over(df_ele, :src)
    df_ele = filter_with(df_ele, (src=set[:ff],))

    df_oth = fill_with((
        yr=set[:yr],
        r=set[:r],
        src=set[:e],
        sec=setdiff(set[:demsec],["ele"]),
        units=KWH,
    ), 0.02)

    d[:pctgen] = vcat(df_oth, edit_with(df_ele, Add(:sec,"ele")))
    return d[:pctgen]
end


"""
`eq0(yr,r,src,sec)`
```math
\\tilde{eq}_{yr,r,src,sec}
= \\left\\{
    energy \\left( yr, r, src, sec \\right) \\;\\vert\\; yr,\\, r,\\, e\\in src,\\, demsec\\in sec
\\right\\}
```
"""
function _partition_eq0!(d::Dict, set::Dict)
    println("  Partitioning eq0(yr,r,src,sec)")
    df = filter_with(d[:energy], (src=set[:e], sec=set[:demsec], pq="q"); drop=true)
    df[!,:value] = max.(0, df[:,:value])
    d[:eq0] = dropzero(df)
    return d[:eq0]
end


"""
```math
\\tilde{ed}_{yr,r,src,sec} = \\dfrac
    {\\tilde{pe}_{yr,r,src,sec}}
    {\\tilde{eq}_{yr,r,src,sec}}
```
"""
function _partition_ed0!(d::Dict, set::Dict, maps::Dict)
    println("  Partitioning ed0(yr,r,src,sec)")
    idx_p = SLiDE._index_src_sec_pq!(d, set, maps, (:e,:demsec,:p))
    idx_q = SLiDE._index_src_sec_pq!(d, set, maps, (:e,:demsec,:q))

    df_p = fill_zero(d[:pe0]; with=idx_p)
    df_q = fill_zero(d[:eq0]; with=idx_q)

    df = operate_over(df_p, df_q;
        id=[:usd_per_x,:x]=>:usd,
        units=maps[:operate],
        fillmissing=false,
    )
    df[!,:value] .= df[:,:factor] .* df[:,:usd_per_x] .* df[:,:x]

    d[:ed0] = dropzero(SLiDE.operation_output(df))
    return d[:ed0]
end


"""
`emarg0(yr,r,src,sec)`
```math
\\tilde{emarg}_{yr,r,src,sec} = \\dfrac
    {\\tilde{pe}_{yr,r,src,sec} - \\tilde{ps}_{yr,src}}
    {\\tilde{eq}_{yr,r,src,sec}}
```
"""
function _partition_emarg0!(d::Dict, set::Dict, maps::Dict)
    println("  Partitioning emarg0(yr,r,src,sec)")
    idx_p = SLiDE._index_src_sec_pq!(d, set, maps, (:e,:demsec,:p))
    idx_q = SLiDE._index_src_sec_pq!(d, set, maps, (:e,:demsec,:q))

    df_p = d[:pe0] - d[:ps0]

    df_p = fill_zero(df_p; with=idx_p)
    df_q = fill_zero(d[:eq0]; with=idx_q)

    df = operate_over(df_p, df_q;
        id=[:usd_per_x,:x]=>:usd,
        units=maps[:operate],
        fillmissing=false,
    )
    df[!,:value] .= df[:,:factor] .* df[:,:usd_per_x] .* df[:,:x]
    operation_output!(df)

    d[:emarg0] = df[abs.(df[:,:value]).>=1e-8, :] # !!!! drop_small?
    return d[:emarg0]
end


"""
`ned0(yr,r,src,sec)`
```math
\\tilde{ned}_{yr,r,src,sec} = \\tilde{ed}_{yr,r,src,sec} - \\tilde{emarg}_{yr,r,src,sec}
```
"""
function _partition_ned0!(d::Dict)
    println("  Partitioning ned0(yr,r,src,sec)")
    d[:ned0] = d[:ed0] - d[:emarg0]
    return d[:ned0]
end


"""
"""
function _index_src_sec_pq!(d, maps, x::Pair)
    (key,val) = (x[1], x[2])
    if !haskey(d, key)
        idx = DataFrame(permute(val))
        idx = indexjoin(idx, maps[:pq]; kind=:inner)

        # Drop pq if it isn't adding new information.
        SLiDE.nunique(idx[:,:pq])==1 && (idx = select(idx, Not(:pq)))

        merge!(d, Dict(key => idx))
    end
    return d[key]
end

function _index_src_sec_pq!(d, set, maps, key::Tuple)
    if !haskey(d, key)
        (src,sec,pq) = key
        x = key => (src=set[src], sec=set[sec], pq=string(pq))
        SLiDE._index_src_sec_pq!(d, maps, x)
    end
    return d[key]
end