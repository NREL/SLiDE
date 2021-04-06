"""
    scale_with(df, x)
"""
function scale_with(df::DataFrame, x::Weighting)
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


function scale_with(df::DataFrame, x::Mapping)    
    # Save unaffected indices. Map the others.
    df_ones = filter_with(df, Not(x))
    df = edit_with(df, Map(x.data, [x.from;], [x.to;], [x.on;], [x.on;], :inner))

    # Sum if aggregating.
    x.direction == :aggregate && (df = combine_over(df, :dummy; digits=false))
    return vcat(df, df_ones)
end


scale_with(df::DataFrame, x::Missing) = df


"""
    filter_with!(weighting::Weighting, lst::AbstractArray)

    filter_with!(mapping::Mapping, weighting::Weighting)

    filter_with!(mapping::Mapping, weighting::Weighting, lst::AbstractArray)
    filter_with!(weighting::Weighting, mapping::Mapping, lst::AbstractArray)
Apply the above methods sequentially and returns all input arguments in the order in which
they are given.
"""
function filter_with!(weighting::Weighting, lst::AbstractArray)
    agg, dis = map_direction(weighting)

    dftmp = combine_over(weighting.data, dis)
    if !all(dftmp[:,:value].==1.0)
        @error("Shares must sum to 1.")
    end

    dfdis = filter_with(weighting.data, Dict(dis=>lst,))
    
    dfagg = fill_with(unique(select(dfdis, Not(dis))), 1.0)
    dfagg = dfagg - combine_over(dfdis, dis)
    dfagg[!,dis] .= dfagg[:,agg]
    
    weighting.data = vcat(dfdis,dfagg)

    # Update x to add any aggregate-level sectors that were not already included,
    # but for which a disaggregate-level code exists.
    lst_new = setdiff(weighting.data[:,agg], lst)
    [push!(lst, x) for x in lst_new]

    return weighting, lst
end

function filter_with!(mapping::Mapping, weighting::Weighting)
    col = intersect(propertynames(weighting.data), propertynames(mapping.data))
    mapping.data = unique(weighting.data[:,col])
    return mapping
end

function filter_with!(weighting::Weighting, mapping::Mapping, lst::AbstractArray)
    weighting, lst = filter_with!(weighting, lst)
    mapping = filter_with!(mapping, weighting)
    return weighting, mapping, lst
end

function filter_with!(mapping::Mapping, weighting::Weighting, lst::AbstractArray)
    weighting, mapping, lst = filter_with!(weighting, mapping, lst)
    return mapping, weighting, lst
end