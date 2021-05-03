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

When filtering, we ensure the following:
1. Each disaggregate-level code's corresponging 

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