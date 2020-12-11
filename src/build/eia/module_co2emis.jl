function module_co2emis!(d::Dict, set::Dict, maps::Dict)
    set[:co2dim] = unique(d[:emissions][:,:src])

    id=[:btu,:co2perbtu]

    df = filter_with(d[:energy], (src=set[:e], sec=set[:sec], units=BTU))
    df = convertjoin(df, maps[:co2perbtu]; id=id)
    df = operate_with(df, maps[:operate]; id=id)
    idx = setdiff([findindex(df);:dataset],[:pq])

    d[:co2emis] = vcat(
        edit_with(df, Add(:dataset,"seds"))[:,[idx;:value]],
        edit_with(d[:emissions], [
            Add(:sec,"total"),
            Add(:dataset,"epa"),
        ])[:,[idx;:value]],
    )

    return d[:co2emis]
end