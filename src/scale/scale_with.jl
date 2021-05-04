"""
    scale_with(df::DataFrame, x::Weighting)
This function maps `df`: `x.from -> x.to`, multiplying by any associated `share` specified
in `x.data`. For a parameter ``\\bar{z}``,
```math
\\begin{aligned}
\\bar{z}_{c,a} = \\sum_{aa} \\left( \\bar{z}_{c,aa} \\cdot \\tilde{\\delta}_{c,aa \\rightarrow a} \\right)
\\end{aligned}
```
where ``c`` (`x.constant`) represents the index/ices included in, but not changed by,
the scaling process, and ``aa`` (`x.from`) and ``a`` (`x.to`) represent
the value(s) of the scaled index/ices before and after scaling.


    scale_with(df::DataFrame, x::Mapping)
This function scales a parameter in `df` according to the input map `dfmap`.
For a parameter ``\\bar{z}``,
```math
\\bar{z}_{c,a} = \\left(\\bar{z}_{c,aa} \\circ map_{aa\\rightarrow a} \\right)
```
where ``c`` (`x.constant`) represents the index/ices included in, but not changed by,
the scaling process, and ``aa`` (`x.from`) and ``a`` (`x.to`) represent
the value(s) of the scaled index/ices before and after scaling.

For each method, `x.direction = disaggregate`, all disaggregate-level entries will remain
equal to their aggregate-level value. If `x.direction = aggregate`,
```math
\\bar{z}_{c,a} = \\sum_{aa} \\bar{z}_{c,a}
```
"""
function scale_with(df::DataFrame, x::Weighting; kwargs...)
    print_status(df; kwargs...)

    # Save unaffected indices. Map the others and calculate share.
    df_ones = filter_with(df, Not(x))
    df = edit_with(df,
        Map(x.data, [x.constant;x.from], [x.to;:value], [x.constant;x.on], [x.on;:share], :inner)
    )
    df[!,:value] .*= df[:,:share]

    # Sum if aggregating.
    x.direction == :aggregate && (df = combine_over(df, :dummy))
    return vcat(select(df, Not(:share)), df_ones)
end


function scale_with(df::DataFrame, x::Mapping; kwargs...)
    print_status(df; kwargs...)

    # Save unaffected indices. Map the others.
    df_ones = filter_with(df, Not(x))
    df = edit_with(df, Map(x.data, [x.from;], [x.to;], [x.on;], [x.on;], :inner))

    # Sum if aggregating.
    x.direction == :aggregate && (df = combine_over(df, :dummy; digits=false))
    return vcat(df, df_ones)
end


function scale_with(lst::AbstractArray, x::Mapping; kwargs...)
    x = compound_for(x, lst, lst)
    return unique(scale_with(DataFrame(x.on=>lst), x; kwargs...)[:,1])
end

scale_with(lst, x::Weighting; kwargs...) = scale_with(lst, convert_type(Mapping,x); kwargs...)

scale_with(df::DataFrame, x::Union{Missing,Nothing}; kwargs...) = df


"""
    filter_for!(weighting::Weighting, lst::AbstractArray)
    filter_for!(mapping::Mapping, weighting::Weighting)

    filter_for!(mapping::Mapping, weighting::Weighting, lst::AbstractArray)
    filter_for!(weighting::Weighting, mapping::Mapping, lst::AbstractArray)

"""
function filter_for!(weighting::Weighting, lst::AbstractArray)
    agg, dis = map_direction(weighting)

    dftmp = combine_over(weighting.data, dis)
    if !all(dftmp[:,:value].==1.0)
        @error("Shares must sum to 1.")
    end

    dfdis = filter_with(weighting.data, Dict(dis=>lst,))
        
    dfagg = fill_with(unique(select(dfdis, Not(dis))), 1.0)
    dfagg = dfagg - combine_over(dfdis, dis)
    dfagg[!,dis] .= dfagg[:,agg]

    dropzero!(dfagg)
    
    weighting.data = vcat(dfdis,dfagg)

    # Update x to add any aggregate-level sectors that were not already included,
    # but for which a disaggregate-level code exists.
    lst_new = setdiff(weighting.data[:,agg], lst)
    [push!(lst, x) for x in lst_new]

    return weighting, lst
end

function filter_for!(mapping::Mapping, weighting::Weighting)
    col = intersect(propertynames(weighting.data), propertynames(mapping.data))
    mapping.data = unique(weighting.data[:,col])
    return mapping
end

function filter_for!(weighting::Weighting, mapping::Mapping, lst::AbstractArray)
    # !!!! MAKE SURE ZEROS ARE FILLED HERE.
    weighting, lst = filter_for!(weighting, lst)
    mapping = filter_for!(mapping, weighting)
    return weighting, mapping, lst
end

function filter_for!(mapping::Mapping, weighting::Weighting, lst::AbstractArray)
    weighting, mapping, lst = filter_for!(weighting, mapping, lst)
    return mapping, weighting, lst
end


"""
    compound_for(x::T, lst::AbstractArray, df::DataFrame)
    compound_for(x::T, lst::AbstractArray)
"""
function compound_for(x::T, lst::AbstractArray, df::DataFrame) where T<:Scale
    return compound_for!(copy(x), lst, df)
end

function compound_for(x::T, lst::AbstractArray) where T<:Scale
    return compound_for!(copy(x), lst)
end

function compound_for(x::T, lst::AbstractArray, setlst::AbstractArray) where T<:Scale
    (isarray(x.on) && length(x.on)==1) && set_on!(x, x.on[1])
    return compound_for(convert_type(Mapping,x), lst, DataFrame(x.on=>setlst))
end


"""
    compound_for!(x::T, lst::AbstractArray) where T <: Scale
    compound_for!(x::T, lst::AbstractArray, df::DataFrame) where T <: Scale
This function compounds the information in Scale for parameters scaled over multiple indices
simultaneously. This is relevant for parameters such as sectoral output, ``ys_{yr,r,ss,gg}``,
and intermediate demand, ``id_{yr,r,gg,ss}``, that depend on both goods and sectors.

# Arguments
- `x::T where T <: Scale`, scaling information over one index (ex: `aa -> a`), with
    `x.on` set to the target scaling indices (ex: `x.on = [:s,:g]` when compounding to scale
    `ys_{yr,r,s,g}`)
- `lst::AbstractArray`, the complete list of disaggregate-level values in the scaling DataFrame.
- `df::DataFrame`, DataFrame that will ultimately be scaled. If given, `x.data` will be
    extended using `SLiDE.map_year`, to ensure that it is fully defined over all years.
    This is required, for example, when using detail-level BEA data (collected every 5
    years) to disaggregate summary-level data (collected annually).

# Returns
- `x::T where T <: Scale`,
    ``\\delta_{c,aa \\rightarrow a, bb \\rightarrow b} =
        \\delta_{c,aa \\rightarrow a} \\cdot \\delta_{c, bb \\rightarrow b}``
    where ``c`` (`x.constant`) represents the index/ices included in, but not changed by,
    the scaling process, and ``aa``,``bb`` (`x.from`) and ``a``,``b`` (`x.to`) represent
    the value(s) of the scaled index/ices before and after scaling.

    `x.data` does not include `(a,b)` combinations that result into one-to-one mapping.

The specifics of this calculation depend on the Scale subtype input argument.

    compound_for!(x::Mapping, lst::AbstractArray)
Here, all (``aa\\rightarrow a``,``bb\\rightarrow b``) pairs that do not result in one-to-one
mapping are included.

    compound_for!(x::Weighting, lst::AbstractArray)
Here, assume `x.direction = disaggregate`, since aggregation does not require multiplication
by a weighting factor. Consider the case of sharing across both goods and sectors at once.
So, ``g``, ``s`` represent disaggregate-level goods and sectors.
and ``gg``, ``ss`` represent aggregate-level goods and sectors

This function generates a DataFrame with these sharing parameters through the following process:
1. Multiply shares for all (``gg\\rightarrow g``,``ss\\rightarrow s``) combinations.
2. Address the case of when aggregate-level goods and sectors are the same (``gg=ss``):
    - If ``g = s``, sum all of the share values.
    - If ``g\\neq s``, drop these values.


# Example
These two examples are taken from slices of the `Weighting` and `Mapping` DataTypes
compounded to scale sectoral supply, `ys0(yr,r,s,g)` when scaling the model parameters
during the first step of the EEM build stream, executed by [`SLiDE.scale_sector`](@ref).

First, summary-level parameters must be disaggregated to a hybrid of summary- and detail-
level data.

```jldoctest compound_for
julia> lst = ["col_min", "ele_uti", "min", "oil", "uti"];

julia> df = read_file(joinpath(SLIDE_DIR,"docs","src","assets","data","compound_for-weighting.csv"))
4×4 DataFrame
│ Row │ yr    │ summary │ detail  │ value    │
│     │ Int64 │ String  │ String  │ Float64  │
├─────┼───────┼─────────┼─────────┼──────────┤
│ 1   │ 2012  │ min     │ col_min │ 0.419384 │
│ 2   │ 2012  │ min     │ min     │ 0.580616 │
│ 3   │ 2012  │ uti     │ ele_uti │ 0.715143 │
│ 4   │ 2012  │ uti     │ uti     │ 0.284857 │

julia> weighting = Weighting(data=df, constant=[:yr], from=:summary, to=:detail, on=[:s,:g], direction=:disaggregate);

julia> SLiDE.compound_for!(weighting, lst)
Weighting(20×6 DataFrame
│ Row │ yr     │ summary_s │ summary_g │ detail_s │ detail_g │ value    │
│     │ Int64? │ String?   │ String?   │ String?  │ String?  │ Float64  │
├─────┼────────┼───────────┼───────────┼──────────┼──────────┼──────────┤
│ 1   │ 2012   │ min       │ min       │ col_min  │ col_min  │ 0.419384 │
│ 2   │ 2012   │ min       │ min       │ min      │ min      │ 0.580616 │
│ 3   │ 2012   │ min       │ oil       │ col_min  │ oil      │ 0.419384 │
│ 4   │ 2012   │ min       │ oil       │ min      │ oil      │ 0.580616 │
│ 5   │ 2012   │ min       │ uti       │ col_min  │ ele_uti  │ 0.29992  │
│ 6   │ 2012   │ min       │ uti       │ col_min  │ uti      │ 0.119465 │
│ 7   │ 2012   │ min       │ uti       │ min      │ ele_uti  │ 0.415223 │
⋮
│ 13  │ 2012   │ uti       │ min       │ ele_uti  │ col_min  │ 0.29992  │
│ 14  │ 2012   │ uti       │ min       │ ele_uti  │ min      │ 0.415223 │
│ 15  │ 2012   │ uti       │ min       │ uti      │ col_min  │ 0.119465 │
│ 16  │ 2012   │ uti       │ min       │ uti      │ min      │ 0.165393 │
│ 17  │ 2012   │ uti       │ oil       │ ele_uti  │ oil      │ 0.715143 │
│ 18  │ 2012   │ uti       │ oil       │ uti      │ oil      │ 0.284857 │
│ 19  │ 2012   │ uti       │ uti       │ ele_uti  │ ele_uti  │ 0.715143 │
│ 20  │ 2012   │ uti       │ uti       │ uti      │ uti      │ 0.284857 │, [:yr], [:summary_s, :summary_g], [:detail_s, :detail_g], [:s, :g], :disaggregate)
```

Next, these hybrid-level parameters must be aggregated in accordance with the scheme
required for the EEM.

```jldoctest compound_for
julia> df = read_file(joinpath(SLIDE_DIR,"docs","src","assets","data","compound_for-mapping.csv"))
4×2 DataFrame
│ Row │ aggr   │ disagg  │
│     │ String │ String  │
├─────┼────────┼─────────┤
│ 1   │ col    │ col_min │
│ 2   │ eint   │ min     │
│ 3   │ eint   │ uti     │
│ 4   │ ele    │ ele_uti │

julia> mapping = Mapping(data=df, from=:disagg, to=:aggr, on=[:s,:g], direction=:aggregate);

julia> SLiDE.compound_for!(mapping, lst)
Mapping(24×4 DataFrame
│ Row │ disagg_s │ disagg_g │ aggr_s │ aggr_g │
│     │ String   │ String   │ String │ String │
├─────┼──────────┼──────────┼────────┼────────┤
│ 1   │ col_min  │ col_min  │ col    │ col    │
│ 2   │ col_min  │ ele_uti  │ col    │ ele    │
│ 3   │ col_min  │ min      │ col    │ eint   │
│ 4   │ col_min  │ oil      │ col    │ oil    │
│ 5   │ col_min  │ uti      │ col    │ eint   │
│ 6   │ ele_uti  │ col_min  │ ele    │ col    │
│ 7   │ ele_uti  │ ele_uti  │ ele    │ ele    │
⋮
│ 17  │ oil      │ ele_uti  │ oil    │ ele    │
│ 18  │ oil      │ min      │ oil    │ eint   │
│ 19  │ oil      │ uti      │ oil    │ eint   │
│ 20  │ uti      │ col_min  │ eint   │ col    │
│ 21  │ uti      │ ele_uti  │ eint   │ ele    │
│ 22  │ uti      │ min      │ eint   │ eint   │
│ 23  │ uti      │ oil      │ eint   │ oil    │
│ 24  │ uti      │ uti      │ eint   │ eint   │, [:disagg_s, :disagg_g], [:aggr_s, :aggr_g], [:s, :g], :aggregate)
```
"""
function compound_for!(x::T, lst::AbstractArray) where T<:Scale
    if !isarray(x.on) || length(x.on)==1
        return x
    elseif length(x.on)>2
        @error("Can only compound, at most, two columns.")
    else
        df = x.data
        df_ones = map_identity(x, lst)
        df_all = vcat(df, df_ones)
        
        # Define edits and update fields.
        xedit = Dict(k => Rename.([x.from;x.to], append.([x.from;x.to],k)) for k in x.on)
        set_from!(x, append.(x.from, x.on))
        set_to!(x, append.(x.to, x.on))

        x.data = _compound_with(x, df, df_ones, xedit)
    end
    return x
end

function compound_for!(x::T, lst, df::DataFrame) where T<:Scale
    compound_for!(x, lst)
    map_year!(x, df)
    set_scheme!(x, df)
    return x
end


"""
Helper function to handle the differing treatment of compounding Mapping and Weighting data.
"""
function _compound_with(x::Weighting, df::DataFrame, df_ones::DataFrame, xedit::Dict)
    df_ones = vcat([edit_with(df, xedit[fwd]) * edit_with(df_ones, xedit[rev])
        for (fwd,rev) in zip(x.on, reverse(x.on))]...)
    
    df = edit_with(df, xedit[x.on[1]]) * edit_with(df, xedit[x.on[2]])

    # In the case that (g,s) are the same at the aggregate level, if...
    #   1. (g,s) are the SAME at the disaggregate level, sum all of the share values.
    #   2. (g,s) are DIFFERENT at the disaggregate level, drop these.
    # Split df based on whether (g,s) are the same at the aggregate level.
    # Note: using map_direction on df, not x, since df has already been compounded and
    #   x.data has not yet been updated to have the same dimensions.
    #   x.from and x.to HAVE been updated and are safe to use.
    agg, dis = map_direction(df[:, [x.from;x.to]])
    splitter = DataFrame(fill(unique(df[:,agg[1]]), length(agg)), agg)
    df_same, df_diff = split_with(df, splitter)

    # Sum over (g) at the disaggregate level, keeping only the rows for which
    # (g,s) are the same at this level.
    df_same = transform_over(df_same, dis[1])
    ii_same = _find_constant.(eachrow(df_same[:,dis]))
    df_same = df_same[ii_same,:]

    df = vcat(df_same, df_diff)
    return sort(select(vcat(df, df_ones), [x.constant;x.from;x.to;:value]))
end


function _compound_with(x::Mapping, df::DataFrame, df_ones::DataFrame, xedit::Dict)
    df_ones = vcat([crossjoin(edit_with(df, xedit[fwd]), edit_with(df_ones, xedit[rev]))
        for (fwd,rev) in zip(x.on, reverse(x.on))]...)

    df = crossjoin(edit_with(df, xedit[x.on[1]]), edit_with(df, xedit[x.on[2]]))

    return sort(select(vcat(df, df_ones), [x.from;x.to]))
end


"""
    list_unique(df::DataFrame)
    list_unique(df::DataFrame, idx::AbstractArray)
    list_unique(df::DataFrame, idx::Symbol)
This function returns a list of all unique elements across multiple DataFrame columns
"""
list_unique(df::DataFrame) = unique(vcat(eachcol(df)...))
list_unique(df::DataFrame, idx::AbstractArray) = list_unique(df[:,idx])
list_unique(df::DataFrame, idx::Symbol) = unique(df[:,idx])


"This function drops `df` rows that are mapped one-to-one."
function drop_identity(df::DataFrame, idx::Array{Symbol,1})
    return df[nunique.(eachrow(df[:,idx])).==length(idx), :]
end

function drop_identity(df, idx::Array{Array{Symbol,1},1})
    [df = drop_identity(df, getindex.(idx,ii)) for ii in 1:length(idx)]
    return df
end

drop_identity(df) = drop_identity(df, map_direction(dfmap))
drop_identity(df, idx::Tuple) = drop_identity(df, ensurearray(idx))


"""
    map_identity(x::T, lst::AbstractArray) where T<:Scale
This function adds one-to-one mapping to the `data` field in `Mapping` or `Weighting` so
that the entirity of `lst` is included in the mapping.

# Returns
- `df::DataFrame` with `lst` completely mapped.
"""
function map_identity(x::Mapping, lst::AbstractArray)
    col = propertynames(x.data)
    lst_ones = setdiff(lst, vcat(values.(eachcol(x.data))...))
    return DataFrame(fill(lst_ones, size(col)), col)
end

function map_identity(x::Weighting, lst::AbstractArray)
    df_ones = map_identity(convert_type(Mapping,x), lst)
    df_index = unique(x.data[:,ensurearray(x.constant)])
    return edit_with(crossjoin(df_index, df_ones), Add.(:value,1.0))
end


"""
# Argument
- `idx::AbstractArray`: list of columns that might contain good/sector indices **OR**
    `df::DataFrame`: for which we need to find goods/sectors

# Returns
- `idx::Array{Symbol,1}`: input columns that overlap with `[:g,:s]` in the order in which
    they're given
"""
function find_sector(idx::AbstractArray)
    idx = intersect(idx, [:g,:s])

    return if length(idx)==0
        missing
    elseif length(idx)==1
        idx[1]
    else
        idx
    end
end

find_sector(df::DataFrame) = find_sector(propertynames(df))


"Define the [`SLiDE.Weighting`](@ref) field `constant` if `on` is already defined."
function set_constant!(x::Weighting)
    idx = findindex(x.data)
    field = ensurearray(x.on)
    !isempty(intersect(idx, field)) && set_constant!(x, setdiff(idx, field))
    return x
end


"Define the [`SLiDE.Weighting`](@ref) field `on` if `constant` is already defined."
function set_on!(x::Weighting)
    idx = findindex(x.data)
    field = x.constant
    !isempty(intersect(idx, field)) && set_on!(x, setdiff(idx, field))
    return x
end


"""
    map_direction(df::DataFrame)
    map_direction(x::T) where T <: Scale
This function returns a Tuple of DataFrame columns in the order (aggregate, disaggregate).
This is determined from the number of unique entries in each column under the assumption
that the aggregate-level will have fewer unique entries.

```jldoctest
df = DataFrame(s="cng", src=["cru","gas"])
SLiDE.map_direction(df)

# output

(:s, :src)
```
"""
function map_direction(df::DataFrame)
    col = findindex(df)
    nn_col = nunique(df[:,col])
    nn_unique = unique(nn_col)

    # If there is only ONE column on each the aggregate and disaggregate level...
    if nn_col == nn_unique
        ii = sortperm(nn_unique)
        agg, dis = col[ii[1]], col[ii[end]]
    else
        scheme = [col[nn_col.==nn] for nn in sort(nn_unique)]
        agg, dis = scheme[1], scheme[end]
    end
    
    return agg, dis
end

map_direction(x::Mapping) = map_direction(x.data)
map_direction(x::Weighting) = map_direction(convert_type(Mapping, x))


"""
This function sets the `direction` field to `aggregate` or `disaggregate` based on the
results of [`SLiDE.map_direction`](@ref) and values of the `from` and `to` fields.
"""
function set_direction!(x::T) where T <: Scale
    agg, dis = map_direction(x)
    x.direction = (x.from==agg && x.to==dis) ? :disaggregate : :aggregate
    return x.direction
end


"This function returns true if all scaling parameters have been set to a defined parameter."
has_scheme(x::T) where T<:Scale = !(:undef in [x.from;x.to;x.direction])


"""
    set_scheme!(mapping::Mapping)
Define `Mapping` and/or `Weighting` fields `from` and `to` if `direction` is already defined.

    set_scheme!(mapping::Mapping, weighting::Weighting)
    set_scheme!(weighting::Weighting, mapping::Mapping)
Defines `Mapping` and/or `Weighting` fields `from` and `to` !!!!
"""
function set_scheme!(weighting::Weighting, mapping::Mapping)
    # Mapping
    from, to, on = map_scheme(weighting, mapping)
    weighting.from, weighting.to, weighting.on = from, to, on
    mapping.from, mapping.to, mapping.on = from, to, on
    
    # Direction -- DO NOT change from, to fields. These are determined based on overlap
    # between weighting and mapping data.
    set_direction!(mapping)
    weighting.direction = mapping.direction

    # Mapping
    set_constant!(weighting)
    return weighting, mapping
end


function set_scheme!(mapping::Mapping, weighting::Weighting)
    weighting, mapping = set_scheme!(weighting, mapping)
    return mapping, weighting
end


function set_scheme!(x::T, df::DataFrame) where T <: Scale
    x.from, x.to, x.on = map_scheme(x, df)
    set_direction!(x)
    return x
end


function set_scheme!(x::T, lst::AbstractArray) where T <: Scale
    SLiDE.set_scheme!(x, DataFrame(dummy=lst,))
    x.on = x.from
    return x
end


""
function reverse_scheme!(x::T) where T<:Scale
    x.direction = x.direction==:aggregate ? :disaggregate : :aggregate
    x.to, x.from = x.from, x.to
    return x
end


"""
    map_scheme(x::T...)
    map_scheme(x::T, df::DataFrame)
This function sets the `direction` field for `Mapping` and `Weighting` types based on
overlap between input parameters.
"""
map_scheme(weighting::Weighting, mapping::Mapping) = _map_scheme(weighting.data, mapping.data)
map_scheme(mapping::Mapping, weighting::Weighting) = map_scheme(weighting, mapping)

function map_scheme(x::Weighting, df::DataFrame)
    return _map_scheme(df, unique(x.data[:,[x.from;x.to]]), x.on)
end

map_scheme(x::Mapping, df::DataFrame) = _map_scheme(df, x.data)


"""
    _map_scheme(df, dfmap, on)
Internal support for [`SLiDE.map_scheme`](@ref) to avoid confusion over DataFrame inputs.

# Arguments
- `df::DataFrame` of column(s) to scale
- `dfmap::DataFrame` of mapping columns
- `on::Symbol` or `on::Array{Symbol,1}`: columns in `df` that will be mapped

# Returns
- `from::Symbol` or `from::Array{Symbol,1}`: `dfmap` columns that overlap with `df`
- `to::Symbol` or `to::Array{Symbol,1}`: `dfmap` columns that do not overlap with `df`
- `on::Symbol` or `on::Array{Symbol,1}`: columns in `df` that will be mapped
"""
function _map_scheme(df::DataFrame, dfmap::DataFrame)
    on = findindex(df)
    lstmap = SLiDE.list_unique(dfmap)
    
    on = [x for x in on if !isempty(intersect(df[:,x],lstmap))]

    from, to, on = _map_scheme(df, dfmap, on)
    return from, to, (length(on)==1 ? on[1] : on)
end

function _map_scheme(df::DataFrame, dfmap::DataFrame, on)
    idxmap = ensurearray(SLiDE.map_direction(dfmap))
    dfmap = SLiDE.drop_identity(dfmap, idxmap)
    df = unique(df[:,ensurearray(on)])

    if size(propertynames(dfmap),1) !== 2*size(ensurearray(on),1)
        on = intersect(propertynames(dfmap), ensurearray(on))
    end

    dmap = Dict(k => unique(dfmap[:,ensurearray(k)]) for k in idxmap)
    dinner = Dict(k => innerjoin(dmap[k], df, on=Pair.(k, on); makeunique=true) for k in idxmap)

    # Find out which mapping index/indices overlap(s) most with df.
    # Higher overlap -> from, lower overlap -> to.
    noverlap = [(size(dinner[k],1), k ) for k in idxmap]
    sort!(noverlap; rev=true)
    
    return getindex(noverlap[1],2), getindex(noverlap[2],2), on
end