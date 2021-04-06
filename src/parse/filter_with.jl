"""
    filter_with(df::DataFrame, set::Any; kwargs...)

# Arguments
- `df::DataFrame` to filter.
- `set::Dict` or `set::NamedTuple`: Values to keep in the DataFrame.

# Keywords
- `extrapolate::Bool = false`: Add missing regions/years to the DataFrame?
    If `extrapolate` is set to true, the following `kwargs` become relevant:
    - When extrapolating over years,
        - `backward::Bool = true`: Do we extrapolate backward in time?
        - `forward::Bool = true`: Do we extrapolate forward in time?
        Currently, "extrapolating" means copying the closest 
    - When extrapolating across regions,
        - `r::Pair = "md" => "dc"`: `Pair` indicating a region (`r.first`) to extrapolate to
            another region (`r.second`). A suggested regional extrapolation: MD data will be
            used to approximate DC data in the event that it is missing.
        - `overwrite::Bool = false`: If data in the target region `r.second` is already present,
            should it be overwritten?

# Returns
- `df::DataFrame` with only the desired keys.

# Examples

```jldoctest filter_with
julia> df = read_file(joinpath(SLIDE_DIR,"docs","src","assets","data","filter_use.csv"))
14×4 DataFrame
│ Row │ yr    │ i      │ j      │ value   │
│     │ Int64 │ String │ String │ Float64 │
├─────┼───────┼────────┼────────┼─────────┤
│ 1   │ 2015  │ agr    │ agr    │ 69.42   │
│ 2   │ 2015  │ agr    │ fbp    │ 277.179 │
│ 3   │ 2015  │ fbp    │ agr    │ 49.132  │
│ 4   │ 2015  │ fbp    │ fbp    │ 210.998 │
│ 5   │ 2015  │ uti    │ agr    │ 4.846   │
│ 6   │ 2015  │ uti    │ fbp    │ 10.102  │
│ 7   │ 2015  │ uti    │ uti    │ 35.093  │
│ 8   │ 2016  │ agr    │ agr    │ 60.197  │
│ 9   │ 2016  │ agr    │ fbp    │ 264.173 │
│ 10  │ 2016  │ fbp    │ agr    │ 47.739  │
│ 11  │ 2016  │ fbp    │ fbp    │ 205.21  │
│ 12  │ 2016  │ uti    │ agr    │ 4.548   │
│ 13  │ 2016  │ uti    │ fbp    │ 9.152   │
│ 14  │ 2016  │ uti    │ uti    │ 27.47   │

julia> df = filter_with(df, (i = ["agr","fbp"], j = ["agr","fbp"]))
8×4 DataFrame
│ Row │ yr    │ i      │ j      │ value   │
│     │ Int64 │ String │ String │ Float64 │
├─────┼───────┼────────┼────────┼─────────┤
│ 1   │ 2015  │ agr    │ agr    │ 69.42   │
│ 2   │ 2015  │ agr    │ fbp    │ 277.179 │
│ 3   │ 2015  │ fbp    │ agr    │ 49.132  │
│ 4   │ 2015  │ fbp    │ fbp    │ 210.998 │
│ 5   │ 2016  │ agr    │ agr    │ 60.197  │
│ 6   │ 2016  │ agr    │ fbp    │ 264.173 │
│ 7   │ 2016  │ fbp    │ agr    │ 47.739  │
│ 8   │ 2016  │ fbp    │ fbp    │ 205.21  │

julia> filter_with(df, (yr = 2016,); drop = true)
4×3 DataFrame
│ Row │ i      │ j      │ value   │
│     │ String │ String │ Float64 │
├─────┼────────┼────────┼─────────┤
│ 1   │ agr    │ agr    │ 60.197  │
│ 2   │ agr    │ fbp    │ 264.173 │
│ 3   │ fbp    │ agr    │ 47.739  │
│ 4   │ fbp    │ fbp    │ 205.21  │
```
"""
function filter_with(
    df::DataFrame,
    set::Any;
    drop = false,
    extrapolate::Bool = false,
    forward::Bool = true,
    backward::Bool = true,
    r::Pair = "md" => "dc",
    overwrite::Bool = false
)
    cols = propertynames(df)

    # Find keys that reference both column names in the input DataFrame df and
    # values in the set Dictionary. Then, created a DataFrame containing all permutations.
    df_set = _intersect_with(set, df; intersect_values=true)

    if df_set === nothing
        @warn("Returning unfiltered DataFrame.")
        return df
    end
        
    # Drop values that are not in the current set.
    idx_set = propertynames(df_set)
    df = innerjoin(df, df_set, on = idx_set)
    
    if extrapolate
        :yr in idx_set && (df = extrapolate_year(df, set; forward = forward, backward = backward))
        :r in idx_set  && (df = extrapolate_region(df, r; overwrite = overwrite))
    end

    # If one of the filtered DataFrame columns contains only one unique value, drop it.
    # If drop specifies columns to drop, drop only these IFF they contain one unique value.
    # NEVER drop units and never drop columns containing multiple unique values.
    if drop !== false
        idx_drop = setdiff(_find_constant(df[:,idx_set]), propertynames_with(df,:units))
        drop !== true && intersect!(idx_drop, ensurearray(drop))
        setdiff!(cols, idx_drop)
    end

    return sort(df[:,cols])
end


function filter_with(df::DataFrame, set::DataFrame; drop=false)
    idx_set = propertynames(set)
    df = indexjoin(df, set; kind=:inner)

    cols = propertynames(df)

    if drop !== false
        idx_drop = setdiff(_find_constant(df[:,idx_set]), propertynames_with(df,:units))
        drop !== true && intersect!(idx_drop, ensurearray(drop))
        setdiff!(cols, idx_drop)
    end

    return df[:,cols]
end


function filter_with(df::DataFrame, idx::InvertedIndex{DataFrame})
    idx = idx.skip
    on = intersect(propertynames(df), propertynames(idx))
    df = antijoin(df, idx, on=on)
    return df
end


function filter_with(df::DataFrame, x::InvertedIndex{Weighting})
    x = x.skip
    df_not = antijoin(df, x.data[:,[x.constant;x.from]],
        on=Pair.([x.constant;x.on],[x.constant;x.from]))
    return df_not
end


function filter_with(df::DataFrame, x::InvertedIndex{Mapping})
    x = x.skip
    df_not = antijoin(df, x.data[:,ensurearray(x.from)], on=Pair.(x.on,x.from))
    return df_not
end


"""
    split_with(df::DataFrame, splitter)
This function separates `df` into two DataFrames, `df_in` and `df_out`.

This is helpful for operating on a slice of `df` while saving the slice of `df` not included
in the operation.

# Arguments
- `df::DataFrame` to split
- `splitter::DataFrame` or `splitter::NamedTuple` containing indices of `df` to isolate

# Returns
- `df_in::DataFrame`: slice of `df` found in `splitter` by
    [`DataFrames.innerjoin`](https://dataframes.juliadata.org/stable/lib/functions/#DataFrames.innerjoin)
- `df_out::DataFrame`: slice of `df` **not** found in `splitter` by
    [`DataFrames.antijoin`](https://dataframes.juliadata.org/stable/lib/functions/#DataFrames.antijoin)
"""
function split_with(df::DataFrame, splitter::DataFrame; drop=false)
    idx_join = intersect(propertynames(df), propertynames(splitter))
    df_in = innerjoin(df, splitter, on=idx_join)
    df_out = antijoin(df, splitter, on=idx_join)

    # if drop !== false
    #     drop = idx_join
    # end
    # return drop_filter(df_in; drop=drop), drop_filter(df_out; drop=drop)
    return df_in, df_out
end

function split_with(df::DataFrame, splitter::NamedTuple; drop=false)
    return split_with(df, DataFrame(permute(splitter)); drop=drop)
end


# function drop_filter(df, col; drop=false)
#     if drop !== false
#         idx_drop = setdiff(SLiDE._find_constant(df[:,findindex(df)]), propertynames_with(df,:units))
#         drop !== true && intersect!(idx_drop, ensurearray(drop))
#         setdiff!(col, idx_drop)
#     end
#     return select(df, col)
# end

# drop_filter(df; drop=false) = drop_filter(df, propertynames(df); drop=drop)


"""
    split_fill_unstack(df::DataFrame, splitter, colkey, value)
This function prepares a slice of `df` for a calculation during which units are preserved by:

1. Splitting `df` with `splitter` using [`SLiDE.split_with`](@ref);
2. Filling zeros in `df_in` to prevent missing entries in the unstacked DataFrame.
    Approaching these steps in this order enables non-unique contents indicated by `colkey`;
    and
3. Unstacking `df_in`.

# Arguments
- `df::DataFrame` to stack
- `colkey::Symbol` or `colkey::Array{Symbol,1}`: variable column(s)
- `value::Symbol` or `value::Array{Symbol,1}`: value column(s)

# Returns
- `df_in::DataFrame`: slice of `df` found in `splitter`, unstacked and without missing values.
- `df_out::DataFrame`: slice of `df` **not** found in the DataFrame slice.
"""
function split_fill_unstack(
    df::DataFrame,
    splitter::DataFrame,
    colkey::Union{Symbol, Array{Symbol,1}},
    value::Union{Symbol, Array{Symbol,1}},
)
    df_in, df_out = split_with(df, splitter)
    
    df_in = fill_zero(df_in; with=splitter)
    # idx = findindex(df_in)
    # idx_split = findindex(splitter)
    # df_perm = crossjoin(permute(df_in[:,setdiff(idx,idx_split)]), splitter)
    # df_in = indexjoin(df_in, df_perm)
    
    df_in = _unstack(df_in, colkey, value)

    return df_in, df_out
end


function split_fill_unstack(
    df::DataFrame,
    splitter::NamedTuple,
    colkey::Union{Symbol, Array{Symbol,1}},
    value::Union{Symbol, Array{Symbol,1}},
)
    return split_fill_unstack(df, convert_type(DataFrame, splitter), colkey, value)
end


"""
    stack_append(df_wide::DataFrame, df_long::DataFrame, colkey, value)
This function prepares a slice of `df` for a calculation during which units are preserved by:

1. Stacking `df_wide` and
2. Concatening `df_wide` and `df_long`
    
# Arguments
- `df_wide::DataFrame` to stack
- `df_long::DataFrame` to append
- `colkey::Symbol` or `colkey::Array{Symbol,1}`: variable column(s)
- `value::Symbol` or `value::Array{Symbol,1}`: value column(s)

# Returns
- `df::DataFrame`
"""
function stack_append(
    df_wide::DataFrame,
    df_out::DataFrame,
    colkey::Union{Symbol, Array{Symbol,1}},
    value::Union{Symbol, Array{Symbol,1}};
    cols::Symbol=:intersect,
    ensure_finite::Bool=true,
)
    if ensure_finite
        inputs = propertynames_with(findvalue(df_wide),0)
        if !isempty(inputs)
            outputs = _remove_id.(inputs,0)
            for (inp,out) in zip(inputs,outputs)
                ii = .!isfinite.(df_wide[:,out])
                df_wide[ii,out] .= df_wide[ii,inp]
            end
        end
    end

    
    df_wide = _stack(df_wide, colkey, value)

    return vcat(df_wide, df_out; cols=cols)
end


"""
    extrapolate_year(df::DataFrame, yr::Array{Int64,1}; kwargs...)
    extrapolate_year(df::DataFrame, set::Any; kwargs...)

# Arguments
- `df::DataFrame` that might be in need of extrapolation.
- `yr::Array{Int64,1}`: List of years overwhich extrapolation is possible (depending on the kwargs)
- `set::Dict` or `set::NamedTuple` containing list of years, identified by the key `:yr`.

# Keywords
- `backward::Bool = true`: Do we extrapolate backward in time?
- `forward::Bool = true`: Do we extrapolate forward in time?

# Returns
- `df::DataFrame` extrapolated in time.

# Example
Continuing with the DataFrame from [`SLiDE.filter_with`](@ref),

```jldoctest extrapolate_year; setup = :(df = filter_with(read_file(joinpath(SLIDE_DIR,"docs","src","assets","data","filter_use.csv")), (i = ["agr","fbp"], j = ["agr","fbp"])))
julia> df
8×4 DataFrame
│ Row │ yr    │ i      │ j      │ value   │
│     │ Int64 │ String │ String │ Float64 │
├─────┼───────┼────────┼────────┼─────────┤
│ 1   │ 2015  │ agr    │ agr    │ 69.42   │
│ 2   │ 2015  │ agr    │ fbp    │ 277.179 │
│ 3   │ 2015  │ fbp    │ agr    │ 49.132  │
│ 4   │ 2015  │ fbp    │ fbp    │ 210.998 │
│ 5   │ 2016  │ agr    │ agr    │ 60.197  │
│ 6   │ 2016  │ agr    │ fbp    │ 264.173 │
│ 7   │ 2016  │ fbp    │ agr    │ 47.739  │
│ 8   │ 2016  │ fbp    │ fbp    │ 205.21  │

julia> extrapolate_year(df, Dict(:yr => 2014:2017))
16×4 DataFrame
│ Row │ yr    │ i      │ j      │ value   │
│     │ Int64 │ String │ String │ Float64 │
├─────┼───────┼────────┼────────┼─────────┤
│ 1   │ 2014  │ agr    │ agr    │ 69.42   │
│ 2   │ 2014  │ agr    │ fbp    │ 277.179 │
│ 3   │ 2014  │ fbp    │ agr    │ 49.132  │
│ 4   │ 2014  │ fbp    │ fbp    │ 210.998 │
│ 5   │ 2015  │ agr    │ agr    │ 69.42   │
│ 6   │ 2015  │ agr    │ fbp    │ 277.179 │
│ 7   │ 2015  │ fbp    │ agr    │ 49.132  │
│ 8   │ 2015  │ fbp    │ fbp    │ 210.998 │
│ 9   │ 2016  │ agr    │ agr    │ 60.197  │
│ 10  │ 2016  │ agr    │ fbp    │ 264.173 │
│ 11  │ 2016  │ fbp    │ agr    │ 47.739  │
│ 12  │ 2016  │ fbp    │ fbp    │ 205.21  │
│ 13  │ 2017  │ agr    │ agr    │ 60.197  │
│ 14  │ 2017  │ agr    │ fbp    │ 264.173 │
│ 15  │ 2017  │ fbp    │ agr    │ 47.739  │
│ 16  │ 2017  │ fbp    │ fbp    │ 205.21  │
```
"""
function extrapolate_year(
    df::DataFrame,
    yr::AbstractArray;
    backward::Bool = true,
    forward::Bool = true
)
    df = copy(df)
    yr_diff = setdiff(yr, unique(df[:,:yr]))
    length(yr_diff) == 0 && (return df)
    
    cols = setdiff(propertynames(df), [:yr])
    cols_ans = propertynames(df)

    df_ext = []

    if backward
        yr_min = minimum(df[:,:yr])
        df_min = filter_with(df, (yr = yr_min,))[:,cols]

        yr_back = yr_diff[yr_diff .< yr_min]
        df_back = crossjoin(DataFrame(yr = yr_back), df_min)[:,cols_ans]

        push!(df_ext, df_back)
    end
    
    if forward
        yr_max = maximum(df[:,:yr])
        df_max = filter_with(df, (yr = yr_max,))[:,cols]

        yr_forward = yr_diff[yr_diff .> yr_max]
        df_forward = crossjoin(DataFrame(yr = yr_forward), df_max)[:,cols_ans]

        push!(df_ext, df_forward)
    end
    return sort([df_ext...; df])
end


function extrapolate_year(df::DataFrame, set; backward::Bool=true, forward::Bool=true)
    extrapolate_year(df, set[:yr]; forward = forward, backward = backward)
end


"""
"""
function extend_year(df::DataFrame, mapping::DataFrame)
    col = propertynames(df)
    df = edit_with(outerjoin(mapping, df, on=Pair(:y,:yr)), Rename(:x,:yr))
    return df[:,col]
end

function extend_year(df::DataFrame, yr::AbstractArray)
    years = unique(df[:,:yr])
    df = extend_year(df, map_step(yr, years))
    return df
end

extend_year(df::DataFrame, set::Dict) = extend_year(df, set[:yr])


"""
This function returns a DataFrame defining mapping for a step function.

# Keywords
- `fun::Function`: how to pick the cut-off boundary. By default, this is set to occur
    between to values. For example, this would result in using 2007 data for years <= 2009
    and 2012 data for years >= 2009.

# Returns


# Example

```jldoctest map_year
julia> map_year([2007,2012] => 2005:2015)
11×2 DataFrame
│ Row │ from  │ to    │
│     │ Int64 │ Int64 │
├─────┼───────┼───────┤
│ 1   │ 2007  │ 2005  │
│ 2   │ 2007  │ 2006  │
│ 3   │ 2007  │ 2007  │
│ 4   │ 2007  │ 2008  │
│ 5   │ 2007  │ 2009  │
│ 6   │ 2012  │ 2010  │
│ 7   │ 2012  │ 2011  │
│ 8   │ 2012  │ 2012  │
│ 9   │ 2012  │ 2013  │
│ 10  │ 2012  │ 2014  │
│ 11  │ 2012  │ 2015  │
```
"""
function map_year(from::AbstractArray, to::AbstractArray; fun=Statistics.mean, extrapolate=true)

    if !extrapolate
        to = intersect(ensurearray(to), intersect(from))
        isempty(to) && (return DataFrame())
    end
    
    rng = DataFrame(low=from[1:end-1], high=from[2:end])
    rng[!,:mid] = fun.(eachrow(rng))

    df = crossjoin(DataFrame(to=to), rng)
    df[!,:diff] .= df[:,:to].-df[:,:mid]

    df[!,:from] .= df[:,:low].*(df[:,:diff].<0) + df[:,:high].*(df[:,:diff].>0)
    df[!,:dist] .= abs.(df[:,:diff])

    df = unique(df[:,[:from,:to,:dist]])

    df_closest = combine_over(df, :from; fun=Statistics.minimum)
    df = innerjoin(df, df_closest, on=[:to,:dist])[:,[:from,:to]]
    return df
end

function map_year(from::AbstractArray, to::Integer; fun=Statistics.mean, extrapolate=true)
    df = DataFrame(to=to)

    df[!,:from] .= if to in from;         to
    elseif to > from[end] && extrapolate; from[end]
    elseif to < from[1]   && extrapolate; from[1]
    end

    return df[:,[:from,:to]]
end

function map_year(scheme::Pair; fun=Statistics.mean, extrapolate=true)
    return map_year(scheme[1], scheme[2]; fun=fun, extrapolate=extrapolate)
end

function map_year(df::DataFrame, x; extrapolate=true)
    dfmap = map_year(unique(df[:,:yr]), x; extrapolate=extrapolate)
    df = edit_with(df, Map(dfmap,[:from],[:to],[:yr],[:yr],:outer))
    return df
end


"""
    extrapolate_region(df::DataFrame; kwargs...)
    extrapolate_region(df::DataFrame, r::Pair; kwargs...)

Fills in missing data in the input DataFrame `df` by filling it with existing information in
`df`. Here, "extrapolate" makes a direct copy of the data.

# Arguments
- `df::DataFrame` that might be in need of extrapolation.
- `r::Pair = "md" => "dc"`: `Pair` indicating a region (`r.first`) to extrapolate to another
    region (`r.second`). A suggested regional extrapolation: MD data will be used to
    approximate DC data in the event that it is missing. To fill multiple regions with data,
    use "md" => ["dc","va"].

# Keyword Argument:
- `overwrite::Bool = false`: If data in the target region `r.second` is already present,
    should it be overwritten?

# Returns
- `df::DataFrame` extrapolated in region.

# Example

```jldoctest extrapolate_region
julia> df = read_file(joinpath(SLIDE_DIR,"docs","src","assets","data","filter_utd.csv"))
8×5 DataFrame
│ Row │ yr    │ r      │ s      │ t       │ value     │
│     │ Int64 │ String │ String │ String  │ Float64   │
├─────┼───────┼────────┼────────┼─────────┼───────────┤
│ 1   │ 2015  │ md     │ agr    │ exports │ 0.0390152 │
│ 2   │ 2015  │ md     │ agr    │ imports │ 0.778159  │
│ 3   │ 2015  │ va     │ agr    │ exports │ 1.11601   │
│ 4   │ 2015  │ va     │ agr    │ imports │ 0.88253   │
│ 5   │ 2016  │ md     │ agr    │ exports │ 0.0330508 │
│ 6   │ 2016  │ md     │ agr    │ imports │ 0.762089  │
│ 7   │ 2016  │ va     │ agr    │ exports │ 1.16253   │
│ 8   │ 2016  │ va     │ agr    │ imports │ 0.86741   │

julia> extrapolate_region(df)
12×5 DataFrame
│ Row │ r      │ yr    │ s      │ t       │ value     │
│     │ String │ Int64 │ String │ String  │ Float64   │
├─────┼────────┼───────┼────────┼─────────┼───────────┤
│ 1   │ dc     │ 2015  │ agr    │ exports │ 0.0390152 │
│ 2   │ dc     │ 2015  │ agr    │ imports │ 0.778159  │
│ 3   │ dc     │ 2016  │ agr    │ exports │ 0.0330508 │
│ 4   │ dc     │ 2016  │ agr    │ imports │ 0.762089  │
│ 5   │ md     │ 2015  │ agr    │ exports │ 0.0390152 │
│ 6   │ md     │ 2015  │ agr    │ imports │ 0.778159  │
│ 7   │ md     │ 2016  │ agr    │ exports │ 0.0330508 │
│ 8   │ md     │ 2016  │ agr    │ imports │ 0.762089  │
│ 9   │ va     │ 2015  │ agr    │ exports │ 1.11601   │
│ 10  │ va     │ 2015  │ agr    │ imports │ 0.88253   │
│ 11  │ va     │ 2016  │ agr    │ exports │ 1.16253   │
│ 12  │ va     │ 2016  │ agr    │ imports │ 0.86741   │
```

If we instead want to copy VA data into DC, specify:

```jldoctest extrapolate_region
julia> extrapolate_region(df, "va" => "dc")
12×5 DataFrame
│ Row │ r      │ yr    │ s      │ t       │ value     │
│     │ String │ Int64 │ String │ String  │ Float64   │
├─────┼────────┼───────┼────────┼─────────┼───────────┤
│ 1   │ dc     │ 2015  │ agr    │ exports │ 1.11601   │
│ 2   │ dc     │ 2015  │ agr    │ imports │ 0.88253   │
│ 3   │ dc     │ 2016  │ agr    │ exports │ 1.16253   │
│ 4   │ dc     │ 2016  │ agr    │ imports │ 0.86741   │
│ 5   │ md     │ 2015  │ agr    │ exports │ 0.0390152 │
│ 6   │ md     │ 2015  │ agr    │ imports │ 0.778159  │
│ 7   │ md     │ 2016  │ agr    │ exports │ 0.0330508 │
│ 8   │ md     │ 2016  │ agr    │ imports │ 0.762089  │
│ 9   │ va     │ 2015  │ agr    │ exports │ 1.11601   │
│ 10  │ va     │ 2015  │ agr    │ imports │ 0.88253   │
│ 11  │ va     │ 2016  │ agr    │ exports │ 1.16253   │
│ 12  │ va     │ 2016  │ agr    │ imports │ 0.86741   │
```
"""
function extrapolate_region(df::DataFrame, r::Pair = "md" => "dc"; overwrite = false)
    df = copy(df)
    if !overwrite
        r = r.first => setdiff(ensurearray(r.second), unique(df[:,:r]))
        length(r.second) == 0 && (return df)
    else
        df = edit_with(df, Drop.(:r, r.second, "=="))
    end
    
    cols = setdiff(propertynames(df), [:r])
    df_close = crossjoin(DataFrame(r = r.second), filter_with(df, (r = r.first,))[:,cols])
    
    return sort([df_close; df])
end


"""
"""
function _intersect_with(
    x::Union{Dict,NamedTuple},
    df::DataFrame;
    intersect_values::Bool=false
)
    T = typeof(x)
    idx = intersect(findindex(df), collect(keys(x)))

    if isempty(idx)
        @error("Cannot overlap input $T and DataFrame. No overlapping keys/columns.")
        return nothing
    end

    val = [intersect_values ? intersect(unique(df[:,k]), ensurearray(x[k])) : x[k] for k in idx]

    ii = .!isempty.(val)

    if any(.!ii)
        idx_drop = idx[.!ii]
        @warn("No overlapping values in $idx_drop. These will be removed.")
        idx = idx[ii]
        val = val[ii]

        if isempty(idx)
            @error("Cannot overlap input $T and DataFrame. No overlapping values.")
            return nothing
        end
    end
    return DataFrame(permute(NamedTuple{Tuple(idx,)}(val,)))
end


"""
"""
function _find_constant(df::DataFrame)
    idx = findindex(df)
    return idx[nunique(df[:,idx]) .== 1]
end

_find_constant(row::DataFrameRow) = nunique(row)==1


"""
    dropzero!(df::DataFrame, x::Float64)
Removes values `x` in columns of type AbstractFloat from `df`.
"""
function dropvalue!(df::DataFrame, x::Float64)
    cols = find_oftype(df, typeof(x));
    if isnan(x); [filter!(row -> .!isnan.(row[col]), df) for col in cols]
    else;        [filter!(row -> row[col] .!== x, df) for col in cols]
    end
    return df
end

dropvalue(df::DataFrame, x::Float64) = dropvalue!(copy(df), x)


"""
    dropzero!(df::DataFrame)
Removes zero values in columns of type AbstractFloat from `df`
"""
dropzero!(df::DataFrame) = dropvalue!(dropvalue!(df, 0.0), -0.0)
dropzero(df::DataFrame) = dropzero!(copy(df))


"""
    dropnan!(df::DataFrame)
Removes `NaN` values in columns of type AbstractFloat from `df`
"""
dropnan!(df::DataFrame) = dropvalue!(df, NaN)
dropnan(df::DataFrame) = dropnan!(copy(df))


"""
"""
function getzero(df; digits=false)
    digits!==false && (df = SLiDE.round!(copy(df), digits=digits))
    return df[df[:,:value].==0.0, 1:end-1]
end


# """
# """
# function drop_small(df, col; digits=5)
#     df = drop_small_average(df, col; digits=digits)
#     df = drop_small_value(df; digits=digits*2)
#     return df
# end


# """
# """
# function drop_small_average(df, col; digits=5)
#     idx = df / combine_over(df, col; fun=Statistics.mean, digits=false)
#     idx = getzero(idx; digits=digits)
#     return filter_with(df, Not(idx))
# end


# """
# """
# drop_small_value(df; digits=7) = dropzero(SLiDE.round!(df; digits=digits))