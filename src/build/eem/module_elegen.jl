function module_elegen!(d::Dict, maps::Dict)
    id = [:elegen,:heatrate]

    df = indexjoin(d[:seds], maps[:elegen]; kind=:inner)
    df = convertjoin(df, d[:heatrate]; id=id)
    df = operate_with_2(df, maps[:operate]; id=id)
    d[:elegen] = edit_with(df, Deselect([:sec],"=="))
    return d[:elegen]
end