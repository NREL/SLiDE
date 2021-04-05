abstract type Scale <: EconomicSystemsType end
# abstract type Share <: Scale end
# abstract type Map <: Scale end

mutable struct Index <: Scale
    data::DataFrame
    from::Union{Symbol,Array{Symbol,1}}
    to::Union{Symbol,Array{Symbol,1}}
    on::Union{Symbol,Array{Symbol,1}}
    direction::Symbol
end

function Index(; data, from, to, on, direction, )
    Index(data, from, to, on, direction, )
end

mutable struct Factor <: Scale
    data::DataFrame
    index::Array{Symbol,1}
    from::Union{Symbol,Array{Symbol,1}}
    to::Union{Symbol,Array{Symbol,1}}
    on::Union{Symbol,Array{Symbol,1}}
    direction::Symbol
end

function Factor(; data, index, from, to, on, direction, )
    Factor(data, index, from, to, on, direction, )
end


# ------------------------------------------------------------------------------------------


"""
"""
function Factor(data::DataFrame;
    index=[:undef],
    from=:undef,
    to=:undef,
    on=:undef,
    direction=:undef,
)
    return Factor(data, index, from, to, on, direction)
end


"""
"""
function Index(data::DataFrame; from=:undef, to=:undef, on=:undef, direction=:undef)
    return Index(data, from, to, on, direction)
end


# ------------------------------------------------------------------------------------------

"""
Extends copy to Factor and Index
"""
Base.copy(x::Factor) = Factor(copy(x.data), x.index, x.from, x.to, x.on, x.direction)
Base.copy(x::Index) = Index(copy(x.data), x.from, x.to, x.on, x.direction)

SLiDE._inp_key(x::AbstractArray) = Tuple(x)
SLiDE._inp_key(x::Symbol, col) = SLiDE._inp_key([x;col])


function SLiDE.convert_type(::Type{Index}, x::Factor)
    return Index(unique(x.data[:,[x.from;x.to]]), x.from, x.to, x.on, x.direction)
end


function SLiDE.filter_with(df::DataFrame, x::InvertedIndex{Factor})
    x = x.skip
    df_not = antijoin(df, x.data[:,[x.index;x.from]],
        on=Pair.([x.index;x.on],[x.index;x.from]))
    return df_not
end

function SLiDE.filter_with(df::DataFrame, x::InvertedIndex{Index})
    x = x.skip
    df_not = antijoin(df, x.data[:,ensurearray(x.from)], on=Pair.(x.on,x.from))
    return df_not
end


# ------------------------------------------------------------------------------------------
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
function map_identity(x::Index, lst::AbstractArray)
    col = propertynames(x.data)
    lst_ones = setdiff(lst, vcat(values.(eachcol(x.data))...))
    return DataFrame(fill(lst_ones, size(col)), col)
end

function map_identity(x::Factor, lst::AbstractArray)
    df_ones = map_identity(convert_type(Index,x), lst)
    df_index = unique(x.data[:,ensurearray(x.index)])
    return edit_with(crossjoin(df_index, df_ones), Add.(:value,1.0))
end


# ------------------------------------------------------------------------------------------


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
Defines [`SLiDE.Factor`](@ref) field `index` if `on` is already defined.
"""
function set_index!(x::Factor)
    idx = findindex(x.data)
    field = ensurearray(x.on)
    !isempty(intersect(idx, field)) && (x.index = setdiff(idx, field))
    return x
end


"""
Defines [`SLiDE.Factor`](@ref) field `on` if `index` is already defined.
"""
function set_on!(x::Factor)
    idx = findindex(x.data)
    field = x.index
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


function map_direction(x::T) where T <: Scale
    return x.direction == :disaggregate ? (x.from, x.to) : (x.to, x.from)
end


"""
"""
function set_direction!(x::T) where T <: Scale
    agg, dis = map_direction(x.data[:, [x.from;x.to]])
    x.direction = (x.from==agg && x.to==dis) ? :disaggregate : :aggregate
    return x.direction
end


"""
    set_scheme!(index::Index)
Defines `Index` and/or `Factor` fields `from` and `to` if `direction` is already defined

    set_scheme!(index::Index, factor::Factor)
    set_scheme!(factor::Factor, index::Index)
Defines `Index` and/or `Factor` fields `from` and `to` !!!!
"""
function set_scheme!(factor::Factor, index::Index)
    # Mapping
    from, to, on = map_scheme(factor, index)
    factor.from, factor.to, factor.on = from, to, on
    index.from, index.to, index.on = from, to, on
    
    # Direction -- DO NOT change from, to fields. These are determined based on overlap
    # between factor and index data.
    set_direction!(index)
    factor.direction = index.direction

    # Index
    set_index!(factor)
    return factor, index
end


function set_scheme!(index::Index, factor::Factor)
    factor, index = set_scheme!(factor, index)
    return index, factor
end


function set_scheme!(x::T, df::DataFrame) where T <: Scale
    x.from, x.to, x.on = map_scheme(x, df)
    set_direction!(x)
    return x
end


"""
    map_scheme(df)
"""
map_scheme(factor::Factor, index::Index) = _map_scheme(factor.data, index.data)
map_scheme(index::Index, factor::Factor) = map_scheme(factor, index)

function map_scheme(x::Factor, df::DataFrame)
    return _map_scheme(df, x.data[:,[x.from;x.to]], x.on)
end

map_scheme(x::Index, df::DataFrame) = _map_scheme(df, x.data)


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
    share_with!(factor::Factor, index::Index)
Returns `factor` with `factor.data::DataFrame` shared using [`SLiDE.share_with`](@ref)
"""
function share_with!(factor::Factor, index::Index)
    factor.data = select(
        share_with(factor.data, index),
        [factor.index; factor.from; factor.to; findvalue(factor.data)],
    )
    return factor
end


"""
    share_with(df::DataFrame, x::Index)
"""
function share_with(df::DataFrame, x::Index)
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
    filter_with!(factor::Factor, lst::AbstractArray)

    filter_with!(index::Index, factor::Factor)


    filter_with!(index::Index, factor::Factor, lst::AbstractArray)
    filter_with!(factor::Factor, index::Index, lst::AbstractArray)
Apply the above methods sequentially and returns all input arguments in the order in which
they are given.
"""
function filter_with!(factor::Factor, lst::AbstractArray)
    agg, dis = map_direction(factor)

    dftmp = combine_over(factor.data, dis)
    if !all(dftmp[:,:value].==1.0)
        @error("Shares must sum to 1.")
    end

    dfdis = filter_with(factor.data, Dict(dis=>lst,))
    
    dfagg = fill_with(unique(select(dfdis, Not(dis))), 1.0)
    dfagg = dfagg - combine_over(dfdis, dis)
    dfagg[!,dis] .= dfagg[:,agg]
    
    factor.data = vcat(dfdis,dfagg)

    # Update x to add any aggregate-level sectors that were not already included,
    # but for which a disaggregate-level code exists.
    lst_new = setdiff(factor.data[:,agg], lst)
    [push!(lst, x) for x in lst_new]

    return factor, lst
end

function filter_with!(index::Index, factor::Factor)
    col = intersect(propertynames(factor.data), propertynames(index.data))
    index.data = unique(factor.data[:,col])
    return index
end

function filter_with!(factor::Factor, index::Index, lst::AbstractArray)
    factor, lst = filter_with!(factor, lst)
    index = filter_with!(index, factor)
    return factor, index, lst
end

function filter_with!(index::Index, factor::Factor, lst::AbstractArray)
    factor, index, lst = filter_with!(factor, index, lst)
    return index, factor, lst
end


"""
    compound_for(x::Factor, df::DataFrame, lst::AbstractArray)
    compound_for(x::Factor, df::DataFrame, lst::AbstractArray)
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
    compound_for!(x::Factor, col)
    compound_for!(x::Factor, col, lst::AbstractArray)
    compound_for!(x::Factor, df::DataFrame, lst::AbstractArray)
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

function compound_for!(x::Index, col::AbstractArray)
    if length(col)==1
        compound_for!(x, col[1])
    else
        @error("Can only compound type Index for one column (by renaming)")
    end
    return x
end

compound_for!(x::T, col::Symbol, lst::AbstractArray) where T <: Scale = compound_for!(x, col)
compound_for!(x::T, col::Missing, lst::AbstractArray)  where T <: Scale = missing


"""
Helper function to handle the differing treatment of compounding Index and Factor data.
"""
function _compound_with(x::Factor, df::DataFrame, df_ones::DataFrame, xedit::Dict)
    df_ones = vcat([edit_with(df, xedit[fwd]) * edit_with(df_ones, xedit[rev])
        for (fwd,rev) in zip(x.on, reverse(x.on))]...)
    
    df = edit_with(df, xedit[x.on[1]]) * edit_with(df, xedit[x.on[2]])

    # In the case that (g,s) are the same at the aggregate level, if...
    #   1. (g,s) are the SAME at the disaggregate level, sum all of the share values.
    #   2. (g,s) are DIFFERENT at the disaggregate level, drop these.
    # Split df based on whether (g,s) are the same at the aggregate level.
    agg, dis = map_direction(df[:, [x.from;x.to]])
    splitter = DataFrame(fill(unique(df[:,agg[1]]), length(agg)), agg)
    df_same, df_diff = split_with(df, splitter)

    # Sum over (g) at the disaggregate level, keeping only the rows for which
    # (g,s) are the same at this level.
    df_same = transform_over(df_same, dis[1])
    ii_same = SLiDE._find_constant.(eachrow(df_same[:,dis]))
    df_same = df_same[ii_same,:]

    df = vcat(df_same, df_diff)
    return select(vcat(df,df_ones), [x.index;x.from;x.to;:value])
end


function _compound_with(x::Index, df::DataFrame, df_ones::DataFrame, xedit::Dict)
    df_ones = vcat([crossjoin(edit_with(df, xedit[fwd]), edit_with(df_ones, xedit[rev]))
        for (fwd,rev) in zip(x.on, reverse(x.on))]...)

    df = crossjoin(edit_with(df, xedit[x.on[1]]), edit_with(df, xedit[x.on[2]]))

    return vcat(df, df_ones; cols=:intersect)
end


"""
    compound_sector!(d, set, var; scale_id)
"""
function compound_sector!(d::Dict, set::Dict, var::Symbol; scale_id::Symbol=:factor)
    df = d[var]
    col = find_sector(df)
    lst = set[:sector]

    if ismissing(col)
        return missing
    else
        key = SLiDE._inp_key(scale_id,col)
        if !haskey(d, key)
            d[key] = compound_for(d[scale_id], df[:, ensurearray(col)], lst)
        end
        return d[key]
    end
end