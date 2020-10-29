"""
    indexjoin(df::DataFrame...; kwargs)
    indexjoin(df::Array{DataFrame,1}; kwargs)

This function joins input DataFrames on their index columns (ones that are not filled with 
`AbstractFloat` or `Bool` DataTypes)

# Argument
- `df::DataFrame...` to joins

# Keywords
- `valnames::Array{Symbol,1}`: names of output value columns.
- `indicator::Array{Any,1}`: prefix to add to DataFrame value names.
"""
function indexjoin(df::Array{DataFrame,1};
    indicator = missing,
    valnames = missing,
    fillmissing = 0.0,
    mark_source::Bool = false,
    )

    if indicator === missing && mark_source
        @warn("Cannot mark source dataframe in indexjoin unless an indicator is specified.")
        mark_source = false
    end

    df = df[.!isempty.(df)]
    N = length(df)

    val = findvalue.(df)
    idx = findindex.(df)

    if valnames === missing
        indicator === missing && (indicator = _generate_indicator(N))
        valnames = broadcast.(Symbol, Symbol.(indicator, :_), val)
    end
    valnames = ensurearray.(valnames)

    editor = [Rename.(val[ii], valnames[ii]) for ii in 1:N]
    mark_source && (editor = [[Add(indicator[ii], true); editor[ii]] for ii in 1:N])

    [df[ii] = edit_with(df[ii], editor[ii]) for ii in 1:N]
    df_ans = copy(df[1])

    for ii in 2:N
        cols = intersect(propertynames(df_ans), idx[ii])

        df_ans = if length(cols) == 0
            crossjoin(df_ans, df[ii])
        else
            outerjoin(df_ans, df[ii], on=cols)
        end
    end

    idx = unique(collect(Iterators.flatten(idx)))
    valnames = collect(Iterators.flatten(valnames))
    
    # Handle missing keys.
    if fillmissing !== false
        df_ans = edit_with(df_ans, Replace.(valnames, missing, fillmissing))
    end
    
    if mark_source
        df_ans = edit_with(df_ans, Replace.(indicator, missing, false))
        append!(valnames, indicator)
    end
    return select!(df_ans, [idx; valnames])
end


function indexjoin(df::Vararg{DataFrame};
    indicator = missing,
    valnames = missing,
    fillmissing = 0.0
)
    return indexjoin(ensurearray(df);
        indicator = indicator,
        valnames = valnames,
        fillmissing = fillmissing
    )
end

_generate_indicator(N::Int) = Symbol.(:df, 1:N)