"""
"""
list_unique(df::DataFrame) = unique(vcat(eachcol(df)...))
list_unique(df::DataFrame, idx::AbstractArray) = list_unique(df[:,idx])
list_unique(df::DataFrame, idx::Symbol) = unique(df[:,idx])


"""
"""
function drop_identity(df::DataFrame, idx::Array{Symbol,1})
    return df[SLiDE.nunique.(eachrow(df[:,idx])).==length(idx), :]
end

function drop_identity(df, idx::Array{Array{Symbol,1},1})
    [df = drop_identity(df, getindex.(idx,ii)) for ii in 1:length(idx)]
    return df
end

drop_identity(df) = drop_identity(df, map_direction(dfmap))
drop_identity(df, idx::Tuple) = drop_identity(df, ensurearray(idx))


"""
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


"""
Defines [`SLiDE.Weighting`](@ref) field `constant` if `on` is already defined.
"""
function set_constant!(x::Weighting)
    idx = findindex(x.data)
    field = ensurearray(x.on)
    !isempty(intersect(idx, field)) && (x.constant = setdiff(idx, field))
    return x
end


"""
Defines [`SLiDE.Weighting`](@ref) field `on` if `constant` is already defined.
"""
function set_on!(x::Weighting)
    idx = findindex(x.data)
    field = x.constant
    !isempty(intersect(idx, field)) && (x.on = setdiff(idx, field))
    return x
end


"""
    map_direction(df::DataFrame)
    map_direction(x::T) where T <: Scale
Returns a Tuple of DataFrame columns in the order (aggregate-level, disaggregate-level).
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
    nn_col = SLiDE.nunique(df[:,col])
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

# function map_direction(x::T) where T <: Scale
#     return x.direction == :disaggregate ? (x.from, x.to) : (x.to, x.from)
# end


"""
"""
function set_direction!(x::T) where T <: Scale
    # agg, dis = map_direction(x.data[:, [x.from;x.to]])
    agg, dis = map_direction(x)
    x.direction = (x.from==agg && x.to==dis) ? :disaggregate : :aggregate
    return x.direction
end


"""
    set_scheme!(mapping::Mapping)
Defines `Mapping` and/or `Weighting` fields `from` and `to` if `direction` is already defined

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


"""
    map_scheme(df)
"""
map_scheme(weighting::Weighting, mapping::Mapping) = _map_scheme(weighting.data, mapping.data)
map_scheme(mapping::Mapping, weighting::Weighting) = map_scheme(weighting, mapping)

function map_scheme(x::Weighting, df::DataFrame)
    return _map_scheme(df, x.data[:,[x.from;x.to]], x.on)
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
    lstmap = list_unique(dfmap)
    
    on = [x for x in on if !isempty(intersect(df[:,x],lstmap))]

    from, to, on = _map_scheme(df, dfmap, on)
    return from, to, (length(on)==1 ? on[1] : on)
end

function _map_scheme(df::DataFrame, dfmap::DataFrame, on)
    idxmap = ensurearray(map_direction(dfmap))
    dfmap = drop_identity(dfmap, idxmap)
    df = unique(df[:,ensurearray(on)])

    dmap = Dict(k => unique(dfmap[:,ensurearray(k)]) for k in idxmap)
    dinner = Dict(k => innerjoin(dmap[k], df, on=Pair.(k, on)) for k in idxmap)

    # Find out which mapping index/indices overlap(s) most with df.
    # Higher overlap -> from, lower overlap -> to.
    noverlap = [(size(dinner[k],1), k ) for k in idxmap]
    sort!(noverlap; rev=true)
    
    return getindex(noverlap[1],2), getindex(noverlap[2],2), on
end


"""
    compound_for(x::Weighting, df::DataFrame, lst::AbstractArray)
    compound_for(x::Weighting, df::DataFrame, lst::AbstractArray)
    compound_for(x::T, col::Symbol) where T<:Scale
"""
function compound_for(x::T, df::DataFrame, lst::AbstractArray) where T <: Scale
    return compound_for!(copy(x), df, lst)
end

function compound_for(x::T, col, lst::AbstractArray) where T <: Scale
    return compound_for!(copy(x), col, lst)
end

compound_for(x::T, col::Symbol) where T <: Scale = compound_for!(copy(x), col)


"""
    compound_for!(x::Weighting, col)
    compound_for!(x::Weighting, col, lst::AbstractArray)
    compound_for!(x::Weighting, df::DataFrame, lst::AbstractArray)
This function maps `x.data` to disaggregate variables (`ys0`, `id0`) that include both
goods and sectors:

```math
\\tilde{\\delta}_{yr,gg \\rightarrow g, ss \\rightarrow s} =
    \\tilde{\\delta}_{yr,gg \\rightarrow g} \\cdot \\tilde{\\delta}_{yr, ss \\rightarrow s}
```

where ``gg``, ``ss`` represent aggregate-level goods and sectors
and ``g``, ``s`` represent disaggregate-level goods and sectors.

In the case that we are sharing across both goods and sectors in one data set, this function
generates a dataframe with these sharing parameters through the following process:
1. Multiply shares for all (``gg\\rightarrow g``,``ss\\rightarrow s``) combinations.
2. Address the case of when aggregate-level goods and sectors are the same (``gg=ss``):
    - If ``g = s``, sum all of the share values.
    - If ``g\\neq s``, drop these values.
"""
function compound_for!(x::T, col::AbstractArray, lst::AbstractArray) where T <: Scale
    if length(col)>2
        @error("Can only compound, at most, two columns.")
    elseif length(col)==1
        x = compound_for!(x, col[1])
    else
        df = x.data
        df_ones = map_identity(x, lst)
        df_all = vcat(df, df_ones)

        # Define edits and update fields.
        xedit = Dict(k => Rename.([x.from;x.to], append.([x.from;x.to],k)) for k in col)
        x.from = append.(x.from, col)
        x.to = append.(x.to, col)
        x.on = col

        x.data = _compound_with(x, df, df_ones, xedit)
    end
    return x
end

function compound_for!(x::T, df::DataFrame, lst) where T <: Scale
    compound_for!(x, findindex(df), lst)
    set_scheme!(x, df)
    return x
end

function compound_for!(x::T, df::DataFrame) where T <: Scale
    idx = findindex(df)
    compound_for!(x, df[:,idx], list_unique(df,idx))
    return x
end

function compound_for!(x::T, col::Symbol) where T <: Scale
    x.on = col
    return x
end

function compound_for!(x::Mapping, col::AbstractArray)
    if length(col)==1
        compound_for!(x, col[1])
    else
        @error("Can only compound type Mapping for one column (by renaming)")
    end
    return x
end

compound_for!(x::T, col::Symbol, lst::AbstractArray) where T <: Scale = compound_for!(x, col)
compound_for!(x::T, col::Missing, lst::AbstractArray)  where T <: Scale = missing


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
    ii_same = SLiDE._find_constant.(eachrow(df_same[:,dis]))
    df_same = df_same[ii_same,:]

    df = vcat(df_same, df_diff)
    return select(vcat(df,df_ones), [x.constant;x.from;x.to;:value])
end


function _compound_with(x::Mapping, df::DataFrame, df_ones::DataFrame, xedit::Dict)
    df_ones = vcat([crossjoin(edit_with(df, xedit[fwd]), edit_with(df_ones, xedit[rev]))
        for (fwd,rev) in zip(x.on, reverse(x.on))]...)

    df = crossjoin(edit_with(df, xedit[x.on[1]]), edit_with(df, xedit[x.on[2]]))

    return vcat(df, df_ones; cols=:intersect)
end