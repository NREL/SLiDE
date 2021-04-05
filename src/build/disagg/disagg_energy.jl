function disagg_energy!(d, set, maps)

    # Disaggregate all using shrgas.
    _disagg_with_shrgas!(d, set, maps)

    # Make individual adjustments.
    _disagg_energy_md0!(d, set)
    _disagg_energy_cd0!(d)
    _disagg_energy_ys0!(d, set, maps)
    _disagg_energy_id0!(d, set, maps)
    _disagg_energy_m0!(d)
    _disagg_energy_x0!(d)

    # Zero production.
    _disagg_energy_zero_prod!(d)

    # Update household disaggregation.
    SLiDE._disagg_hhadj!(d)

    # Need to keep small values until after we've built emissions info.
    # drop_small!(d)
    
    return d, set, maps
end


"""
"""
function _scale_shrgas!(d::Dict, set::Dict, maps::Dict, on)
    key = Tuple([:shrgas;on])
    if !haskey(d,key)
        d[key] = SLiDE._scale_extend(d[:shrgas], maps[:cng], set[:sector], on)
    end
    return d[key]
end


"""
"""
function _disagg_with_shrgas!(d, set, maps)
    parameters = collect(keys(SLiDE.build_parameters("parameters")))
    [_disagg_with_shrgas!(d, set, maps, k) for k in parameters]

    # Update saved sectors.
    SLiDE.set_sector!(set, unique(d[:ys0][:,:s]))

    maps[:demand] = filter_with(maps[:demand], (s=set[:s],))

    return d, set, maps
end


"""
"""
function _disagg_with_shrgas!(d::Dict, set::Dict, maps::Dict, key::Symbol)
    taxes = [:ta0,:tm0,:ty0]
    on = SLiDE._find_sector(d[key])

    if !isempty(on)
        d[key] = if key in taxes
            SLiDE.scale_with_map(d[key], _scale_shrgas!(d, set, maps, on), on; key=key)
        else
            SLiDE.scale_with_share(d[key], _scale_shrgas!(d, set, maps, on), on; key=key)
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
function _disagg_energy_mrgshr!(d::Dict, set::Dict)
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
function _disagg_energy_md0!(d::Dict, set::Dict)
    df = d[:md0]
    g = SLiDE._find_sector(df)[1]

    df, df_out = split_with(df, DataFrame(g=>set[:e],))
    
    df_mrgshr = _disagg_energy_mrgshr!(d, set)
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
function _disagg_energy_cd0!(d::Dict)
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
function _disagg_energy_ys0!(d::Dict, set::Dict, maps::Dict)
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
function _disagg_energy_inpshr!(d::Dict, set::Dict, maps::Dict)
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
function _disagg_energy_id0!(d::Dict, set::Dict, maps::Dict)
    df, df_out = split_with(d[:id0], (g=set[:e],))

    df_inpshr = _disagg_energy_inpshr!(d, set, maps)
    df_ed0 = edit_with(d[:ed0], [Rename(:src,:g), Deselect([:units],"==")])

    df = combine_over(dropzero(df_ed0 * df_inpshr), :sec; digits=false)
    d[:id0] = vcat(df_out, df)
    return d[:id0]
end


"""
"""
function _disagg_energy_x0!(d::Dict)
    x = [Add(:g,"ele"), Deselect([:units],"==")]

    df, df_out = split_with(d[:x0], (g="ele",))
    df = edit_with(filter_with(d[:trdele], (t="exports",); drop=true), x)

    d[:x0] = vcat(df_out, df)
    return d[:x0]
end


"""
"""
function _disagg_energy_m0!(d::Dict)
    x = [Add(:g,"ele"), Deselect([:units],"==")]
    
    df, df_out = split_with(d[:m0], (g="ele",))
    df = edit_with(filter_with(d[:trdele], (t="imports",); drop=true), x)

    d[:m0] = vcat(df_out, df)
    return d[:m0]
end


"""
"""
function _disagg_energy_zero_prod!(d::Dict, on)
    key = Tuple([:zero_prod;on])
    if !haskey(d,key)
        idx_zero = fill_zero(combine_over(filter_with(d[:ys0], (s="ele",)), :g))
        idx_zero = getzero(idx_zero)

        # Rename if appropriate.
        if isempty(intersect(propertynames(idx_zero), ensurearray(on)))
            idx_zero = edit_with(idx_zero, Rename.(:s,on))
        end

        d[key] = idx_zero
    end
    return d[key]
end


function _disagg_energy_zero_prod!(d::Dict, key::Symbol)
    on = SLiDE._find_sector(d[key])
    d[key] = filter_with(d[key], Not(_disagg_energy_zero_prod!(d, on)))
    return d[key]
end


function _disagg_energy_zero_prod!(d::Dict)
    [_disagg_energy_zero_prod!(d,k) for k in [:ld0,:kd0,:ty0,:id0,:s0,:xd0,:xn0,:x0,:rx0]]
    return d
end


"""
"""
function drop_small!(d; digits=5)
    taxes = [:ta0, :tm0, :ty0]
    parameters = collect(keys(SLiDE.build_parameters("parameters")))

    [d[k] = drop_small(d[k]; digits=digits, key=k) for k in setdiff(parameters,taxes)]
    return d
end


"""
"""
function drop_small(df; digits=5, key=missing)
    sector = SLiDE._find_sector(df)
    
    if !isempty(sector)
        col = setdiff(findindex(df), [:yr; sector[1]])
        !ismissing(key) && println("\tDropping small values from $key\t", col)

        df = drop_small_average(df, col; digits=digits)
        df = drop_small_value(df; digits=digits+2)
    end
    
    return df
end


"""
"""
function drop_small_average(df, col; digits=5)
    idx = df / combine_over(df, col; fun=Statistics.mean, digits=false)
    idx = getzero(idx; digits=digits)
    return filter_with(df, Not(idx))
end


"""
"""
function drop_small_value(df; digits=7)
    idx = getzero(df; digits=digits)
    return filter_with(df, Not(idx))
end

# _drop_small_value(df, small::Float64) = edit_with(df, Drop.(findvalue(df), small, "<"))
# _drop_small_value(df, digits::Int) = _drop_small_value(df, 1/(10^(digits+1)))