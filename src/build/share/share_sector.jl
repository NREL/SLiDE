"""
    share_sector!(d::Dict, set::Dict; kwargs...)
This function returns a sectoral disaggregation weighting factor, updates the sectoral
set list(s) stored in `set`, and adds the sectoral weighting DataFrame to `d`.

# Arguments
- `d::Dict` of model parameters
- `set::Dict` of Arrays describing parameter indices (years, regions, goods, sectors, etc.)

# Returns
- `weighting::Weighting`
"""
function share_sector!(d, set; kwargs...)
    weighting, mapping, lst = SLiDE.share_sector(set[:sector]; kwargs...)
    
    push!(d, :sector=>weighting.data)
    set_sector!(set, lst)
    reverse_scheme!(weighting)
    
    return weighting
end


"""
    share_sector(; kwargs...)
    share_sector(lst::AbstractArray; kwargs...)
This function returns a sectoral disaggregation weighting factor.

It first reads and partitions ([`partition`](@ref)) detail-level BEA data to calculate 
gross output, ``y_{yr,g}``, which is used to determine sectoral scaling for disaggregation.
409 detail-level codes are mapped to 73 summary-level codes using the
[blueNOTE sectoral scaling map](https://github.com/NREL/SLiDEData/blob/master/coremaps/scale/sector/bluenote.csv),
denoted here as ``map_{gg\\rightarrow g} = map_{ss\\rightarrow s}``, where
``gg``/``ss`` are summary-level goods/sectors and
``g``/``s`` are detail-level goods/sectors.

A sectoral disaggregation parameter ``\\tilde{\\delta}_{yr,gg \\rightarrow g}`` can be defined:

```math
\\tilde{\\delta}_{yr,gg \\rightarrow g} = \\dfrac
    {y_{yr,g} \\circ map_{gg\\rightarrow g}}
    {\\sum_{gg} y_{yr,g} \\circ map_{gg\\rightarrow g}}
```

This process follows two major steps:
1. Calculate ``\\tilde{\\delta}_{yr,gg \\rightarrow g}`` for *all* ``(gg,g)``, (summary, detail) pairs.
2. If an input argument is given, filter sectoral disaggregation weighting to include only the relevant sectors.

# Arguments
- `lst::AbstractArray` of sectors to include

# Returns
- `weighting::Weighting`
- `mapping::Mapping`
- `lst::AbstractArray` of sectors, updated in case any aggregate sectors were added
"""
function share_sector( ; path::String=SCALE_BLUENOTE_IO, kwargs...)
    println("Sharing sector using mapping in $path.")
    
    sector_level = :detail
    dfmap = read_file(path)[:,1:2]
    
    # Get the detail-level info so we can disaggregate.
    dataset = Dataset(""; step="bea", sector_level=sector_level)
    set_det = read_set("io"; sector_level=sector_level)
    det = read_input!(dataset)
    filter_with!(det, set_det, set!(dataset; step="bea"))

    df = SLiDE._partition_y0!(det, set_det; sector_level=sector_level, kwargs...)
    
    return share_with(Weighting(df), Mapping(dfmap))
end


function share_sector(lst::AbstractArray; kwargs...)
    weighting, mapping = share_sector( ; kwargs...)
    filter_for!(weighting, mapping, lst)
    return weighting, mapping, lst
end


"""
    share_with(df::DataFrame, x::Mapping)
"""
function share_with(weighting::Weighting, mapping::Mapping)    
    set_scheme!(weighting, mapping)
    share_with!(weighting, mapping)
    return weighting, mapping
end


function share_with(df::DataFrame, x::Mapping)
    !has_scheme(x) && SLiDE.set_scheme!(Weighting(df), x)

    df = edit_with(df, [
        Rename(x.on, x.from);
        Map(x.data, [x.from;], [x.to;], [x.from;], [x.to;], :inner);
    ])

    if x.direction==:aggregate
        agg, dis = SLiDE.map_direction(x)
        df = df / combine_over(df, dis)
    end
    return df
end


"""
    share_with!(weighting::Weighting, mapping::Mapping)
Returns `weighting` with `weighting.data::DataFrame` shared using [`SLiDE.share_with`](@ref)
"""
function share_with!(weighting::Weighting, mapping::Mapping)
    set_scheme!(weighting, mapping)

    weighting.data = select(
        share_with(weighting.data, mapping),
        [weighting.constant; weighting.from; weighting.to; findvalue(weighting.data)],
    )
    return weighting
end