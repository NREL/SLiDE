"""
"""
function _module_convfac(d::Dict)
    return filter_with(d[:seds], (src="cru", sec="supply", units=BTU_PER_BARREL); drop=true)
end


"""
"""
function _module_cprice(d::Dict, maps::Dict)
    id = [:cru,:convfac]
    df = convertjoin(d[:crude_oil], _module_convfac(d); id=id)
    return operate_with(df, maps[:operate]; id=id)
end


"""
"""
function _module_prodbtu(d::Dict)
    return filter_with(d[:seds], (src=["cru","gas"], sec="supply", units=BTU); drop=true)
end


"""
"""
function _bluenote_pedef(d::Dict, set::Dict)
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

    d[:pedef] = vcat([_bluenote_pedef(df, df_split) for df_split in values(splitter)]...)
    return d[:pedef]
end


function _bluenote_pedef(df::DataFrame, df_split::DataFrame)
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
    idx_r, idx_sec = index_with(df_sec, DataFrame(value=0.))

    col = intersect(col, propertynames(df_sec))
    select!(df_sec, col)

    if !isempty(idx_r)
        df_r = combine_over(df_sec * q_sec, :r) / combine_over(q_sec, :r)
        df_r = indexjoin(idx_r, df_r; kind=:inner)

        df_sec = [df_sec; df_r[:,col]]
    end 

    return df_sec
end