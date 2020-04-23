using DataFrames
using Dates

"""
    function datatype(str::String)
This function evaluates an input string as a DataType if it is defined.
Otherwise, it will return false.
See: (thread on discourse.julialang.org)[https://discourse.julialang.org/t/parse-string-to-datatype/7118/9]
"""
function datatype(str::String)
    # type = :($(Symbol(titlecase(str))))
    type = :($(Symbol(str)))
    return isdefined(SLiDE, type) ? eval(type) : nothing
end

"""
    Base.strip(x::Missing)
    Base.strip(x::Number)
Extends `strip` to ignore missing fields and numbers.
"""
Base.strip(x::Missing) = x
Base.strip(x::Number) = x

"""
    Base.lowercase(x::Symbol)
Extends `lowercase` to handle symbols.
"""
Base.lowercase(x::Int) = x
Base.lowercase(x::Symbol) = Symbol(lowercase(string(x)))
Base.lowercase(x::Missing) = missing

"""
    Base.uppercase(x::Symbol)
Extends `uppercase` to handle symbols.
"""
Base.uppercase(x::Int) = x
Base.uppercase(x::Symbol) = Symbol(uppercase(string(x)))
Base.uppercase(x::Missing) = missing

"""
    Base.occursin(x::Symbol, y::Symbol)
    Base.occursin(x::String, y::Symbol)
Extends `occursin` to work for symbols. Potentially helpful for DataFrame columns.
"""
Base.occursin(x::Symbol, y::Symbol) = occursin(string(x), y)
Base.occursin(x::String, y::Symbol) = occursin(x, string(y))

"""
    convert_type(::Type{T}, x::Any)
    convert_type(::Dict{Any,Any}, df::DataFrame, value_col::Symbol; kwargs...)
Converts `x` into the specified `Type{T}`.

# Arguments
- `::Type{T}`: target DataType.
- `x<:Any`: value to convert.

# Keyword Arguments
Options available when converting a DataFrame into a dictionary of keys pointing to a value:
- `drop_cols = []`: Columns not to include in
    the keys. By default, no columns are dropped.
- `value_col::Symbol = :end`: If converting

# Returns
Data in specified type
"""
convert_type(::Type{T}, x::Any) where T<:AbstractString = string(x)
convert_type(::Type{T}, x::Date) where T<:Integer = Dates.year(x)
convert_type(::Type{T}, x::AbstractString) where T<:AbstractString = string(strip(x))

function convert_type(::Type{T}, x::AbstractString) where T<:Integer
    return convert_type(T, convert_type(Float64, x))
end

function convert_type(::Type{T}, x::AbstractString) where T<:Real
    return parse(T, reduce(replace, ["," => "", "\"" => ""], init = x))
end

convert_type(::Type{T}, x::Symbol) where T<:Real = convert_type(T, convert_type(String, x))

convert_type(::Type{DataFrame}, lst::Array{Dict{Any,Any},1}) = [DataFrame.(lst)...;]

function convert_type(::Type{Dict}, df::DataFrame; drop_cols = [], value_col::Symbol = :end)
    # Find and save the column containing values and that/those containing keys.
    # This assums that the last column in the DataFrame contains the value, unless specified
    # otherwise by the value_col keyword argument.
    value_col = value_col == :end ? names(df)[end] : value_col
    key_cols = setdiff(names(df), convert_type.(Symbol, ensurearray(drop_cols)), [value_col])

    d = Dict((length(key_cols) == 1 ? (row[key_cols]) : (row[key_cols]...,)) => row[value_col]
        for row in eachrow(df))
    return d
end

convert_type(::Type{DataType}, x::AbstractString) = datatype(x)
convert_type(::Type{Array{T}}, x::Any) where T<:Any = convert_type.(T, x)
convert_type(::Type{Array{T,1}}, x::Any) where T<:Any = convert_type.(T, x)

convert_type(::Type{T}, x::Missing) where T<:Real = x;
convert_type(::Type{T}, x::Missing) where T<:AbstractString = x;
convert_type(::Type{Any}, x::Any) = x

convert_type(::Type{T}, x::Any) where T = T(x)

convert_type(::Type{Bool}, x::AbstractString) = lowercase(x) == "true" ? true : false

"""
Returns true/false if the the DataType or object is an array.
"""
isarray(::Type{Array{T,1}}) where T <: Any = true
isarray(x::Array{T,1}) where T <: Any = true
isarray(::Any) = false

"""
    ensurearray(x::Any)
"""
ensurearray(x::Array{T,1}) where T <: Any = x
ensurearray(x::Tuple{Vararg{Any}}) = collect(x)
ensurearray(x::Any) = [x]

"""
    permute(x::Any)
This function finds all possible permutations of the input arrays.

# Arguments
- `x::Tuple` or `x::NamedTuple{}` or `x::Array`: list of arrays to permute.
    If `x` is a NamedTuple, its values will be permuted.

# Returns
- `x::Array{Tuple,1}`: list of all possible permutations of the input values.
    If `x` does not contain at least one array, there will be nothing to permute and the function will return `x`.
"""
function permute(x::Tuple{Array, Vararg{Any}})
    return length(x) == 1 ? sort(unique(x[1])) :
        [collect(Base.Iterators.product(sort.(unique.(ensurearray.(x)))...))...;]
end

permute(x::Tuple) = sort(unique(ensurearray(x)))
permute(x::NamedTuple) = permute(values(x))
permute(x::Array) = any(isarray.(x)) ? permute(Tuple(x)) : sort(unique(x))