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
function _module_convfac(d::Dict)
    return filter_with(d[:seds], (src="cru", sec="supply", units=BTU_PER_BARREL); drop=true)
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
function _module_cprice!(d::Dict, maps::Dict)
    id = [:usd_per_barrel,:btu_per_barrel] => :usd_per_btu
    df = _module_convfac(d)
    col = propertynames(df)

    df = operate_over(d[:crude_oil], df; id=id, units=maps[:operate])

    df[!,:value] .= df[:,:factor] .* df[:,:usd_per_barrel] ./ df[:,:btu_per_barrel]

    d[:cprice] = df[:,col]
    return d[:cprice]
end


"""
```math
\\tilde{prodbtu}_{yr,r} \\text{ [trillion btu]}
= \\left\\{
    seds \\left( yr, r, src, sec \\right) \\;\\vert\\; yr,\\, r,\\, as\\in src,\\, sec=supply
\\right\\}
```
"""
function _module_prodbtu!(d::Dict, set::Dict)
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
function _module_pedef!(d::Dict, set::Dict)
    var = :pq
    val = [:units,:value]

    splitter = DataFrame(permute((src=[set[:ff];"ele"], sec=set[:demsec], pq=["p","q"])))
    splitter = indexjoin(splitter, maps[:pq]; kind=:left)
    idx = [:yr,:r,:src]

    df, df_out = split_fill_unstack(copy(d[:energy]), splitter, var, val);

    df[!,:pq] .= df[:,:p] .* df[:,:q]

    pedef = combine_over(df,:sec)
    pedef[!,:value] .= pedef[:,:pq] ./ pedef[:,:q]
    pedef[!,:units] .= pedef[:,:units_p]

    idx = intersect(findindex(pedef), propertynames(df_out))
    
    # For missing or NaN results, replace with the average. NaN values are a result of an
    # aggregate q = 0 (stored here in pedef), so use this to identify.
    idx_r, pedef = split_with(pedef, (q=0.,))

    pedef_r = combine_over(pedef[:,[idx;:value]] * pedef[:,[idx;:q]], :r) /
        combine_over(pedef[:,[idx;:q]], :r)
    
    pedef_r = indexjoin(idx_r[:,1:3], pedef_r; kind=:inner)

    d[:pedef] = sort(vcat(pedef_r, pedef; cols=:intersect))
    return d[:pedef]
end


"""
"""
function _module_pe0!(d::Dict, set::Dict)
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
    df_cprice = _module_cprice!(d, maps)

    idx_q = filter_with(df_energy, (src="cru", pq="q"); drop=:pq)[:,1:end-2]
    idx_avg = antijoin(idx_q, df_cprice,
        on=intersect(propertynames(df_cprice),propertynames(idx_q)))

    df_avg = combine_over(df_cprice, :r; fun=Statistics.mean)
    df_avg = indexjoin(idx_avg, df_avg)

    df_cprice = crossjoin(df_cprice, DataFrame(src="cru",sec=set[:demsec]))
    df_cprice = vcat(df_avg, df_cprice)

    d[:pe0] = [df[:,col]; df_cprice[:,col]]

    return d[:pe0]
end


"""
"""
function _module_ps0!(d::Dict)
    var = :src
    val = [:units,:value]
    splitter = DataFrame(src=["cru","oil"])

    df = combine_over(d[:pe0], [:r,:sec]; fun=Statistics.minimum)
    df, df_out = split_fill_unstack(df, splitter, var, val)

    df[!,:cru] .= df[:,:oil] / 2

    d[:ps0] = stack_append(df, df_out, var, val; ensure_finite=false)
    return d[:ps0]
end


"""
"""
function _module_prodval!(d::Dict, set::Dict, maps::Dict)
    id = [:usd_per_btu,:btu]=>:usd
    col = propertynames(d[:prodbtu])
    df = filter_with(d[:ps0], (src=set[:as],))

    df = operate_over(df, d[:prodbtu]; id=id, units=maps[:operate])
    df[!,:value] .= df[:,:factor] .* df[:,:usd_per_btu] .* df[:,:btu]
    d[:prodval] = select(df, col)
    return d[:prodval]
end


"""
"""
function _module_shrgas!(d::Dict)
    df = copy(d[:prodval])
    df = df / transform_over(df, :src)

    # Use ys0 to determine which indices to keep.
    idx_ys0 = crossjoin(
        filter_with(combine_over(d[:ys0], :g), (s="cng",); drop=true)[:,1:end-1],
        DataFrame(src=unique(df[:,:src])),
    )
    
    # Define indices where we need to calculate an average (that present for ys0 but not for
    # prodval), calculate REGIONAL average, and apply that to the determined index.
    idx_avg = antijoin(idx_ys0, df, on=propertynames(idx_ys0))

    df_avg = combine_over(df, :r; fun=Statistics.mean)
    df_avg = indexjoin(idx_avg, df_avg)

    # Ensure all SECTORAL shares sum to one.
    df = vcat(df, df_avg)
    df = df / combine_over(df, :src)
    d[:shrgas] = select(df, Not(:units))

    return d[:shrgas]
end


"""
"""
function _module_netgen!(d::Dict)
    # SEDS data
    df_ps0 = filter_with(d[:ps0], (src="ele",); drop=true)
    df_netgen = filter_with(d[:seds], (src="ele", sec="netgen", units=KWH); drop=true)

    df = operate_over(df_ps0, df_netgen; id=[:usd_per_kwh,:kwh]=>:value, units=maps[:operate])

    df[!,:value] .= df[:,:factor] .* df[:,:usd_per_kwh] .* df[:,:kwh]
    # df[:,:value] /= 10  # !!!!factor

    # IO data
    df_nd0 = filter_with(d[:nd0], (g="ele",); drop=true)
    df_xn0 = filter_with(d[:xn0], (g="ele",); drop=true)
    df_io = df_nd0 - df_xn0

    # Label the data by its source and concatenate.
    df_seds = edit_with(df, Add(:dataset,"seds"))
    df_io = edit_with(df_io, [Add(:dataset,"io"), Add(:units, KWH)])

    col = propertynames(df_netgen)
    insert!(col, length(col)-1, :dataset)
    d[:netgen] = sort(vcat(df_seds[:,col], df_io[:,col]))
end


"""
```math
\\tilde{trdele}_{yr,r,t} \\text{ [billion usd]}
= \\left\\{
    seds \\left( yr, r, src, sec \\right) \\;\\vert\\; yr,\\, r,\\, src=ele,\\, [imports,exports]\\in sec
\\right\\}
```
"""
function _module_trdele!(d::Dict)
    df = filter_with(d[:seds], (src="ele", sec=["imports","exports"], units=USD); drop=:src)
    d[:trdele] = edit_with(df, [Rename(:src,:g), Rename(:sec,:t)])
    return d[:trdele]
end


"""
"""
function _module_pctgen!(d::Dict, set::Dict)
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
```math
\\tilde{eq}_{yr,r,src,sec}
= \\left\\{
    energy \\left( yr, r, src, sec \\right) \\;\\vert\\; yr,\\, r,\\, e\\in src,\\, demsec\\in sec
\\right\\}
```
"""
function _module_eq0!(d::Dict, set::Dict)
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
function _module_ed0!(d::Dict, set::Dict, maps::Dict)
    id = [:usd_per_x,:x] => :usd
    
    idx_p = _index_src_sec_pq!(d, set, maps, (:e,:demsec,:p))
    idx_q = _index_src_sec_pq!(d, set, maps, (:e,:demsec,:q))

    df_p = fill_zero(d[:pe0]; with=idx_p)
    df_q = fill_zero(d[:eq0]; with=idx_q)
    col = propertynames(df_p)

    df = operate_over(df_p, df_q; id=id, units=maps[:operate], fillmissing=false)
    df[!,:value] .= df[:,:factor] .* df[:,:usd_per_x] .* df[:,:x]

    d[:ed0] = dropzero(df[:,col])
    return d[:ed0]
end


"""
```math
\\tilde{emarg}_{yr,r,src,sec} = \\dfrac
    {\\tilde{pe}_{yr,r,src,sec} - \\tilde{ps}_{yr,src}}
    {\\tilde{eq}_{yr,r,src,sec}}
```
"""
function _module_emarg0!(d::Dict, set::Dict, maps::Dict)
    id = [:usd_per_x,:x] => :usd

    idx_p = _index_src_sec_pq!(d, set, maps, (:e,:demsec,:p))
    idx_q = _index_src_sec_pq!(d, set, maps, (:e,:demsec,:q))

    df_p = d[:pe0] - d[:ps0]

    df_p = fill_zero(df_p; with=idx_p)
    df_q = fill_zero(d[:eq0]; with=idx_q)
    col = propertynames(df_p)

    df = operate_over(df_p, df_q; id=id, units=maps[:operate], fillmissing=false)
    df[!,:value] .= df[:,:factor] .* df[:,:usd_per_x] .* df[:,:x]

    d[:emarg0] = df[abs.(df[:,:value]).>=1e-8, col]

    return d[:emarg0]
end


"""
```math
\\tilde{ned}_{yr,r,src,sec} = \\tilde{ed}_{yr,r,src,sec} - \\tilde{emarg}_{yr,r,src,sec}
```
"""
function _module_ned0!(d::Dict)
    d[:ned0] = d[:ed0] - d[:emarg0]
    return d[:ned0]
end


"""
"""
function _scale_shrgas!(d::Dict, maps::Dict, set::Dict, on)
    key = Tuple([:shrgas;on])
    if !haskey(d,key)
        d[key] = SLiDE._scale_extend(d[:shrgas], maps[:cng], set[:sector], on)
    end
    return d[key]
end


"""
"""
function _disagg_with_shrgas!(d::Dict, maps::Dict, set::Dict, key::Symbol)
    taxes = [:ta0,:tm0,:ty0]
    on = SLiDE._find_sector(d[key])

    if !isempty(on)
        d[key] = if key in taxes
            SLiDE.scale_with_map(d[key], _scale_shrgas!(d, maps, set, on), on; key=key)
        else
            SLiDE.scale_with_share(d[key], _scale_shrgas!(d, maps, set, on), on; key=key)
        end
    end

    return d[key]
end


"""
```math
\\begin{aligned}
mrgshr_{yr,r,m,g=trn} &= \\dfrac
    {md_{yr,r,m,g=trn}}
    {\\sum_m md_{yr,r,m,g=trn}}
\\\\
mrgshr_{yr,r,m,g=trd} &= 1 - mrgshr_{yr,r,m,g=trn}
\\end{aligned}
```
"""
function _module_mrgshr!(d::Dict, set::Dict)
    if !haskey(d,:mrgshr)
        var = :m
        val = :value
        col = propertynames(d[:md0])

        df = filter_with(d[:md0], (g=set[:e],))

        df = df / combine_over(df, var; digits=false)

        df = unstack(df, var, val)
        df = fill_zero(df; with=(yr=set[:yr], r=set[:r], g=set[:e]))

        df[!,:trd] .= 1.0 .- df[:,:trn]

        d[:mrgshr] = select(dropzero(SLiDE._stack(df, :m, :value)), col)
    end
    return d[:mrgshr]
end


"""
```math
md_{yr,r,m,g} = mrgshr_{yr,r,m,g} \\cdot \\sum_{sec} emrg_{yr,r,src\\rightarrow g, sec}
```
"""
function _module_md0!(d::Dict, set::Dict)
    df = d[:md0]
    g = SLiDE._find_sector(df)[1]

    df, df_out = split_with(df, DataFrame(g=>set[:e],))

    df_emrg = edit_with(d[:emarg0], Rename(:src,g))

    df = d[:mrgshr] * combine_over(df_emrg, :sec)

    d[:md0] = dropzero(vcat(df_out, df; cols=:intersect))
    return d[:md0]
end


"""
```math
\\tilde{cd}_{yr,r,g}
= \\left\\{
    ed \\left(yr,r,src\\rightarrow g, sec\\right) \\;\\vert\\; yr,\\, r,\\, g,\\, sec=res
\\right\\}
```
"""
function _module_cd0!(d::Dict)
    df = d[:cd0]
    g = SLiDE._find_sector(df)[1]

    df, df_out = split_with(df, DataFrame(g=>set[:e],))

    df_ed0 = edit_with(d[:ed0], Rename(:src,g))

    df = filter_with(df_ed0, (sec="res",); drop=true)
    d[:cd0] = vcat(df_out, df; cols=:intersect)

    return d[:cd0]
end


"""
"""
function _module_ys0!(d::Dict, set::Dict, maps::Dict)
    x = set[:e]
    idx = SLiDE._find_sector(d[:ys0])
    df, df_out = split_with(d[:ys0], DataFrame(s=x, g=x))

    # -----
    # Edit ele,cru,gas,col.
    df_energy = filter_with(d[:energy], (src=x, sec="supply", pq="q"); drop=true)
    df_ps = filter_with(d[:ps0], (src=x,))

    df = operate_over(df_energy, df_ps;
        id=[:x,:usd_per_x]=>:usd,
        units=maps[:operate], 
        fillmissing=0.0,
    )

    df[!,:value] .= df[:,:factor] .* df[:,:x] .* df[:,:usd_per_x]

    # -----
    # Since we don't have ps0(oil), calculate (oil,oil) as a share of ned0.
    x = Deselect([:units],"==")
    df_energy = filter_with(edit_with(d[:energy], x), (src="cru", sec="ref", pq="q"); drop=true)
    df_ned = filter_with(edit_with(d[:ned0], x), (src="oil",))

    df_energy = df_energy / transform_over(df_energy, :r)
    df_ned = transform_over(combine_over(df_ned, :sec), :r)

    df_oil = df_energy * df_ned

    # Add this back to df and adjust indices to get src -> (s,g).
    df = edit_with(vcat(df, df_oil; cols=:intersect), Rename(:src,idx[1]))
    df[!,idx[2]] .= df[:,idx[1]]

    # -----
    # Make zero if production is zero.
    xgen = "ele"
    idxgen = filter_with(df[:,findindex(df)], (s=xgen,g=xgen); drop=:g)
    df_out = indexjoin(df_out, idxgen; id=[:ys0,:generation], indicator=true)
    df_out[.&(df_out[:,:s].==xgen, .!df_out[:,:generation]),:value] .= 0.0

    # FINALLY, add this back to ys0.
    d[:ys0] = dropzero(vcat(df_out[:,1:end-2], df))
    return d[:ys0]
end


"""
"""
function _module_inpshr!(d::Dict, set::Dict, maps::Dict)
    if !haskey(d, :inpshr)
        x = unique(d[:id0][:,:g])
        x_idx = [Deselect([:g,:units,:value], "=="); Rename(:src,:g)]

        idx_pctgen = edit_with(d[:pctgen][d[:pctgen][:,:value].>0.01, :], x_idx)
        idx_ys0 = edit_with(filter_with(d[:ys0], DataFrame(s=x, g=x)), x_idx)
        idx_ed0 = edit_with(d[:ed0], x_idx)

        idx_shr = filter_with(innerjoin(idx_pctgen, maps[:demand], on=:sec), (s=x,))
        idx_shr_avg = indexjoin(idx_shr, idx_ys0, idx_ed0; kind=:inner)

        # Set up to average. Filter id0, fill it with zeros, and map both to demand sectors.
        df = filter_with(copy(d[:id0]), (g=set[:e],))
        df0 = fill_zero(df)

        df_sec = indexjoin(df, maps[:demand]; kind=:inner)
        df0_sec = indexjoin(df0, maps[:demand]; kind=:inner)
        
        # Calculate input share.
        df_shr = df_sec / transform_over(df_sec, :s; digits=false)
        df_shr = filter_with(idx_shr, df_shr)
        
        # Adjust idx_shr_avg to remove indices for which df is already defined.
        idx_shr_avg = antijoin(idx_shr_avg, df_shr,
            on=intersect(propertynames(idx_shr_avg), propertynames(df_shr)))
        
        # Calculate the average using the FILLED version of the DataFrames.
        df_shr_avg = transform_over(df0, :r; digits=false) / transform_over(df0_sec, [:r,:s]; digits=false)
        df_shr_avg = filter_with(dropzero(df_shr_avg), idx_shr_avg)

        d[:inpshr] = vcat(df_shr, df_shr_avg)
    end
    return d[:inpshr]
end


"""
"""
function _module_id0!(d::Dict, set::Dict, maps::Dict)
    df, df_out = split_with(d[:id0], (g=set[:e],))

    df_inpshr = _module_inpshr!(d, set, maps)
    df_ed0 = edit_with(d[:ed0], [Rename(:src,:g), Deselect([:units],"==")])

    df = combine_over(dropzero(df_ed0 * df_inpshr), :sec; digits=false)
    d[:id0] = vcat(df_out, df)
    return d[:id0]
end


"""
"""
function _module_x0!(d::Dict)
    x = [Add(:g,"ele"), Deselect([:units],"==")]

    df, df_out = split_with(d[:x0], (g="ele",))
    df = edit_with(filter_with(d[:trdele], (t="exports",); drop=true), x)

    d[:x0] = vcat(df_out, df)
    return d[:x0]
end


"""
"""
function _module_m0!(d::Dict)
    x = [Add(:g,"ele"), Deselect([:units],"==")]
    
    df, df_out = split_with(d[:m0], (g="ele",))
    df = edit_with(filter_with(d[:trdele], (t="imports",); drop=true), x)

    d[:m0] = vcat(df_out, df)
    return d[:m0]
end


"""
"""
function _module_zero_prod!(d::Dict, on)
    key = Tuple([:zero_prod;on])
    if !haskey(d,key)
        idx_zero = fill_zero(combine_over(filter_with(d[:ys0], (s="ele",)), :g))
        idx_zero = idx_zero[idx_zero[:,:value].==0.0, 1:end-1]

        # Rename if appropriate.
        if isempty(intersect(propertynames(idx_zero), ensurearray(on)))
            idx_zero = edit_with(idx_zero, Rename.(:s,on))
        end

        d[key] = idx_zero
    end
    return d[key]
end


function _module_zero_prod!(d::Dict, key::Symbol)
    on = SLiDE._find_sector(d[key])
    d[key] = filter_with(d[key], Not(_module_zero_prod!(d, on)))
    return d[key]
end


function _module_zero_prod!(d::Dict)
    [_module_zero_prod!(d,k) for k in [:ld0,:kd0,:ty0,:id0,:s0,:xd0,:xn0,:x0,:rx0]]
    return d
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
        _index_src_sec_pq!(d, maps, x)
    end
    return d[key]
end