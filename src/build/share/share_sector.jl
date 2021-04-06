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
    set_det = SLiDE.read_set("io"; sector=:detail)
    det = SLiDE.read_input!(Dataset(""; step="partition", sector=:detail))

    df = SLiDE._partition_y0!(det, set_det)
    
    # Initialize scaling information.
    weighting, mapping = SLiDE.share_with(Weighting(df), Mapping(dfmap))
    # weighting = Weighting(df)
    # mapping = Mapping(dfmap)
    
    # SLiDE.set_scheme!(weighting, mapping)
    # SLiDE.share_with!(weighting, mapping)
    
    weighting.data = SLiDE.map_year(weighting.data, set[:yr])

    return weighting, mapping
end


function share_sector(set::Dict, lst::AbstractArray;
    path::String=joinpath(SLIDE_DIR,"data","coremaps","scale","sector","bluenote.csv"),
)
    weighting, mapping = share_sector(set; path=path)
    filter_with!(weighting, mapping, lst)
    return weighting, mapping, lst
end


"""
    share_with(df::DataFrame, x::Mapping)
"""
function share_with(weighting::Weighting, mapping::Mapping)    
    SLiDE.set_scheme!(weighting, mapping)
    SLiDE.share_with!(weighting, mapping)
    return weighting, mapping
end


function share_with(df::DataFrame, x::Mapping)
    df = edit_with(df, [
        Rename(x.on, x.from);
        Map(x.data, [x.from;], [x.to;], [x.from;], [x.to;], :inner);
    ])

    if x.direction==:aggregate
        agg, dis = map_direction(x)
        df = df / combine_over(df, dis)
    end
    return df
end


"""
    share_with!(weighting::Weighting, mapping::Mapping)
Returns `weighting` with `weighting.data::DataFrame` shared using [`SLiDE.share_with`](@ref)
"""
function share_with!(weighting::Weighting, mapping::Mapping)
    weighting.data = select(
        share_with(weighting.data, mapping),
        [weighting.constant; weighting.from; weighting.to; findvalue(weighting.data)],
    )
    return weighting
end