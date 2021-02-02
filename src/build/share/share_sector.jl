function share_sector!(dataset::String, d::Dict, set::Dict)
    # If no scheme is specified, sha
    !haskey(set,:sector) && (set[:sector] = set[:detail])

    if !isempty(intersect(set[:sector], set[:detail]))
        # Read the set and BEA input, this time for the DETAILED level, and partition.
        # _set_sector!(set, set[:detail])
        set_det = _set_sector!(copy(set), set[:detail])

        det = merge(
            read_from(joinpath("src","build","readfiles","input","detail.yml")),
            Dict(:sector=>:detail),
        )
        
        # !!!! Need to make sure this doesn't try to read summary-level partition
        # info if it is already saved.
        det = partition(_development(dataset), det, set_det)

        df = _share_sector(det[:y0])
        (d[:sector], set) = _combine_sector_levels!(df, set)
    # else
        # what if there's no detailed info?? Just do some mapping.
    end
    
    return d, set
end


"""
"""
function _share_sector(df::DataFrame)
    f_map = joinpath("scale","sector","bluenote.csv")
    (from,to) = (:detail,:summary)
    sector = _find_sector(df)
    
    df = edit_with(df, [
        Rename.(sector, from);
        Map(f_map,[from],[to],[from],[to],:left);
        Order([:yr,to,from,:value], [Int,String,String,Float64]);
    ])

    df = df / combine_over(df,from)
    return df
end


"""
"""
function _combine_sector_levels!(df::DataFrame, set::Dict)
    # !!!! later -- will make general to work for regions.
    (var,val) = (:sector, set[:sector])
    d = Dict()
    
    df_det = edit_with(filter_with(df, (detail=val,)), [
        Rename(:detail,:disagg),
        Rename(:summary,:aggr),
    ])

    # !!!! If detail is empty, should return something saying that we don't need to continue
    # with the sectoral disaggregation process.
    if isempty(df_det)
        df_sum = fill_with((yr=unique(df[:,:yr]), sector=set[:sector]), 1.0)
    else
        # If detail shares are represented, initialize summary shares to one for all summary
        # shares included in the mapping DataFrame (which should be all 73 summary shares).
        # We need to start with all of them present in case there are some detail shares
        # present for which no summary data is requested.
        _set_sector!(set, unique([val; df_det[:,:aggr]]))
        
        df_sum = fill_with((
            yr=unique(df[:,:yr]),
            aggr=intersect(set[:summary], set[:sector])
        ), 1.0)
        df_sum = df_sum - combine_over(df_det, :disagg)
        df_sum[:,:disagg] .= df_sum[:,:aggr]

        @info("Sectoral disaggregation required.")
    end

    df = sort_unique(vcat(df_det, df_sum))

    return (df, set)
end


function _set_sector!(set::Dict, x::AbstractArray)
    [set[k] = x for k in [:s,:g,:sector]]
    return set
end