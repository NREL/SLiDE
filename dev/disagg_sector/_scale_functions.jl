"""
"""
scale_with(df, dfmap, from::Pair, to::Symbol) = scale_with(rename(df, from), dfmap, from[end], to)
scale_with(df, dfmap, from::Symbol, to::Symbol) = indexjoin(df, dfmap; id=[:value,:share], kind=:inner)

function scale_with(df, dfmap)
    # Ensure that from = disaggregate and to = aggregate
    agg, dis = SLiDE._find_scheme(dfmap)
    from, to = SLiDE._find_scheme(df, dfmap)

    df = scale_with(df, dfmap, from, to)

    df = df / combine_over(df, dis)

    idx = setdiff(findindex(df), [agg;dis])
    return sort(select(df, [idx;agg;dis;:value]))
end


"""
"""
function filter_scale(df, x)
    # !!!! what if x has only agg? only disagg?
    # Then length of idx will only be one.
    # And find_scheme won't work because there won't be one.
    idx = _intersect(df, x)
    agg, dis = SLiDE._find_scheme(df[:,idx])

    # Check that we are scaling SHARES here:
    dftmp = combine_over(df, dis)
    if !all(dftmp[:,:value].==1.0)
        @error("Shares must sum to 1.")
    end

    dfdis = filter_with(df, Dict(dis=>x,))
    
    dfagg = fill_with(unique(select(dfdis, Not(dis))), 1.0)
    dfagg = dfagg - combine_over(dfdis, dis)
    dfagg[!,dis] .= dfagg[:,agg]
    
    df = vcat(dfdis,dfagg)

    # Update x to add any aggregate-level sectors that were not already included,
    # but for which a disaggregate-level code exists.
    x = string.(unique([x; df[:,agg]]))
    return (df, x)
end


"""
"""
function scale_for(df, set, col)
    if length(col) > 1
        from, to = SLiDE._find_scheme(df, set);
        dfmap = SLiDE._extend_over(unique(df[:,[from;to]]), set)

        x = Dict(k => Rename.([from;to], SLiDE._add_id.([from;to], k; replace=to)) for k in col)

        idxmap = get_to.(vcat(values(x)...))

        df = vcat([crossjoin(edit_with(df, x[col]), edit_with(dfmap, x[rev]))
            for (col, rev) in zip(sort!(col), sort(col; rev=true))]...)

        idx = setdiff(findindex(df), idxmap)
        agg, dis = SLiDE._find_scheme(df[:,idxmap])

        splitter = DataFrame(fill(unique(df[:,agg[1]]), length(col)), col)
        df_same, df_diff = split_with(df, splitter)

        # df_same[!,:value] .= df_same[:,:value] .* SLiDE._find_constant.(eachrow(df_same[:,dis]))
        ii_same = SLiDE._find_constant.(eachrow(df_same[:,dis]))
        df_same = df_same[ii_same,:]

        df = select(vcat(df_same, df_diff), [idx;agg;dis;:value])
    end
    return df
end


"""
"""
function split_scale(df::DataFrame, dfmap::DataFrame, on; share::Bool=false, key=missing)
    from, to = SLiDE._find_scheme(df, dfmap, on)

    if typeof(from)<:Pair
        dfmap = edit_with(dfmap, Rename(from[2],from[1]))
        from = from[1]
    end

    SLiDE._print_scale_status(from, to; key=key)

    df_out = antijoin(df, unique(dfmap[:,ensurearray(from)]), on=from)

    df_in = if share
        edit_with(df, Map(dfmap, [idx;from], [to;:value], [idx;on], [on;:share], :inner))
    else
        edit_with(df, Map(dfmap,[from;],[to;],[on;],[on;],:inner))
    end

    return df_in, df_out
end


"""
"""
function scale_share(df, dfmap, on; key=missing)
    df_in, df_out = split_scale(df, dfmap, on; share=true, key=key)
    df_in[!,:value] .= df_in[:,:value] .* df_in[:,:share]
    df = vcat(df_out, df_in; cols=:intersect)
    return df
end


"""
"""
function scale_map(df, dfmap, on; key=missing)
    df_in, df_out = split_scale(df, dfmap, on; share=false, key=key)
    df = vcat(df_out, df_in; cols=:intersect)
    return df
end