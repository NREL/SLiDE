"""
    share_rpc!(d::Dict, set::Dict)
"""
function share_rpc!(d::Dict, set::Dict)
    println("  Calculating rpc(r,g), regional purchase coefficient")
    !(:ng   in collect(keys(d))) && _set_ng!(d, set)
    !(:d0   in collect(keys(d))) && _share_d0!(d, set)
    !(:mrt0 in collect(keys(d))) && _share_mrt0!(d)
    !(:xn0  in collect(keys(d))) && _share_xn0!(d, set)
    !(:mng  in collect(keys(d))) && _share_mn0!(d, set)

    df = dropnan(d[:d0] / (d[:d0] + d[:mn0]))

    df = edit_with(df, Drop(:g,"uti","=="))
    df_uti = fill_with((r = set[:r], g = "uti"), 0.9)

    d[:rpc] = sort([dropnan(df); df_uti])
end


"`ng`: Sectors not included in the CFS."
function _set_ng!(d::Dict, set::Dict)
    df = combine_over(copy(d[:cfs]), [:orig, :dest, :sg])
    df = fill_zero((g = set[:g],), df)
    df[!,:value] .= df[:,:value] .== 0.0
    d[:ng] = df
    set[:ng] = df[df[:,:value],:g]
end


"`d0`: Local supply-demand. Trade that remains within the same region."
function _share_d0!(d::Dict, set::Dict)
    println("\td0(r,g), national exports")

    df = copy(d[:cfs])
    df = df[df[:,:orig] .== df[:,:dest],:]
    df = edit_with(df, [Rename(:orig,:r), Drop(:dest,"all","==")])
    cols = propertynames(df)

    d[:d0] = _avg_ng(df, d, set)[:,cols]
end

"`mrt0(r,g)`: Interstate trade (CFS)"
function _share_mrt0!(d::Dict)
    df = copy(d[:cfs])
    df = df[df[:,:orig] .!= df[:,:dest],:]
    d[:mrt0] = df
end

"`mn0(r,g)`: National demand (CFS)"
function _share_mn0!(d::Dict, set::Dict)
    println("\tmn0(r,g), national demand")
    :mrt0 in collect(keys(d)) && _share_mrt0!(d)

    df = copy(d[:mrt0])
    df = edit_with(combine_over(df, :orig), Rename(:dest,:r))
    cols = propertynames(df)

    d[:mn0] = _avg_ng(df, d, set)[:,cols]
end

"`xn0(r,g)`: National exports (CFS)"
function _share_xn0!(d::Dict, set::Dict)
    println("\txn0(r,g), national exports")
    !(:mrt0 in collect(keys(d))) && _share_mrt0!(d)

    df = copy(d[:mrt0])
    df = edit_with(combine_over(df, :dest), Rename(:orig,:r))
    cols = propertynames(df)

    d[:xn0] = _avg_ng(df, d, set)[:,cols]
end

" !!!! "
function _avg_ng(df::DataFrame, d::Dict, set::Dict)
    !(:ng in collect(keys(d))) && _set_ng!(d, set)

    df = copy(df)
    not_ng = edit_with(d[:ng], Replace(:value,Bool,Not))
    df = fill_zero((g = set[:g], r = set[:r]), df)

    df_ng = transform_over(df, :g) / transform_over(not_ng, :g)
    
    df = indexjoin(df, df_ng, copy(d[:ng]); valnames = [:value, :value_ng, :ng])

    df[!,:ng] .= convert_type.(Bool, df[:,:ng])

    df[!,:value_calc] .= df[:,:value]
    df[df[:,:ng], :value] .= df[df[:,:ng], :value_ng]
    return df
end