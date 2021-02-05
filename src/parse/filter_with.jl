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
    yr::Array{Int64,1};
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


function extrapolate_year(
    df::DataFrame,
    set;
    backward::Bool = true,
    forward::Bool = true
)
    extrapolate_year(df, set[:yr]; forward = forward, backward = backward)
end


function extrapolate_year(
    df::DataFrame,
    yr::UnitRange{Int64};
    backward::Bool = true,
    forward::Bool = true
)
    extrapolate_year(df, ensurearray(yr); forward = forward, backward = backward)
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
    return idx[length.(unique.(eachcol(df[:,idx]))) .== 1]
end


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