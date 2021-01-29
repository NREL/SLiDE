"""
    fill_zero(keys_unique::NamedTuple; value_colnames)
    fill_zero(keys_unique::NamedTuple, df::DataFrame)
    fill_zero(df::DataFrame...)
    fill_zero(d::Dict...)
    fill_zero(keys_unique, d::Dict)

This function can be used to fill zeros in either a dictionary or DataFrame.
- Options for dictionary editing:
    - If only (a) dictionary/ies is/are input, the dictionaries will be edited such that
        they all contain all permutations of their key values. All dictionaries in a
        resultant list of dictionaries will be the same length.
    - If a dictionary is input with a list of keys, it will be edited to ensure that it
        includes all permutations.
    - If only a list of keys is input, a new dictionary will be created, containing all key
        permutations with values initialized to zero.
- Options for DataFrame editing:
    - If only (a) DataFrame(s) is/are input, the DataFrame(s) will be edited such that
        they all contain all permutations of their key values. All DataFrames in a
        resultant list of DataFrames will be the same length.
    - If a DataFrame is input with a NamedTuple, it will be edited to ensure that it
        includes all permutations of the NamedTuple's values.
    - If only a NamedTuple is input, a new DataFrame will be created, containing all key
        permutations with values initialized to zero.

# Arguments
- `keys_unique::Tuple`: A list of arrays whose permutations should be included in the
    resultant dictionary.
- `keys_unique::NamedTuple`: A list of arrays whose permutations should be included in the
    resultant dictionary. The NamedTuple's keys correspond to the DataFrame columns where
    they will be stored.
- `d::Dict...`: The dictionary/ies to edit.
- `df::DataFrame...`: The DataFrame(s) to edit.

# Keywords
- `value_colnames::Any = :value`: "value" column labels to add and set to zero when creating
    a new DataFrame. Default is `:value`.

# Returns
- `d::Dict...` if input included dictionaries and/or Tuples
- `df::DataFrame...` if input included DataFrames and/or NamedTuples
"""
function fill_zero(keys_fill::NamedTuple; value_colnames=:value)
    df_fill = DataFrame(permute(keys_fill))
    return edit_with(df_fill, Add.(convert_type.(Symbol, value_colnames), 0.))
end


function fill_zero(keys_fill::Any; permute_keys::Bool=true)
    permute_keys && (keys_fill = permute(keys_fill))
    return Dict(k => 0. for k in keys_fill)
end


function fill_zero(keys_fill::Vararg{Any}; permute_keys::Bool=true)
    permute_keys && (keys_fill = permute(keys_fill))
    return Dict(k => 0. for k in keys_fill)
end


# ----- EDIT EXISTING ----------------------------------------------------------------------


function fill_zero(
    df::Vararg{DataFrame};
    permute_keys::Bool=false,
    colnames=[],
    with::Union{Dict,NamedTuple}=Dict(),
)
    df = ensurearray(df)
    N = length(df)

    id = _generate_id(N)
    idx = findindex.(df)
    to = findvalue.(df)

    df = indexjoin(df)
    df = fill_zero(df; permute_keys=permute_keys, colnames=colnames, with=with)
    from = [propertynames_with(df, k) for k in id]

    df = [edit_with(df[:,[idx[ii];from[ii]]], Rename.(from[ii], to[ii])) for ii in 1:N]

    return Tuple(df)
end


function fill_zero(
    df::DataFrame;
    permute_keys::Bool=true,
    colnames=[],
    with::Any=Dict(),
)
    idx = findindex(df)

    !isempty(colnames) && intersect!(idx, ensurearray(colnames))

    df = _fill_zero_with(df, with; permute_keys=permute_keys)

    return df
end


function fill_zero(d::Vararg{Dict}; permute_keys::Bool=true)
    d = copy.(ensurearray(d))
    # Find all keys present in the input dictionary/ies and ensure all are present.
    keys_fill = unique([collect.(keys.(d))...;])
    d = [fill_zero(keys_fill, x; permute_keys=permute_keys) for x in d]
    return length(d) == 1 ? d[1] : Tuple(d)
end


# ----- GIVEN SET LIST ---------------------------------------------------------------------

function fill_zero(keys_fill::NamedTuple, df::DataFrame)
    @warn("Depreciated!")
    df = copy(df)
    df_fill = fill_zero(keys_fill)
    df = fill_zero(df, df_fill; permute_keys=false)[1]
    return df
end


function fill_zero(set::Dict, df::DataFrame)
    @warn("Depreciated!")
    idx = intersect(findindex(df), collect(keys(set)))
    val = [set[k] for k in idx]
    return fill_zero(NamedTuple{Tuple(idx, )}(val, ), df)
end


function fill_zero(keys_fill::Any, d::Dict; permute_keys::Bool=true)
    @warn("Depreciated!")
    d = copy(d)
    # If permuting keys, find all possible permutations of keys that should be present
    # and determine which are missing. Then add missing keys to the dictionary and return.
    permute_keys && (keys_fill = permute(keys_fill))
    keys_missing = setdiff(keys_fill, collect(keys(d)))

    [push!(d, k => 0.) for k in keys_missing]
    return d
end


"""
Initialize a new DataFrame and fills it with the specified input value.
"""
function fill_with(keys_fill::NamedTuple, value::Any; value_colnames=:value)
    df = fill_zero(keys_fill; value_colnames=value_colnames)
    df = edit_with(df, Replace.(value_colnames, 0.0, value))
    return df
end


"""
    permute(x::Any)
    permute(x...)

# Arguments
- `x::Any`: input data to permute

# Returns
All possible permutations of the input values. 
    - `x::DataFrame` or `x::NamedTuple`: Input type and key/column names will be preserved.
    - Given any other input `x`,
        - `x::Array{Tuple,1}` of the possible combinations of the input data.
            Each tuple will be ordered in the same way the input data was ordered.
        - `x::Any`: If `x` does not contain multiple sets to permute, `permute` will return
            `x`, unchanged.
"""
function permute(df::DataFrame)
    idx = propertynames(df)
    val = DataFrame(permute(unique.(eachcol(df))))
    return edit_with(val, Rename.(propertynames(val), idx))
end

function permute(x::NamedTuple)
    idx = keys(x)
    val = eachcol(DataFrame(ensuretuple.(permute(values(x)))))
    return NamedTuple{Tuple(idx, )}(val, )
end

permute(x::Any) = any(isarray.(x)) ? permute(ensurearray.(x)...) : x
permute(x::Vararg{Any}) = vec(collect(Iterators.product(x...)))


"""
    _fill_zero_with(df::DataFrame, with; kwargs...)
This function fills zeros in `df` given a slice of keys/values that must be filled.

# Arguments
- `df::DataFrame` to fill
- `with`: Type indicating which `df` must be represented in `df`
    - `with::Dict` or `with::NamedTuple`: find keys also represented in `df` columns and
        fill `df` with all permutations of these values
    - `with::DataFrame`: fill `df`, including all columns/values in `with`.

# Keywords
- `permute_keys::Bool=true`: Should we permute `df` indices **not** included in `with`?

# Returns
- `df::DataFrame` with zeros filled.
"""
function _fill_zero_with(df::DataFrame, with::Any;
    permute_keys::Bool=true,
)
    if !isempty(with)
        df = indexjoin(df, _intersect_with(with, df))
    elseif permute_keys
        idx = findindex(df)
        df = indexjoin(permute(df[:,idx]), df)
    end
    
    return df
end


function _fill_zero_with(df::DataFrame, with::DataFrame;
    permute_keys::Bool=true,
)
    df = indexjoin(_permute_unique(df; permute_keys=permute_keys, with=with), df)
    
    return df
end


"""
    _permute_unique(df::DataFrame; kwargs...)
This function returns an index of `df` where only unique columns are permuted.

# Arguments
- `df::DataFrame` to permute

# Keywords
- `permute_keys::Bool=true`: Should we permute non-duplcate `df` indices?
- `with::DataFrame=DataFrame()`: Index slice that must be completely represented in the
    permutation.

# Returns
- `df::DataFrame` of **index** columns (not including values), as indicated by keywords
"""
function _permute_unique(df::DataFrame; permute_keys::Bool=true, with::DataFrame=DataFrame())
    idx_permute, idx_static = _split_index(df)
    df_static = unique(df[:,idx_static])

    if !isempty(with)
        idx_with = findindex(with)
        idx_permute = setdiff(idx_permute, idx_with)
        
        df_static = innerjoin(df_static, with,
            on=intersect(idx_static,idx_with))
    end

    df_permute = unique(df[:,idx_permute])
    permute_keys && (df_permute = permute(df_permute))
    
    return crossjoin(df_permute, df_static)
end


"""
    _split_index(df::DataFrame)
This function separates `df` indices that *should* be permuted from ones that do not need to
be because they contain duplicate information.

# Arguments
- `df::DataFrame` to divide into type of index (permuted vs. static).

# Returns
- `idx_permute::Array{Symbol,1}` indices to permute
- `idx_static::Array{Symbol,1}` indices to join to each row of the permuted indices.
"""
function _split_index(df::DataFrame)
    # !!!! Would be SO NICE if we could figure out if some units go with some values.
    # Like in MSN data. Or (src,sec,units) in EEM.
    idx = findindex(df)
    idx_static = _find_duplicate_index(df)
    idx_permute = setdiff(idx, idx_static)
    return idx_permute, idx_static
end


"""
    _find_duplicate_index(df::DataFrame)
This function finds and returns a list of DataFrame indices that do not provide unique
information. This might be the case (for example), if both a code and a corresponding description are
included. Duplicate indices will **not** be permuted when filling zeros.

This is relevant during calculations when both (base, units) are present.

# Arguments
- `df::DataFrame`

# Returns
- `idx::Array{Symbol,1}`: list of DataFrame indices that provide duplicate information.
"""
function _find_duplicate_index(df::DataFrame)
    idx_duplicate = _find_constant(df)
    idx = setdiff(findindex(df), idx_duplicate)

    num_unique = nunique(df[:,idx])

    idx_duplicate = vcat(
        [idx_duplicate],
        [_find_duplicate_index(df, idx[num_unique .== nn]) for nn in nonunique(num_unique)],
    )
    
    return vcat(idx_duplicate...)
end


function _find_duplicate_index(df::DataFrame, idx::Array{Symbol,1})
    df = unique(df[:,idx])
    N = nunique(df[:,idx[1]])

    idx_all = reverse(collect(Combinatorics.combinations(idx)))
    idx_all = idx_all[length.(idx_all) .> 1]

    idx_duplicate = idx_all[[size(unique(df, idx), 1) for idx in idx_all] .== N]

    length(idx_duplicate) == 1 && (idx_duplicate = idx_duplicate[1])
    return idx_duplicate
end