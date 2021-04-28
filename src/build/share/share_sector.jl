"""
    share_sector!()
# Arguments
- `d::Dict` of model parameters
"""
function share_sector!(d, set; kwargs...)
    weighting, mapping, lst = share_sector(set[:sector]; kwargs...)
    
    push!(d, :sector=>weighting.data)
    set_sector!(set, lst)
    
    return weighting
end


"""
    share_sector(set::Dict)

# Returns
- `weighting::Weighting`
- `mapping::Mapping`
"""
function share_sector( ; path::String=SCALE_BLUENOTE_IO)
    @info("Sharing sector using mapping in $path.")

    sector_level = :detail
    dfmap = read_file(path)[:,1:2]

    # Get the detail-level info so we can disaggregate.
    set_det = SLiDE.read_set("io"; sector_level=sector_level)
    det = SLiDE.read_input!(Dataset(""; step="partition", sector_level=sector_level))

    df = SLiDE._partition_y0!(det, set_det; sector_level=sector_level)
    
    # Initialize scaling information.
    return SLiDE.share_with(Weighting(df), Mapping(dfmap))
end


function share_sector(lst::AbstractArray; kwargs...)
    weighting, mapping = share_sector( ; kwargs...)
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