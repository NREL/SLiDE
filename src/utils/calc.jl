import Base


"""
    Base.:/(df1::DataFrame, df2::DataFrame)
Extends / to operate on 2 DataFrames, each with one column of AbstractFloat type.
The operation will join the DataFrames on their descriptive columns to ensure the operation
is performed for related values. Values that are "missing" after joining are set to 0.
"""
function Base.:/(df1::DataFrame, df2::DataFrame)
    df = indexjoin(copy.([df1,df2]))
    out = findvalue(df)

    df[!,:value] .= df[:, out[1]] ./ df[:, out[2]]

    return df[:, unique([setdiff(propertynames(df),out);:value])]
end


"""
    Base.:+(df::Vararg{DataFrame})
Extends + to operate on 2+ DataFrames, each with one column of AbstractFloat type.
The operation will join the DataFrames on their descriptive columns to ensure the operation
is performed for related values. Values that are "missing" after joining are set to 0.
"""
function Base.:+(df::Vararg{DataFrame})
    N = length(df)

    if length(findvalue.(df)) > N
        @error("Can only add DataFrames with one value column EACH.")
    end

    df = indexjoin(ensurearray(df))
    out = findvalue(df)

    df[!,:value] .= df[:, out[1]];
    [df[!,:value] += df[:, out[ii]] for ii in 2:N]

    return df[:, unique([setdiff(propertynames(df),out);:value])]
end


"""
    Base.:-(df::Vararg{DataFrame})
Extends - to operate on 2+ DataFrames, each with one column of AbstractFloat type.
The operation will join the DataFrames on their descriptive columns to ensure the operation
is performed for related values. Values that are "missing" after joining are set to 0.
"""
function Base.:-(df::Vararg{DataFrame})
    N = length(df)

    if length(findvalue.(df)) > N
        @error("Can only subtract DataFrames with one value column EACH.")
    end

    df = indexjoin(ensurearray(df))
    out = findvalue(df)

    df[!,:value] .= df[:, out[1]];
    [df[!,:value] -= df[:, out[ii]] for ii in 2:N]

    return df[:, unique([setdiff(propertynames(df),out);:value])]
end


"""
    Base.:*(df::Vararg{DataFrame})
Extends * to operate on 2+ DataFrames, each with one column of AbstractFloat type.
The operation will join the DataFrames on their descriptive columns to ensure the operation
is performed for related values. Values that are "missing" after joining are set to 0.
"""
function Base.:*(df::Vararg{DataFrame})
    N = length(df)

    if length(findvalue.(df)) > N
        @error("Can only multiply DataFrames with one value column EACH.")
    end

    df = indexjoin(ensurearray(df))
    out = findvalue(df)

    df[!,:value] .= df[:, out[1]];
    [df[!,:value] .*= df[:, out[ii]] for ii in 2:N]

    return df[:, unique([setdiff(propertynames(df),out);:value])]
end


"""
    combine_over(df::DataFrame, col::Array{Symbol,1}; operation::Function = sum)
    combine_over(df::DataFrame, col::Symbol; operation::Function = sum)
This function applies [`combine`](https://juliadata.github.io/DataFrames.jl/stable/lib/functions/#DataFrames.combine)
to the input DataFrame `df` over the input column(s) `col`.

# Arguments
- `df::DataFrame`: DataFrame on which to operate.
- `col::Symbol` or `col::Array{Symbol,1}`: column(s) over which to operate.

# Keywords
- `operation::Function=sum`: Operation to perform over the DataFrame columns. By default,
    the function will return a summation. Other standard summary functions include: `sum`,
    `prod`, `minimum`, `maximum`, `mean`, `var`, `std`, `first`, `last` and `length`.

# Returns
- `df::DataFrame` WITHOUT the specified column(s) argument. The resulting DataFrame will be
    'shorter' than the input DataFrame.
"""
function combine_over(df::DataFrame, col::Array{Symbol,1}; fun::Function=sum, kwargs...)
    val = findvalue(df)

    if !isempty(val)
        idx = setdiff(propertynames(df), [col; val])    
        df = combine(groupby(df, idx), val .=> fun .=> val)
        round!(df; kwargs...)
    end
    
    return df
end

combine_over(df, col::Symbol; kwargs...) = combine_over(df, ensurearray(col); kwargs...)

combine_over(df, col::Any) = df


"""
    transform_over(df::DataFrame, col::Array{Symbol,1}; operation::Function = sum)
    transform_over(df::DataFrame, col::Symbol; operation::Function = sum)
This function applies [`transform`](https://juliadata.github.io/DataFrames.jl/stable/lib/functions/#DataFrames.transform)
to the input DataFrame `df` over the input column(s) `col`.

# Arguments
- `df::DataFrame`: DataFrame on which to operate.
- `col::Symbol` or `col::Array{Symbol,1}`: column(s) over which to operate.

# Keywords
- `operation::Function=sum`: Operation to perform over the DataFrame columns. By default,
    the function will return a summation. Other standard summary functions include: `sum`,
    `prod`, `minimum`, `maximum`, `mean`, `var`, `std`, `first`, `last` and `length`.

# Returns
- `df::DataFrame` WITH the specified column(s) argument. The resulting DataFrame will be
    the same length as the input DataFrame.
"""
function transform_over(df::DataFrame, col::Array{Symbol,1}; fun::Function=sum, kwargs...)
    cols = propertynames(df)
    val = findvalue(df)
    idx = setdiff(propertynames(df), [col; val])

    df = transform(groupby(df, idx), val .=> fun .=> val)

    return round!(select(df, cols); kwargs...)
end

transform_over(df, col::Symbol; kwargs...) = transform_over(df, ensurearray(col); kwargs...)

transform_over(df, col::Any) = df


"""
Round either the specified columns or all columns of type `AbstractFloat` to the specified
number of digits.

# Arguments
- `df::DataFrame` of values in need of rounding
- `col::Symbol` or `col::Array{Symbol,1}` to round. If no columns are specified,
    all columns of type `AbstractFloat` will be rounded.

# Keywords
- `digits::Int=10`: Number of decimal places to keep when rounding
"""
function round!(df::DataFrame, col::Union{Symbol,Vector{Symbol}}; digits=DEFAULT_ROUND_DIGITS)
    if digits!==false && !isempty([col;])
        df[!,col] .= round.(df[:,col]; digits=digits)
    end
    return df
end

round!(df; kwargs...) = round!(df, find_oftype(df, AbstractFloat); kwargs...)


"""
"""
function operate_over(df::Vararg{DataFrame};
    id=[]=>[],
    units::DataFrame=DataFrame(),
    copyinput::Bool=false,
    fillmissing=1.0,
    # fillmissing::Bool=true,
)
    # df = ensurearray(df)
    # idx = findindex.(df)
    # idx_all = setdiff(union(idx...), [:units])

    # with = permute(dropmissing(vcat(df...; cols=:union)[:,idx_all]))
    # diff = [setdiff(idx_all, idx[ii]) for ii in 1:length(idx)]

    # df = [isempty(diff[ii]) ? df[ii] : crossjoin(df[ii], unique(with[:,diff[ii]]))
    #     for ii in 1:length(df)]
    df = indexjoin(df...; id=id[1], fillmissing=fillmissing, skipindex=:units, kind=:left)

    # df = df[:, [idx_all; propertynames_with(df,:units); findvalue(df)]]

    return operate_over(df; id=id, units=units, copyinput=copyinput, fillmissing=fillmissing)
end


function operate_over(df::DataFrame;
    id=[]=>[],
    units::DataFrame=DataFrame(),
    copyinput::Bool=false,
    fillmissing=1.0,
    # fillmissing::Bool=true,
)
    if !isempty(units)
        df = _join_units(df, units, id; copyinput=copyinput, fillmissing=fillmissing)
    end
    return df
end


"""
"""
function _join_units(
    df::DataFrame,
    units::DataFrame,
    id;
    copyinput::Bool=false,
    fillmissing=1.0,
)
    on = :units

    utx = _add_id.(on, id[1]) => _add_id(on, id[2])
    idx_units = propertynames_with(units, on)[1:length(id[1])]

    # If we might be performing a calculation that will replace an existing output,
    # append that input with 0.
    if copyinput
        id[2] in propertynames(df)  && (df[!,append(id[2],0)] .= df[:,id[2]])
        utx[2] in propertynames(df) && (df[!,append(utx[2],0)] .= df[:,utx[2]])
    end
    
    df = leftjoin(df, units, on=Pair.(utx[1], idx_units))
    
    # Check for missing values and fill these if they are found.
    # Do not fill anything in the "operation" column to return this indicator that the join
    # was incomplete.
    ii = ismissing.(df[:, :operation])

    if any(ii)
        df[!,:complete] .= .!ii

        if !isempty(intersect(id[1], [id[2]]))
            df[!, :value] .= df[:,id[2]] .* ii
        end

        if fillmissing !== false
            df[ii,:factor] = fillmissing
            df[ii,:units] = df[ii,utx[2]]
        end
    end
    return df
end