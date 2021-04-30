function disaggregate_energy!(dataset, d, set, maps)
    step = "disaggregate"
    d_read = read_build(set!(dataset; step=step))

    if dataset.step=="input"
        # Do some renaming here so we don't have to later.
        [d[k] = edit_with(d[k], Rename(:src,:g)) for k in [:ed0,:emarg0,:pctgen]]

        # Disaggregate.
        _disaggregate_cng!(d, set, maps)
        _disagg_energy_fvs!(d)

        # Make individual adjustments.
        _disagg_energy_md0!(d, set)
        _disagg_energy_cd0!(d, set)
        _disagg_energy_ys0!(d, set, maps)
        _disagg_energy_id0!(d, set, maps)
        _disagg_energy_m0!(d)
        _disagg_energy_x0!(d)

        # Zero production.
        _disagg_energy_zero_prod!(d)

        # Update household disaggregation.
        _disagg_hhadj!(d)
        write_build!(set!(dataset; step=step), d)
    end
    
    return d, set, maps
end


"""
"""
function _disaggregate_cng!(d, set, maps)
    weighting, mapping = share_with(Weighting(d[:shrgas]), Mapping(maps[:cng]))
    disaggregate_sector!(d, set, weighting; label=:cng)
    maps[:demand] = filter_with(maps[:demand], (s=set[:sector],))
    return d, set
end


"""
`fvs`, initial factor value shares in production
```math
fvs_{yr,r,s,x} = \\dfrac{x_{yr,r,s}}{\\sum_{g}ys_{yr,r,s,g}}
```
"""
function _disagg_energy_fvs!(d::Dict)
    println("  Calculating fvs, initial factor value shares in production")
    d[:fvs] = vcat([_disagg_energy_fvs(d,key) for key in [:kd0,:ld0]]...)
    return d[:fvs]
end

function _disagg_energy_fvs(d::Dict, key::Symbol)
    df = d[key] / combine_over(d[:ys0],:g; digits=false)
    col = propertynames(df)
    df = edit_with(df, Add(:parameter, "$key"))
    return select!(df, insert!(col, length(col), :parameter))
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
    println("  Calculating mrgshr(yr,r,m,g=e)")
    if !haskey(d,:mrgshr)
        var, val = :m, :value
        col = propertynames(d[:md0])

        df = filter_with(d[:md0], (g=set[:e],))
        df = df / combine_over(df, var; digits=false)

        df = unstack(df, var, val)
        df = fill_zero(df; with=(yr=set[:yr], r=set[:r], g=set[:e]))
        df[!,:trd] .= 1.0 .- df[:,:trn]

        d[:mrgshr] = select(dropzero(_stack(df, var, val)), col)
    end
    return d[:mrgshr]
end


"""
`md0(yr,r,m,g)`, margin demand
```math
md_{yr,r,m,g} = mrgshr_{yr,r,m,g} \\cdot \\sum_{sec} emrg_{yr,r,src\\rightarrow g, sec}
```
"""
function _disagg_energy_md0!(d::Dict, set::Dict)
    println("  Calculating md0(yr,r,m,g=e), margin demand")

    df, df_out = split_with(d[:md0], DataFrame(g=set[:e],))
    
    df_mrgshr = _disagg_energy_mrgshr!(d, set)
    df = df_mrgshr * combine_over(d[:emarg0], :sec)

    d[:md0] = dropzero(vcat(df_out, df; cols=:intersect))
    return d[:md0]
end


"""
`cd0(yr,r,g)`, national final consumption
```math
\\tilde{cd}_{yr,r,g}
= \\left\\{
    ed \\left(yr,r,src\\rightarrow g, sec\\right) \\;\\vert\\; yr,\\, r,\\, g,\\, sec=res
\\right\\}
```
"""
function _disagg_energy_cd0!(d::Dict, set::Dict)
    println("  Calculating cd0(yr,r,g=e), national final consumption")
    df, df_out = split_with(d[:cd0], DataFrame(g=set[:e],))

    df = filter_with(d[:ed0], (sec="res",); drop=true)

    d[:cd0] = vcat(df_out, df; cols=:intersect)
    return d[:cd0]
end


"""
"""
function _disagg_energy_ys0!(d::Dict, set::Dict, maps::Dict)
    println("  Calculating ys0(yr,r,s=e,g=e), regional sectoral output")
    x = set[:e]
    df, df_out = split_with(d[:ys0], DataFrame(s=x, g=x))
    
    # (1) Calculate data for e = [ele,cru,gas,col].
    df_energy = filter_with(d[:energy], (src=x, sec="supply", pq="q"); drop=true)
    df_ps0 = filter_with(d[:ps0], (src=x,))

    df = operate_over(df_energy, df_ps0;
        id=[:x,:usd_per_x]=>:usd,
        units=maps[:operate], 
        fillmissing=0.0,
    )
    df[!,:value] .= df[:,:factor] .* df[:,:x] .* df[:,:usd_per_x]
    operation_output!(df, Not(:units))

    # (2) Since we don't have ps0(oil), calculate (oil,oil) as a share of ned0.
    df_energy = filter_with(d[:energy], (src="cru", sec="ref", pq="q"); drop=true)
    df_ned = filter_with(d[:ned0], (src="oil",))

    df_energy = df_energy / transform_over(df_energy, :r)
    df_ned = transform_over(combine_over(df_ned, :sec), :r)

    df_oil = select(df_energy, Not(:units)) * df_ned

    # (3) Add this back to df and adjust indices to get src -> (s,g).
    df = edit_with(vcat(df, df_oil), Rename(:src,:g))
    df[!,:s] .= df[:,:g]

    # (4) Make zero if production is zero.
    idxgen = filter_with(df[:,findindex(df)], (s="ele", g="ele"); drop=:g)
    df_out = indexjoin(df_out, idxgen; id=[:ys0,:generation], indicator=true)
    df_out[.&(df_out[:,:s].=="ele", .!df_out[:,:generation]),:value] .= 0.0

    # FINALLY, add this back to ys0.
    d[:ys0] = dropzero(vcat(df_out[:,1:end-2], df))
    return d[:ys0]
end


"""
"""
function _disagg_energy_inpshr!(d::Dict, set::Dict, maps::Dict)
    if !haskey(d, :inpshr)
        x = set[:sector]

        # Save/define indices for which to perform these operations.
        idx = Dict(
            :shr => d[:pctgen][d[:pctgen][:,:value].>0.01, :],
            :ys0 => select(filter_with(d[:ys0], DataFrame(s=x, g=x)), Not(:g)),
            :ed0 => d[:ed0],
        )
        [idx[k] = select(df, Not(:value)) for (k,df) in idx]

        idx[:shr] = innerjoin(idx[:shr], maps[:demand], on=:sec)
        idx[:shr_avg] = indexjoin(values(idx)...; kind=:inner)

        # Set up to average. Filter id0, fill it with zeros, and map both to demand sectors.
        df = filter_with(copy(d[:id0]), (g=set[:e],))
        df0 = fill_zero(df)

        df_sec = indexjoin(df, maps[:demand]; kind=:inner)
        df0_sec = indexjoin(df0, maps[:demand]; kind=:inner)
        
        # Calculate input share.
        df_shr = df_sec / transform_over(df_sec,:s; digits=false)
        df_shr = filter_with(df_shr, idx[:shr])
        
        # Adjust share average index to remove indices for which df is already defined.
        idx[:shr_avg] = antijoin(idx[:shr_avg], df_shr, on=propertynames(idx[:shr_avg]))
        
        # Calculate the average using the FILLED version of the DataFrames.
        df_shr_avg = transform_over(df0, :r; digits=false) /
                transform_over(df0_sec, [:r,:s]; digits=false)
        df_shr_avg = filter_with(dropzero(df_shr_avg), idx[:shr_avg])

        d[:inpshr] = vcat(df_shr, df_shr_avg)
    end
    return d[:inpshr]
end


"""
`id0(yr,r,g=ele,s)`, regional intermediate demand
"""
function _disagg_energy_id0!(d::Dict, set::Dict, maps::Dict)
    println("  Calculating id0(yr,r,g=ele,s), regional intermediate demand")
    df, df_out = split_with(d[:id0], (g=set[:e],))

    df_inpshr = _disagg_energy_inpshr!(d, set, maps)
    df = combine_over(dropzero(d[:ed0] * df_inpshr), :sec; digits=false)

    d[:id0] = vcat(df_out, df)
    return d[:id0]
end


"""
`x0(yr,r,g=ele)`, foreign exports
"""
function _disagg_energy_x0!(d::Dict)
    println("  Calculating x0(yr,r,g=ele), foreign exports")
    df, df_out = split_with(d[:x0], (g="ele",))

    df = filter_with(d[:trdele], (t="exports",); drop=true)

    d[:x0] = vcat(df_out, df)
    return d[:x0]
end


"""
`m0(yr,r,g=ele)`, foreign imports
"""
function _disagg_energy_m0!(d::Dict)
    println("  Calculating m0(yr,r,g=ele), foreign imports")
    df, df_out = split_with(d[:m0], (g="ele",))

    df = filter_with(d[:trdele], (t="imports",); drop=true)

    d[:m0] = vcat(df_out, df)
    return d[:m0]
end


"""
"""
function _disagg_energy_zero_prod!(d::Dict)
    idxzero = _disagg_energy_zero_prod(d)
    [d[k] = _disagg_energy_zero_prod(d[k], idxzero) for k in [:ld0,:kd0,:ty0,:id0,:s0,:xd0,:xn0,:x0,:rx0]]
    return d
end

function _disagg_energy_zero_prod(d::Dict)
    idx_zero = fill_zero(combine_over(filter_with(d[:ys0], (s="ele",)), :g))
    return getzero(idx_zero)
end

function _disagg_energy_zero_prod(df::DataFrame, idxzero::DataFrame)
    idxon = find_sector(idxzero)
    if !(idxon in propertynames(df))
        idxzero = edit_with(idxzero, Rename(idxon, find_sector(df)))
    end
    return filter_with(df, Not(idxzero))
end


"""
"""
function drop_small!(d, set; digits=5)
    variables = setdiff(keys(d), list("taxes"))

    [d[k] = drop_small(d[k]; digits=digits, key=k) for k in variables
        if typeof(d[k])==DataFrame]
    return d
end


"""
"""
function drop_small(df; digits=5, key=missing)
    sector = ensurearray(find_sector(df))
    
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



function operation_propertynames(df::DataFrame)
    idx = findindex(df)
    return [setdiff(idx[.!occursin.(:_, idx)], [:operation]); :value]
end

operation_output(df::DataFrame) = select(df, operation_propertynames(df))
operation_output(df::DataFrame, x::InvertedIndex) = select(operation_output(df), x)

operation_output!(df::DataFrame) = select!(df, operation_propertynames(df))
operation_output!(df::DataFrame, x::InvertedIndex) = select!(operation_output!(df), x)