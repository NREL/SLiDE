"""
    disagg_sector!(dataset::String, d::Dict, set::Dict; kwargs...)
This function performs the sectoral disaggregation for all of the model parameters.
- Taxes (``ta``, ``tm``, ``ty``) are disaggregated using [`SLiDE._disagg_sector_map`](@ref).
- All other parameters are disaggregated using [`SLiDE._disagg_sector_share`](@ref).

Since disaggregate-level data is available only for 2007 and 2012, the map `d[:sector]` must
be extended using [`SLiDE.map_year`](@ref), so that

```math
\\tilde{\\delta}_{yr,gg \\rightarrow g} =
\\begin{cases}
\\tilde{\\delta}_{2007,gg \\rightarrow g}  & yr \\leq 2009  \\\\
\\tilde{\\delta}_{2012,gg \\rightarrow g}  & yr > 2009
\\end{cases}
```

where ``gg``, ``ss`` represent aggregate-level goods and sectors
and ``g``, ``s`` represent **dis**aggregate-level goods and sectors.

# Arguments
- `dataset::String`: dataset identifier
- `d::Dict` of DataFrames containing the model parameters. This must include `d[:sector]`,
    ``\\tilde{\\delta}_{yr,gg \\rightarrow g}``, of sectoral shares.
- `set::Dict` of Arrays describing region, sector, final demand, etc.

# Keywords
- `scheme::Pair = :aggr=>:disagg`: columns in `dfmap` to **dis**aggregate from ``\\rightarrow`` to

# Returns
- `d::Dict` of DataFrames containing disaggregated model parameters.
- `set::Dict` of Arrays describing region, sector, final demand, etc.
"""
function disagg_sector!(
    dataset::String,
    d::Dict,
    set::Dict;
    scheme=:aggr=>:disagg,
)
    dfmap = unique(d[:sector][:,[:yr,scheme[1],scheme[2],:value]])
    dfmap = map_year(dfmap, set[:yr])

    taxes = [:ta0,:tm0,:ty0]
    
    [d[k] = _disagg_sector_map(d[k], dfmap; key=k) for k in taxes]
    [d[k] = _disagg_sector_share(d[k], dfmap; key=k) for k in setdiff(keys(d), [taxes;:sector])]
    
    return d, set
end


"""
    _disagg_sector_share(df::DataFrame, dfmap::DataFrame; kwargs...)
This function maps `df` from the aggregate to the disaggregate level and multiplies by the
sectoral sharing defined in `dfmap`. For a parameter ``\\bar{z}``,

```math
\\begin{aligned}
\\bar{z}_{yr,r,g} = \\sum_{gg} \\left( \\bar{z}_{yr,r,gg} \\cdot \\tilde{\\delta}_{yr,gg \\rightarrow g} \\right)
\\end{aligned}
```

where ``gg``, ``ss`` represent aggregate-level goods and sectors
and ``g``, ``s`` represent **dis**aggregate-level goods and sectors.

For parameters, such as sectoral output, ``ys_{yr,r,ss,gg}``, and intermediate demand,
``id_{yr,r,gg,ss}``, that depend on both goods and sectors,
[`SLiDE._compound_for`](@ref) is used to produce a compound disaggregation map.

```math
\\begin{aligned}
\\bar{id}_{yr,r,g,s} &= \\sum_{gg,ss} \\left( \\bar{id}_{yr,r,gg,ss} \\cdot \\tilde{\\delta}_{yr,gg \\rightarrow g,ss \\rightarrow s} \\right)
\\\\
\\bar{ys}_{yr,r,s,g} &= \\sum_{gg,ss} \\left( \\bar{ys}_{yr,r,ss,gg} \\cdot \\tilde{\\delta}_{yr,ss \\rightarrow s,gg \\rightarrow g} \\right)
\\end{aligned}
```

# Arguments
- `df::DataFrame`: parameter to share
- `dfmap::DataFrame`: sharing

# Keywords
- `scheme::Pair = :aggr=>:disagg`: columns in `dfmap` to **dis**aggregate from ``\\rightarrow`` to
- `key`: If a value is given, print a message indicating that `key` is being shared.

# Returns
- `df::DataFrame`: shared parameter
"""
function _disagg_sector_share(
    df::DataFrame,
    dfmap::DataFrame;
    scheme=:aggr=>:disagg,
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
    _disagg_sector_map(df::DataFrame, dfmap::DataFrame; kwargs...)
This function maps `df` from the aggregate to the disaggregate level such that all
disaggregate-level goods/sectors have the same value as at the aggregate-level.
For a parameter ``\\bar{z}``,

```math
\\bar{z}_{yr,r,g} = \\bar{z}_{yr,r,gg} \\circ map_{gg \\rightarrow g}
```

where ``gg``, ``ss`` represent aggregate-level goods and sectors
and ``g``, ``s`` represent **dis**aggregate-level goods and sectors.

# Arguments
- `df::DataFrame`: parameter to map
- `dfmap::DataFrame`: mapping ``map_{gg \\rightarrow g}`` or ``\\tilde{\\delta}_{yr,gg \\rightarrow g}``

# Keywords
- `scheme::Pair = :aggr=>:disagg`: columns in `dfmap` to **dis**aggregate from ``\\rightarrow`` to
- `key`: If a value is given, print a message indicating that `key` is being mapped.

# Returns
- `df::DataFrame`: mapped parameter
"""
function _disagg_sector_map(
    df::DataFrame,
    dfmap::DataFrame;
    scheme=:aggr=>:disagg,
    fun::Function=sum,
    key=missing,
)
    # !!!! Make general enough to reference here and when aggregating.
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
    _compound_for(df::DataFrame, col::AbstractArray; kwargs...)
This function produces a map to disaggregate parameters that include both goods
and sectors:

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

# Example

```jldoctest compound_for
julia> df = read_file(joinpath(SLIDE_DIR,"docs","src","assets","data","compound_for-sector_share.csv"))
3×4 DataFrame
│ Row │ yr    │ aggr   │ disagg  │ value    │
│     │ Int64 │ String │ String  │ Float64  │
├─────┼───────┼────────┼─────────┼──────────┤
│ 1   │ 2012  │ oil    │ oil     │ 1.0      │
│ 2   │ 2012  │ uti    │ ele_uti │ 0.787988 │
│ 3   │ 2012  │ uti    │ uti     │ 0.212012 │
```

First, multiply shares for all (``gg\\rightarrow g``,``ss\\rightarrow s``) combinations:

```julia
9×6 DataFrame
│ Row │ yr     │ aggr_g  │ disagg_g │ aggr_s  │ disagg_s │ value     │
│     │ Int64? │ String? │ String?  │ String? │ String?  │ Float64   │
├─────┼────────┼─────────┼──────────┼─────────┼──────────┼───────────┤
│ 1   │ 2012   │ oil     │ oil      │ oil     │ oil      │ 1.0       │
│ 2   │ 2012   │ oil     │ oil      │ uti     │ ele_uti  │ 0.787988  │
│ 3   │ 2012   │ oil     │ oil      │ uti     │ uti      │ 0.212012  │
│ 4   │ 2012   │ uti     │ ele_uti  │ oil     │ oil      │ 0.787988  │
│ 5   │ 2012   │ uti     │ ele_uti  │ uti     │ ele_uti  │ 0.620925  │
│ 6   │ 2012   │ uti     │ ele_uti  │ uti     │ uti      │ 0.167063  │
│ 7   │ 2012   │ uti     │ uti      │ oil     │ oil      │ 0.212012  │
│ 8   │ 2012   │ uti     │ uti      │ uti     │ ele_uti  │ 0.167063  │
│ 9   │ 2012   │ uti     │ uti      │ uti     │ uti      │ 0.0449492 │
```

Now, for `aggr_g==aggr_s`, sum all share values for `disagg_g==disagg_s` and drop values
if `disagg_g!=disagg_s`.

```julia
3×6 DataFrame
│ Row │ yr     │ aggr_g  │ disagg_g │ aggr_s  │ disagg_s │ value    │
│     │ Int64? │ String? │ String?  │ String? │ String?  │ Float64  │
├─────┼────────┼─────────┼──────────┼─────────┼──────────┼──────────┤
│ 1   │ 2012   │ oil     │ oil      │ oil     │ oil      │ 1.0      │
│ 2   │ 2012   │ uti     │ ele_uti  │ uti     │ ele_uti  │ 0.787988 │
│ 3   │ 2012   │ uti     │ uti      │ uti     │ uti      │ 0.212012 │
```

The resulting output is:

```jldoctest compound_for
julia> SLiDE._compound_for(df, [:g,:s])
7×6 DataFrame
│ Row │ yr     │ aggr_g  │ disagg_g │ aggr_s  │ disagg_s │ value    │
│     │ Int64? │ String? │ String?  │ String? │ String?  │ Float64  │
├─────┼────────┼─────────┼──────────┼─────────┼──────────┼──────────┤
│ 1   │ 2012   │ oil     │ oil      │ oil     │ oil      │ 1.0      │
│ 2   │ 2012   │ oil     │ oil      │ uti     │ ele_uti  │ 0.787988 │
│ 3   │ 2012   │ oil     │ oil      │ uti     │ uti      │ 0.212012 │
│ 4   │ 2012   │ uti     │ ele_uti  │ oil     │ oil      │ 0.787988 │
│ 5   │ 2012   │ uti     │ uti      │ oil     │ oil      │ 0.212012 │
│ 6   │ 2012   │ uti     │ ele_uti  │ uti     │ ele_uti  │ 0.787988 │
│ 7   │ 2012   │ uti     │ uti      │ uti     │ uti      │ 0.212012 │
```
"""
function _compound_for(df::DataFrame, col::AbstractArray; scheme=:aggr=>:disagg)
    # First, multiply shares for all (g,s) combinations. Drop input rows.
    df = _compound_all(df, col; scheme=scheme)
    df = _compound_sum(df, col; scheme=scheme)
end


function _compound_all(df::DataFrame, col::AbstractArray; scheme=:aggr=>:disagg)
    # First, multiply shares for all (g,s) combinations. Drop input rows.
    df = SLiDE._map_for(df, col; scheme=scheme)
    df[!,:value] .= prod.(eachrow(df[:,col]))
    df = select(df, Not(col))
    return df
end


function _compound_sum(df::DataFrame, col::AbstractArray; scheme=:aggr=>:disagg)
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

    return sort(vcat(df_same, df_diff), [from;to])
end



"""
"""
function _map_for(df::DataFrame, col::Array{Symbol,1}; scheme=:aggr=>:disagg)
    (from,to) = (scheme[1], scheme[2])

    # Are there any sector names already in df? If so, save this for renaming later.
    sec = intersect(SLiDE._find_sector(df), [from;to])

    if length(col) > 1
        df = indexjoin(fill(copy(df),length(col)); id=col, skipindex=[from,to])

        # If any sector names WERE overwritten, leave these alone and simply rename.
        # !!!! We COULD add the kwarg to indexjoin so "values" aren't what's being replaced by default.
        !isempty(sec) && (df = edit_with(df, Rename.(SLiDE._add_id.(sec,col), col)))
    else
        println("renaming only")
        !isempty(sec) && (df = edit_with(df, Rename.(sec,col)))
    end

    return df
end


"""
This function returns a list of sector indices found in the input DataFrame or list.
"""
_find_sector(col::Array{Symbol,1}) = intersect([:g,:s], col)
_find_sector(df::DataFrame) = _find_sector(propertynames(df))