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
    SLiDE._partition_co2emiss!(d, maps)
    SLiDE._share_co2emiss!(d, set, maps)
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

        df = filter_with(copy(d[:id0]), (g=set[:e],))
        dfmap = filter_with(maps[:demand], (sec=x,))

        d[:shrco2] = SLiDE.share_with(df, Mapping(dfmap))
    end
    return d[:shrco2]
end


function _partition_secco2!(d::Dict, set::Dict, maps::Dict)
    df_co2emiss = edit_with(SLiDE._partition_co2emiss!(d, maps), Rename(:src,:g))

    # (1) Use share for s = (ind,com,trn)
    df_shrsec = SLiDE._share_co2emiss!(d, set, maps)

    df = SLiDE.operate_over(df_shrsec, df_co2emiss; id=[:factor,:co2]=>:value, fillmissing=0.0)
    df[!,:value] .= df[:,:factor] .* df[:,:co2]
    df[!,:units] .= df[:,:units_co2]

    df = combine_over(df, :sec; digits=false)

    # (2) Use un-shared values for s=(ele,oil).
    idx = vcat(
        DataFrame(g=set[:e], sec="ele"),
        DataFrame(g="cru", sec="ref"),
    )
    x = [Map(maps[:demand],[:sec],[:s],[:sec],[:s],:inner), Deselect([:sec],"==")]
    df_ele_oil = edit_with(filter_with(df_co2emiss, idx), x)

    # (3) Combine.
    d[:secco2] = dropzero(vcat(df_ele_oil, df; cols=:intersect))
    d[:secco2] = filter_with(d[:secco2], Not(SLiDE._no_co2emiss!(d)))

    SLiDE.print_status(:secco2, d)
    return d[:secco2]
end


function _partition_resco2!(d::Dict)
    d[:resco2] = edit_with(filter_with(d[:co2emiss], (sec="res",); drop=true), Rename(:src,:g))
    print_status(:resco2, d)
    return d[:resco2]
end


function _no_co2emiss!(d::Dict)
    idx = findindex(d[:id0])
    df = filter_with(d[:secco2], Not(d[:id0][:,idx]))
    d[:nomatch] = select(df, idx)
end