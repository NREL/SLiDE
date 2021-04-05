"""
    share_sector!()
"""
function share_sector!(d, set;
    path::String=joinpath(SLIDE_DIR,"data","coremaps","scale","sector","bluenote.csv"),
)
    @info("Sharing sector.")
    
    # Need to make sure set[:sector] !== set[:summary]
    weighting, mapping, lst = share_sector(set, set[:sector]; path=path)
    d[:sector] = weighting

    SLiDE.set_sector!(set, lst)
    return d[:sector]
end


"""
    share_sector(set::Dict)
"""
function share_sector(set::Dict;
    path::String=joinpath(SLIDE_DIR,"data","coremaps","scale","sector","bluenote.csv"),
)
    dfmap = read_file(path)[:,1:2]

    # Get the detail-level info so we can disaggregate.
    set_det = SLiDE.set_sector!(copy(set), set[:detail])
    det = merge(
        read_from(joinpath("src","build","readfiles","input","detail.yml")),
        Dict(:sector=>:detail),
    )
    SLiDE._partition_y0!(det, set_det)
    df = select(det[:y0], Not(:units))
    
    # Initialize scaling information.
    weighting = Weighting(df)
    mapping = Mapping(dfmap)
    
    set_scheme!(weighting, mapping)
    share_with!(weighting, mapping)

    return weighting, mapping
end


function share_sector(set::Dict, lst::AbstractArray;
    path::String=joinpath(SLIDE_DIR,"data","coremaps","scale","sector","bluenote.csv"),
)
    weighting, mapping = share_sector(set; path=path)
    filter_with!(weighting, mapping, lst)
    return weighting, mapping, lst
end