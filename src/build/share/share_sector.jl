"""
    share_sector!(dataset::String, d::Dict, set::Dict; kwargs...)
This function adds sharing information for the sectoral disaggregation to `d[:sector]`.

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
1. [`SLiDE.share_sector`](@ref), which calculates ``\\tilde{\\delta}_{yr,gg \\rightarrow g}``
    for *all* ``(gg,g)``, (summary, detail) pairs.
2. [`SLiDE._combine_sector_levels`](@ref), which selects relevant summary- and detail-level
    goods/sectors defined in `set[:sector]` and defines how to share the
    aggregate (summary)-level goods/sectors into this composite disaggregate-level set.

# Arguments
- `dataset::String`: dataset identifier
- `d::Dict` of DataFrames containing regionally-disaggregated model parameters.
- `set::Dict` of Arrays describing region, sector, final demand, etc.
    This should inlude a set `set[:sector]` listing the summary- and detail-level blueNOTE
    codes of interest to include in `g`.

# Returns
- `d::Dict`: regionally-disaggregated model parameters, updated to include
    `d[:sector]` = ``\\tilde{\\delta}_{yr,gg \\rightarrow g}``.
- `set::Dict` of Arrays describing region, sector, final demand, etc.
"""
function share_sector!(dataset::String, d::Dict, set::Dict)
    # https://math.stackexchange.com/questions/932557/set-notation-and-mappings-question
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

        df = share_sector(det[:y0])
        (d[:sector], x) = _combine_sector_levels(df, set[:sector])

        _set_sector!(set, x)
    # else
        # what if there's no detailed info?? Just do some mapping.
    end
    
    return d, set
end


"""
    share_sector(df::DataFrame)
This function calculates and returns a sectoral disaggregation parameter for *all* ``(gg,g)``,
(summary, detail) pairs.

```math
\\tilde{\\delta}_{yr,gg \\rightarrow g} = \\dfrac
    {y_{yr,g} \\circ map_{gg\\rightarrow g}}
    {\\sum_{gg} y_{yr,g} \\circ map_{gg\\rightarrow g}}
```

# Example

Looking at a slice of the disaggregate-level ``y_{yr,g}`` parameter,

```jldoctest share_sector
julia> df = read_file(joinpath(SLIDE_DIR,"docs","src","assets","data","share_sector-y0_det.csv"))
6×3 DataFrame
│ Row │ yr    │ g       │ value   │
│     │ Int64 │ String  │ Float64 │
├─────┼───────┼─────────┼─────────┤
│ 1   │ 2007  │ ele_uti │ 292.105 │
│ 2   │ 2007  │ gas_uti │ 120.746 │
│ 3   │ 2007  │ wat_uti │ 10.331  │
│ 4   │ 2012  │ ele_uti │ 339.302 │
│ 5   │ 2012  │ gas_uti │ 78.708  │
│ 6   │ 2012  │ wat_uti │ 12.583  │

julia> df = SLiDE.share_sector(df)
6×4 DataFrame
│ Row │ yr     │ summary │ detail  │ value     │
│     │ Int64? │ String? │ String? │ Float64   │
├─────┼────────┼─────────┼─────────┼───────────┤
│ 1   │ 2007   │ uti     │ ele_uti │ 0.690259  │
│ 2   │ 2007   │ uti     │ gas_uti │ 0.285329  │
│ 3   │ 2007   │ uti     │ wat_uti │ 0.0244127 │
│ 4   │ 2012   │ uti     │ ele_uti │ 0.787988  │
│ 5   │ 2012   │ uti     │ gas_uti │ 0.18279   │
│ 6   │ 2012   │ uti     │ wat_uti │ 0.0292225 │
```

This ensures ``\\sum_{g}\\tilde{\\delta}_{yr,gg \\rightarrow g} = 1``.

```jldoctest share_sector
julia> combine_over(df, :detail)
2×3 DataFrame
│ Row │ yr     │ summary │ value   │
│     │ Int64? │ String? │ Float64 │
├─────┼────────┼─────────┼─────────┤
│ 1   │ 2007   │ uti     │ 1.0     │
│ 2   │ 2012   │ uti     │ 1.0     │
```
"""
function share_sector(df::DataFrame)
    (from,to) = (:detail,:summary)
    sector = _find_sector(df)
    
    f_map = joinpath(SLIDE_DIR,"data","coremaps","scale","sector","bluenote.csv")
    dfmap = read_file(f_map)

    df = edit_with(df, [
        Rename.(sector, from);
        Map(dfmap,[from],[to],[from],[to],:left);
        Order([:yr,to,from,:value], [Int,String,String,Float64]);
    ])

    df = df / combine_over(df,from)
    return df
end


"""
    _combine_sector_levels(df::DataFrame, x::AbstractArray; kwargs...)
Given a sharing DataFrame that includes level-mapping and a list of all parameters that
should be included at the disaggregate level, this function returns a complete mapping
DataFrame to scale between mixed levels.

# Arguments
- `df::DataFrame`: sharing DataFrame with columns mapped between levels.
- `x::AbstractArray`: composite of all levels to include on the disaggregate level.

# Keywords
- `scheme::Pair = :summary=>:detail`: columns in `df` to **dis**aggregate from ``\\rightarrow`` to.

# Returns
- `df::DataFrame`: complete mapping DataFrame to scale between mixed levels.
    The (aggregate-level, composite) columns are named `(aggr,disagg)` such that the sum over
    the composite column is one. 

# Example

Focusing on a slice of ``\\tilde{\\delta}_{yr,gg \\rightarrow g}``,

```jldoctest combine_sector_levels
julia> df = read_file(joinpath(SLIDE_DIR,"docs","src","assets","data","combine_sector_levels-sector_share.csv"))
8×4 DataFrame
│ Row │ yr    │ summary │ detail  │ value     │
│     │ Int64 │ String  │ String  │ Float64   │
├─────┼───────┼─────────┼─────────┼───────────┤
│ 1   │ 2012  │ oil     │ oil_oil │ 1.0       │
│ 2   │ 2012  │ pet     │ oth_pet │ 0.0299492 │
│ 3   │ 2012  │ pet     │ pav_pet │ 0.015931  │
│ 4   │ 2012  │ pet     │ ref_pet │ 0.941366  │
│ 5   │ 2012  │ pet     │ shn_pet │ 0.0127534 │
│ 6   │ 2012  │ uti     │ ele_uti │ 0.787988  │
│ 7   │ 2012  │ uti     │ gas_uti │ 0.18279   │
│ 8   │ 2012  │ uti     │ wat_uti │ 0.0292225 │

julia> x = ["oil","ref_pet","uti","ele_uti"];

julia> (df, x) = SLiDE._combine_sector_levels(df, x);

julia> df
5×4 DataFrame
│ Row │ yr    │ aggr   │ disagg  │ value     │
│     │ Int64 │ String │ String  │ Float64   │
├─────┼───────┼────────┼─────────┼───────────┤
│ 1   │ 2012  │ oil    │ oil     │ 1.0       │
│ 2   │ 2012  │ pet    │ pet     │ 0.0586336 │
│ 3   │ 2012  │ pet    │ ref_pet │ 0.941366  │
│ 4   │ 2012  │ uti    │ ele_uti │ 0.787988  │
│ 5   │ 2012  │ uti    │ uti     │ 0.212012  │
```

In the case that `set[:sector]`(``g``) includes a disaggregate-level sector without its
corresponding aggregate-level code (e.g. `ref_pet` without `pet`, as is the case in this
example), the aggregate-level code will be added.

```jldoctest combine_sector_levels
julia> x
5-element Array{String,1}:
 "oil"
 "pet"
 "ref_pet"
 "ele_uti"
 "uti"
```

This ensures that ``\\sum_{g}\\tilde{\\delta}_{yr,gg \\rightarrow g} = 1``.

```jldoctest combine_sector_levels
julia> combine_over(df, :disagg)
3×3 DataFrame
│ Row │ yr    │ aggr   │ value   │
│     │ Int64 │ String │ Float64 │
├─────┼───────┼────────┼─────────┤
│ 1   │ 2012  │ oil    │ 1.0     │
│ 2   │ 2012  │ pet    │ 1.0     │
│ 3   │ 2012  │ uti    │ 1.0     │
```
"""
function _combine_sector_levels(df::DataFrame, x::AbstractArray; scheme=:detail=>:summary)
    # !!!! later -- will make general to work for regions.
    (from, to) = (scheme[1], scheme[2])
    
    df = edit_with(df, [Rename(from,:disagg), Rename(to,:aggr)])
    df_dis = filter_with(df, (disagg=x,))

    # !!!! If detail is empty, should return something saying that we don't need to continue
    # with the sectoral disaggregation process.
    # !!!! Make general enough in case it's not just year we need to add.
    if isempty(df_dis)
        df_agg = fill_with((yr=unique(df[:,:yr]), sector=x), 1.0)
    else
        # If detail shares are represented, initialize summary shares to one for all summary
        # shares included in the mapping DataFrame (which should be all 73 summary shares).
        # We need to start with all of them present in case there are some detail shares
        # present for which no summary data is requested.
        df_agg = fill_with((
            yr=unique(df[:,:yr]),
            aggr=union(unique(df[:,:aggr]), unique(df_dis[:,:aggr]))
        ), 1.0)

        df_agg = df_agg - combine_over(df_dis, :disagg)
        df_agg[:,:disagg] .= df_agg[:,:aggr]
    end
    
    df = dropmissing(sort_unique(vcat(df_dis, df_agg)))

    return (df, unique(df[:,:disagg]))
end


function _set_sector!(set::Dict, x::AbstractArray)
    [set[k] = x for k in [:s,:g,:sector]]
    return set
end