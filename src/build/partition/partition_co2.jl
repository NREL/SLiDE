function partition_co2!(dataset::Dataset, d::Dict, set::Dict, maps::Dict)
    step = "co2"
    d_read = SLiDE.read_build(SLiDE.set!(dataset; step=step))

    if dataset.step=="input"
        print_status(set!(dataset; step=step))

        SLiDE.partition_co2!(d, set, maps)
        SLiDE.write_build!(SLiDE.set!(dataset; step=step), copy(d))
    else
        merge!(d, d_read)
    end

    return d
end


function partition_co2!(d::Dict, set::Dict, maps::Dict)
    _partition_co2emiss!(d, maps)
    _share_co2emiss!(d, set, maps)
    _partition_secco2!(d, set, maps)
    _partition_resco2!(d)
    return d
end


"""
```math
\\bar{co_2}_{yr,r,src,sec} \\text{ [million metric tons of CO2]}
= 10^{-3} \\cdot
\\dfrac{\\bar{eq}_{yr,r,src,sec} \\text{ [trillion btu]}}
      {{co_2/btu}_{src} \\text{ [kg CO2/million btu]}}
```
"""
function _partition_co2emiss!(d::Dict, maps::Dict)
    if !haskey(d, :co2emiss)
        df_btu = filter_with(d[:eq0], (units=BTU,))

        df = operate_over(df_btu, maps[:co2perbtu];
            id=[:btu,:co2_per_btu]=>:co2,
            units=maps[:operate],
        )
        df[!,:value] .= df[:,:factor] .* df[:,:co2_per_btu] .* df[:,:btu]

        d[:co2emiss] = SLiDE.operation_output(df)
    end

    return d[:co2emiss]
end


"""
"""
function _share_co2emiss!(d::Dict, set::Dict, maps::Dict)
    if !haskey(d, :shrco2)
        x = ["ind","com","trn"]
        idx = filter_with(maps[:demand], (sec=x,))

        df = filter_with(copy(d[:id0]), (g=set[:e],))
        df_sec = indexjoin(df, idx; kind=:inner)

        d[:shrco2] = df_sec / transform_over(df_sec, :s; digits=false)
    end

    return d[:shrco2]
end


function _partition_secco2!(d::Dict, set::Dict, maps::Dict)
    col = [:r,:g,:s,:units,:value]
    xrename = Rename(:src,:g)
    xsec = [Map(maps[:demand],[:sec],[:s],[:sec],[:s],:inner), Deselect([:sec],"==")]

    df_co2emiss = edit_with(_partition_co2emiss!(d, maps), xrename)
    df_shrsec = _share_co2emiss!(d, set, maps)

    df = operate_over(df_shrsec, df_co2emiss; id=[:factor,:co2]=>:value, fillmissing=0.0)
    df[!,:value] .= df[:,:factor] .* df[:,:co2]
    df[!,:units] .= df[:,:units_co2]

    df = combine_over(df, :sec; digits=false)

    # Use un-shared values for s=(ele,oil).
    idxadj = vcat(DataFrame(g=set[:e], sec="ele"), DataFrame(g="cru", sec="ref"))
    df_ele_oil = edit_with(filter_with(df_co2emiss, idxadj), xsec)

    d[:secco2] = dropzero(vcat(df_ele_oil, df; cols=:intersect))
    d[:secco2] = filter_with(d[:secco2], Not(_no_co2emiss!(d)))

    return d[:secco2]
end


function _partition_resco2!(d::Dict)
    d[:resco2] = edit_with(filter_with(d[:co2emiss], (sec="res",); drop=true), Rename(:src,:g))
    return d[:resco2]
end


function _no_co2emiss!(d::Dict)
    idx = findindex(d[:id0])
    df = filter_with(d[:secco2], Not(d[:id0][:,idx]))
    d[:nomatch] = select(df, idx)
end