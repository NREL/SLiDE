using CSV
using DataFrames
using DelimitedFiles
using YAML
using Query

using SLiDE

"""
    share_rpc!(d::Dict, set::Dict)
"""
function share_rpc!(d::Dict, set::Dict)
    println("  Calculating regional purchase coefficient")
    cols = [:r,:g,:value]
    !(:ng   in collect(keys(d))) && _share_ng!(d, set)
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
function _share_ng!(d::Dict, set::Dict)
    df = combine_over(copy(d[:cfs]), [:orig_state, :dest_state, :sg])
    df = fill_zero((g = set[:g],), df)
    df[!,:value] .= df[:,:value] .== 0.0
    d[:ng] = df
    set[:ng] = df[df[:,:value],:g]
end

"`d0`: Local supply-demand. Trade that remains within the same region."
function _share_d0!(d::Dict, set::Dict)
    cols = [:r,:g,:value]
    df = copy(d[:cfs])
    df = df[df[:,:orig_state] .== df[:,:dest_state],:]
    df = sort(edit_with(df, Rename(:orig_state,:r))[:,cols])
    d[:d0_temp] = copy(df)
    d[:d0] = _avg_ng(df, d, set)[:,cols]
end

"`mrt0`: Interstate trade (CFS)"
function _share_mrt0!(d::Dict)
    cols = [:r,:g,:value]
    df = copy(d[:cfs])
    df = df[df[:,:orig_state] .!= df[:,:dest_state],:]
    d[:mrt0] = df
end

"`mn0`: National demand (CFS)"
function _share_mn0!(d::Dict, set::Dict)
    :mrt0 in collect(keys(d)) && _share_mrt0!(d)

    cols = [:r,:g,:value]
    df = copy(d[:mrt0])
    df = edit_with(combine_over(df, :orig_state), Rename(:dest_state,:r))
    d[:mn0_temp] = copy(df)

    # Average and stuff.
    d[:mn0] = _avg_ng(df, d, set)[:,cols]
end

"`xn0`: National exports (CFS)"
function _share_xn0!(d::Dict, set::Dict)
    !(:mrt0 in collect(keys(d))) && _share_mrt0!(d)

    cols = [:r,:g,:value]
    df = copy(d[:mrt0])
    df = edit_with(combine_over(df, :dest_state), Rename(:orig_state,:r))
    d[:xn0_temp] = copy(df)

    d[:xn0] = _avg_ng(df, d, set)[:,cols]
end

" !!!! "
function _avg_ng(df::DataFrame, d::Dict, set::Dict)
    !(:ng in collect(keys(d))) && _share_ng!(d, set)

    df = copy(df)
    not_ng = edit_with(d[:ng], Replace(:value,Bool,Not))
    df = fill_zero((g = set[:g], r = set[:r]), df)

    df_ng = transform_over(df, :g) / transform_over(not_ng, :g)
    
    df = SLiDE._join_to_operate(df, df_ng, copy(d[:ng]))
    df = edit_with(df, Rename.([:x1,:x2,:x3], [:value, :value_ng, :ng]))
    df[!,:ng] .= convert_type.(Bool, df[:,:ng])

    df[!,:value_calc] .= df[:,:value]
    df[df[:,:ng], :value] .= df[df[:,:ng], :value_ng]
    return df
end