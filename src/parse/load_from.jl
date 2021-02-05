"""
    load_from(::Type{T}, df::DataFrame) where T <: Any
Load a DataFrame `df` into a structure of type T.

!!! note

    This requires that all structure fieldnames are also DataFrame column names.
    Extra dataframe columns are acceptable, although that information will not be used.

# Arguments
- `::Type{T} where T <: Any`: Any DataType.
- `df::DataFrame`: The DataFrame storing the information to store as a DataType.

# Returns
- `x<:Any`: The DataType specified as an argument.
- `lst::Array{T} where T<:Any`: A list of elements of the DataType specified as an argument
    given a multi-row DataFrame.

# Example

```julia
df = DataFrame(from = ["State"], to = ["region"])
load_from(Rename, df)
```
"""
function load_from(::Type{T}, d::Array{Dict{Any,Any},1}) where T <: Any
    lst = if all(isarray.(T.types))
        ensurearray(load_from(T, convert_type(DataFrame, d)))
    else
        vcat(ensurearray(load_from.(T, d))...)
    end
    return size(lst)[1] == 1 ? lst[1] : lst
end


function load_from(::Type{T}, d::Dict{Any,Any}) where T <: Any
    # Fill the datatype with the values in the dictionary keys, ensuring correct t.
    (fields, types) = (string.(fieldnames(T)), T.types)
    d = _load_path(d)

    # Fill the datatype with the input.
    # if any(isarray.(types)) && !all(isarray.(types))
    if any(isarray.(types))
        # Restructure data into a list of inputs in the order and type required when
        # creating the datatype. Ensure that all array entries should, in fact, be arrays.
        inps = [_load_as_type(T, d[f], t) for (f, t) in zip(fields, types)]
        inpscorrect = isarray.(inps) .== isarray.(types)

        # If all inputs are of the correct structure, fill the data type.
        if all(inpscorrect)
            lst = [T(inps...)]
        # If some inputs are arrays when they shouldn't be, expand these into a new list of
        # dictionaries to create a list of datatypes, including all array values.
        # First, create a dictionary determining whether the entry needs to be split.
        # Then, split the dictionary into a list of arrays where necessary.
        else
            LEN = length(inps[findmax(.!inpscorrect)[2]])
            splitarray = Dict(fields[ii] => !inpscorrect[ii] for ii in 1:length(inps))
            lst = [Dict{Any,Any}(k => splitarray[k] ? d[k][ii] : d[k] for k in keys(d))
                for ii in 1:LEN]
            lst = ensurearray(load_from(T, lst))
        end
    else
        lst = ensurearray(load_from(T, convert_type(DataFrame, d)))
    end
    return size(lst)[1] == 1 ? lst[1] : lst
end


function load_from(::Type{T}, df::DataFrame) where T <: Any
    isempty(df) && @error("Cannot load datatype $T from an empty DataFrame.")

    (fields, types) = (fieldnames(T), T.types)

    # Print warning if DataFrame is missing required columns.
    missing_fields = setdiff(fields, propertynames(df))
    # if length(missing_fields) > 0
    #     @warn("DataFrame columns missing fields required to fill DataType $T" * missing_fields)
    # end

    df = df[:, ensurearray(fields)]
    # If all of the struct fields are arrays, we assume all DataFrame rows should be saved.
    if all(isarray.(T.types))
        inps = [_load_as_type(T, df[:, f], t) for (f, t) in zip(fields, types)]
        lst = [T(inps...)]
    else
        lst = [T((_load_as_type(T, row[f], t) for (f, t) in zip(fields, types))...)
            for row in eachrow(df)]
    end
    return size(lst)[1] == 1 ? lst[1] : lst
end


function load_from(::Type{Dict{T}}, df::DataFrame) where T <: Any
    return Dict(_inp_key(x) => x for x in load_from(T, df))
end


"""
    _load_path(d::Dict)
Edits directories containing a list of directories ending in a file name as one path.
"""
function _load_path(d::Dict)
    FILES = [".csv", ".xlsx", ".txt", ".map", ".set"]
    for (k, lst) in d
        if typeof(lst) .== Array{String,1}
            ii_file = [any(occursin.(FILES, x)) for x in lst]
            (ii_file[end] && .!any(ii_file[1:end - 1])) && (d[k] = joinpath(lst...))
        end
    end
    return d
end


"""
    _load_as_type(::Type{Any}, entry, type::DataType)
Converts an entry to the required DataType
"""
function _load_as_type(entry, type::DataType)
    entry = ensurearray(convert_type.(type, entry))
    (!isarray(type) && length(entry) == 1) && (entry = entry[1])
    return entry
end

_load_as_type(::Type{T}, entry, type::DataType) where T <: Any = _load_as_type(entry, type)
_load_as_type(::Type{Drop},    entry, type::Type{Any})    = _load_as_type(_load_case(entry), type)
_load_as_type(::Type{Rename},  entry, type::Type{Symbol}) = _load_as_type(_load_case(entry), type)
_load_as_type(::Type{Replace}, entry, type::Type{Any})    = _load_as_type(_load_case(entry), type)
_load_as_type(::Type{Operate}, entry, type::Type{Symbol}) = _load_as_type(_load_axis(entry), type)
_load_as_type(::Type{Parameter}, entry, type::Type{Array{Symbol,1}}) = _load_as_type(_load_index(entry), type)
_load_as_type(::Type{T}, entry::Missing, type::Type{String}) where T <: Any = _load_as_type(T, "", type)        # if we're reading in dataframe with missing values


"""
    _load_case(entry::AbstractString)
Standardizes string identifiers that indicate a case change (upper-to-lower or vice-versa)
for easier editing.
"""
function _load_case(entry::AbstractString)
    test = lowercase(entry)
    
    occursin("lower", test) && (entry = "lower")
    occursin("upper", test) && (entry = "uppercasefirst" == test ? "uppercasefirst" : "upper")
    occursin("titlecase", test) && (entry = "titlecase")

    "all" == test    && (entry = "all")
    "unique" == test && (entry = "unique")
    return entry
end

_load_case(entry::Any) = entry


"""
    _load_axis(entry::Any)
"""
function _load_axis(entry::AbstractString)
    entry = convert_type(String, entry)
    ("1" == entry || occursin("row", lowercase(entry))) && (entry = "row")
    ("2" == entry || occursin("col", lowercase(entry))) && (entry = "col")
    return entry
end

_load_axis(entry::Any) = _load_axis(convert_type.(String, entry))


"""
"""
function _load_index(entry::String)
    m = match(r"^[\[|\(](?<idx>.*)[\]|\)]$", entry)
    m !== nothing && (entry = m[:idx])
    return string.(split(entry, ","))
end

_load_index(entry::Any) = entry