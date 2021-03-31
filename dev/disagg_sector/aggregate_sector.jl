# # rename for action wordds:
#     _share_sector_aggregate
#     _scale_sector_aggregate

# By default, share to all sectors. This always happens.
# OPTIONAL: Give *something* to indicate whether to combine levels. AND HOW.
# This will happen after the sharing has been completed. Analagous process can be applied
# to regions.
# ACTUALLY, here we might want to do it outside of this:
#   Do you want to select sectors?
#   Check: are these mixed-level?
#   If so, then share.
# 
# Sharing:
# 1. Default -- do all Sharing
# 2. Custom sharing.
#       want to make these one function...
#       EXCEPT, it's really only ever called if someone DOES specify a place to look.
#       So there could be an "all" option -- this goes to share_sector()
#       Let's do a "select", maybe?
# 1. Read something that lists what sectors are included -- maybe dataframe with mapping
#       info -- this will be the default.
#       - path with optional column name (for dataframe). if none is given, read first column.
#       - list
#       - should work for any dataframe
# 2. Save this in set input (sector).
#       - FOR EEM, this is where we define where the (default) path comes from.

function share_sector!(dataset::String, d::Dict, set::Dict)
    !haskey(set,:sector) && (set[:sector] = set[:summary])

    if !isempty(intersect(set[:sector], set[:detail]))
        # !!!! future, check if we did the save-build thing and read sectors if we did.

        # Read the set and BEA input, this time for the DETAILED level, and partition.
        [set[k] = set[:detail] for k in [:g,:s]]

        det = merge(
            read_from(joinpath("src","build","readfiles","input","detail.yml")),
            Dict(:sector=>:detail),
        )

        # !!!! Need to make sure this doesn't try to read summary-level partition
        # info if it is already saved.
        det = partition(SLiDE._development(dataset), det, set)

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
    sector = SLiDE._find_sector(df)
    
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
        set[:sector] = unique([val; df_det[:,:aggr]])
        
        df_sum = fill_with((
            yr=unique(df[:,:yr]),
            aggr=intersect(set[:summary], set[:sector])
        ), 1.0)
        df_sum = df_sum - combine_over(df_det, :disagg)
        df_sum[:,:disagg] .= df_sum[:,:aggr]

        @info("Sectoral disaggregation required.")
    end

    df = SLiDE.sort_unique(vcat(df_det, df_sum))

    return (df, set)
end