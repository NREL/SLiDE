function share_disagg_sector!(dataset::String, d::Dict; scheme=:summary=>:disagg)
    # Read the set and BEA input, this time for the DETAILED level, and partition.
    set = read_from(joinpath("src","build","readfiles","setlist.yml"))
    [set[k] = set[:detail] for k in [:g,:s]]

    det = merge(
        read_from(joinpath("src","build","readfiles","input","detail.yml")),
        Dict(:sector=>:detail),
    )

    # !!!! Need to make sure this doesn't try to read summary-level partition
    # info if it is already saved.
    det = partition(_development(dataset), det, set)

    # Share and aggregate the sectoral map.
    share_sector!(det)
    aggregate_share!(det)

    # Disaggregate all sectoral outputs.
    disagg_sector!(merge!(d, Dict(:sector=>det[:sector])), set; scheme=scheme)

    return d
end


"""
This function performs the sectoral disaggregation for all of the model parameters.
"""
function disagg_sector!(d::Dict, set::Dict; scheme=:summary=>:disagg)
    dfmap = unique(d[:sector][:,[:yr,scheme[1],scheme[2],:value]])
    dfmap = extend_year(dfmap, set[:yr])

    taxes = [:ta0,:tm0,:ty0]
    
    [d[k] = _disagg_sector_map(d[k], dfmap; key=k) for k in taxes]
    [d[k] = _disagg_sector_share(d[k], dfmap; key=k) for k in setdiff(keys(d), [taxes;:sector])]
    
    return d
end


"""
This function maps from the aggregate to the disaggregate level and multiplies by the
sectoral sharing defined in dfmap.
"""
function _disagg_sector_share(
    df::DataFrame,
    dfmap::DataFrame;
    scheme=:summary=>:disagg,
    key=missing,
)
    on = _find_sector(df)
    
    if !isempty(on)
        !ismissing(key) && println("  Disaggregating sectors for $key")
        col = propertynames(df)
        if length(on) > 1
            dfmap = _compound_for(dfmap, on; scheme=scheme)
            (from,to) = (_add_id.(scheme[1],on), _add_id.(scheme[2],on))
        else
            (from,to) = (scheme[1], scheme[2])
        end

        # Map from the sectoral sharing DataFrame (aggregate -> (disagg,value)) while renaming
        # the sector in the input DataFrame.
        df = edit_with(df, Map(dfmap, [:yr;from], [to;:value], [:yr;on], [on;:share], :inner))
        df[!,:value] = df[:,:value] .* df[:,:share]
        df = select(df,col)
    end

    return df
end


"""
"""
function _disagg_sector_map(
    df::DataFrame,
    dfmap::DataFrame;
    scheme=:summary=>:disagg,
    fun::Function=sum,
    key=missing,
)
    on = _find_sector(df)
    
    if !isempty(on)
        !ismissing(key) && println("  Mapping sectors for $key")
        if length(on) > 1
            dfmap = _map_for(dfmap, on; scheme=scheme)
            (from,to) = (_add_id.(scheme[1],on), _add_id.(scheme[2],on))
        else
            (from,to) = (scheme[1], scheme[2])
        end

        # Map from the sectoral sharing DataFrame (aggregate -> (disagg,value)) while renaming
        # the sector in the input DataFrame.
        df = edit_with(df, Map(dfmap,ensurearray(from),ensurearray(to),on,on,:inner))
    end
    return df
end


"""
In the case that we are sharing across both goods and sectors in one data set, this function
generates a dataframe with these sharing parameters through the following process:
1. Multiply shares for all (g,s) combinations.
2. Address the case of when (g,s) are the same at the aggregate level.
    - If they are the SAME at the disaggregate level, sum all of the share values.
    - If they are DIFFERENT at the disaggregate level, drop these values.
"""
function _compound_for(df::DataFrame, col::Array{Symbol,1}; scheme=:summary=>:disagg)
    # First, multiply shares for all (g,s) combinations. Drop input rows.
    df = _map_for(df, col; scheme=scheme)
    df[!,:value] .= prod.(eachrow(df[:,col]))
    df = select(df, Not(col))

    # In the case that (g,s) is the same  at the summary level, address the following cases:
    #   1. (g,s) are the SAME at the disaggregate level, sum all of the share values.
    #   2. (g,s) are DIFFERENT at the disaggregate level, drop these.
    (from,to) = (_add_id.(scheme[1],col), _add_id.(scheme[2],col))

    # Split df based on whether (g,s) are the same at the summary level.
    splitter = DataFrame(fill(unique(df[:,from[1]]), length(from)), from)
    df_same, df_diff = split_with(df, splitter)

    # Sum over (g) at the disaggregate level, keeping only the rows for which (g,s) are the
    # same at this level.
    df_same = transform_over(df_same, to[2:end])
    ii_same = _find_constant.(eachrow(df_same[:,to]))
    df_same = df_same[ii_same,:]

    return vcat(df_same, df_diff)
end


"""
"""
function _map_for(df::DataFrame, col::Array{Symbol,1}; scheme=:summary=>:disagg)
    (from,to) = (scheme[1], scheme[2])
    df = indexjoin(fill(copy(df),length(col)); id=col, skipindex=[from,to])    
    return df
end


"""
This function returns a list of sector indices found in the input DataFrame or list.
"""
_find_sector(col::Array{Symbol,1}) = intersect([:g,:s], col)
_find_sector(df::DataFrame) = _find_sector(propertynames(df))