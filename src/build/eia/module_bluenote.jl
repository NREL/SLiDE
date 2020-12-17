"""
"""
function _module_convfac(d::Dict)
    return filter_with(d[:seds], (src="cru", sec="supply", units=BTU_PER_BARREL); drop=:sec)
end


"""
"""
function _module_cprice(d::Dict, maps::Dict)
    id = [:cru,:convfac]
    df = convertjoin(d[:crude_oil], _module_convfac(d); id=id)
    d[:cprice] = operate_with(df, maps[:operate]; id=id)
    return d[:cprice]
end


"""
"""
function _module_prodbtu(d::Dict, set::Dict)
    d[:prodbtu] = filter_with(d[:seds], (src=set[:as], sec="supply", units=BTU); drop=:sec)
    return d[:prodbtu]
end


"""
"""
function _module_pedef!(d::Dict, set::Dict)
    df = copy(d[:energy])
    
    splitter = Dict(
        :ff => DataFrame(permute((
            src = set[:ff],
            sec = set[:demsec],
            pq = ["p","q"], # must include to act as key when splitting.
        ))),
        :ele => DataFrame(permute((
            src = "ele",
            sec = set[:demsec],
            pq = ["p","q"], # must include to act as key when splitting.
        ))),
    )

    d[:pedef] = vcat([_module_pedef(df, df_split) for df_split in values(splitter)]...)
    return d[:pedef]
end


function _module_pedef(df::DataFrame, df_split::DataFrame)
    # !!!! figure out the units situation when joining to make this one function.
    # This wouldn't be such an issue if we ignored the units columns,
    # but they're nice to keep track of for now.
    col = propertynames(df)

    # df_split = DataFrame(permute((
    #     src = set[:e],
    #     sec = set[:demsec],
    #     pq = ["p","q"], # must include to act as key when splitting.
    # )))

    df, df_out, df_split = _split_with(df, df_split, :pq)
    idx = findindex(df)

    q_sec = combine_over(df[:,[idx;:q]], :sec)
    df_sec = combine_over(df[:,[idx;:p]] * df[:,[idx;:q]], :sec) / q_sec

    df_sec[!,:units] .= df_sec[:,:p_units]

    # For missing or NaN results, replace with the average.
    idx_r, idx_sec = index_with(fill_zero(df_sec), DataFrame(value=0.))

    col = intersect(col, propertynames(df_sec))
    select!(df_sec, col)

    if !isempty(idx_r)
        df_r = combine_over(df_sec * q_sec, :r) / combine_over(q_sec, :r)
        df_r = indexjoin(idx_r, df_r; kind=:inner)

        df_sec = [df_sec; df_r[:,col]]
    end 

    return df_sec
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

    df = indexjoin(df_p, df_pedef; id=[:p,:pedef], fillmissing=false)
    ii = .!ismissing.(df[:,:p])

    df[!,:value] .= df[:,:pedef]
    df[ii,:value] .= df[ii,:p]

    # Use annual EIA data for crude oil averages.
    df_cprice = _module_cprice(d, maps)
    df_r = combine_over(df_cprice, :r; fun=Statistics.mean)

    # !!!! simplify this with index_with.
    df_q = filter_with(df_energy, (src="cru", pq="q"); drop=:pq)
    df_q[!,:value] .= max.(df_q[:,:value], 0)
    dropzero!(df_q)

    df_idx = indexjoin(df_q, crossjoin(df_cprice,df_demsec);
        id=[:q,:cprice], indicator=true, skipindex=:units)
    ii = .!df_idx[:,:cprice] .* df_idx[:,:q];

    idx_cprice = df_idx[.!ii,idx[1:end-1]];
    idx_r = df_idx[ii,idx[1:end-1]];

    df_cprice = indexjoin(idx_cprice, df_cprice; kind=:left)
    df_r = indexjoin(idx_r, df_r; kind=:left)

    df_cru = [df_cprice; df_r]

    d[:pe0] = [df[:,col]; df_cru[:,col]]

    return d[:pe0]
end


"""
"""
function _module_ps0!(d::Dict)
    df = combine_over(d[:pe0], [:r,:sec]; fun=Statistics.minimum)

    df_split = DataFrame(src=["cru","oil"])
    df, df_out, df_split = _split_with(df, df_split, [:src])

    df[!,:cru] .= df[:,:oil]/2

    d[:ps0] = _merge_with(df, df_out, df_split)
    return d[:ps0]
end


"""
"""
function _module_prodval!(d::Dict, set::Dict, maps::Dict)
    id = [:ps0,:prodbtu]
    df_ps0 = filter_with(d[:ps0], (src=set[:as],))
    df = convertjoin(df_ps0, d[:prodbtu]; id=id)
    d[:prodval] = operate_with(df, maps[:operate]; id=id)
    return d[:prodval]
end


"""
"""
function _module_shrgas!(d::Dict, set::Dict)
    df = copy(d[:prodval])
    df = df / transform_over(df, :src)

    x = (yr=set[:yr], r=set[:r], src=set[:as])
    idx_r, idx_shr = index_with(fill_zero(df; with=x), DataFrame(value=0.0))

    df_r = combine_over(df, :r; fun=Statistics.mean)
    df_r = indexjoin(idx_r, df_r)
    # !!!! ys0 condition

    df_gas = vcat(df, df_r)
    d[:shrgas] = df_gas / transform_over(df_gas, :src)
    return d[:shrgas]
end


"""
"""
function _module_netgen!(d::Dict)
    id = [:ps0,:netgen]
    df_ps0 = filter_with(d[:ps0], (src="ele",))
    df_netgen = filter_with(d[:seds], (sec="netgen", units=KWH); drop=true)
    df = convertjoin(df_ps0, df_netgen; id=id)
    df = operate_with(df, maps[:operate]; id=id)
    d[:netgen] = edit_with(df, Add(:dataset, "seds"))
    return d[:netgen]
end


"""
"""
function _module_eq0!(d::Dict, set::Dict)
    df = filter_with(d[:energy], (src=set[:e], sec=set[:demsec], pq="q"); drop=true)
    df[!,:value] = max.(0, df[:,:value])
    d[:eq0] = df
    return d[:eq0]
end


"""
"""
function _module_ed0!(d::Dict, maps::Dict)
    id = [:pe0,:eq0]
    df = convertjoin(d[:pe0], d[:eq0]; id=id)
    df = operate_with(df, maps[:operate]; id=id)
    d[:ed0] = df
    return d[:ed0]
end