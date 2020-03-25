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
Base.lowercase(x::Symbol) = Symbol(lowercase(string(x)))

"""
    Base.uppercase(x::Symbol)
Extends `uppercase` to handle symbols.
"""
Base.uppercase(x::Symbol) = Symbol(uppercase(string(x)))


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

- `::Type{T}`:
- `x<:Any`

# Returns
Data in specified type

"""
convert_type(::Type{T}, x::Any) where T<:AbstractString = string(x)
convert_type(::Type{T}, x::Date) where T<:Integer = Dates.year(x)
convert_type(::Type{T}, x::AbstractString) where T<:AbstractString = string(strip(x))

function convert_type(::Type{T}, x::AbstractString) where T<:Integer
    return convert_type(T, convert_type(Float64, x))
end

# convert_type(::Type{T}, x::AbstractString) where T<:Real = parse(T, replace(x, "," => ""))
function convert_type(::Type{T}, x::AbstractString) where T<:Real
    return parse(T, reduce(replace, ["," => "", "\"" => ""], init = x))
end

convert_type(::Type{T}, x::Symbol) where T<:Real = convert_type(T, convert_type(String, x))

function convert_type(::Type{DataFrame}, lst::Array{Dict{Any,Any},1})
    return vcat(DataFrame.(lst)...)
    # return DataFrame(Dict(key => [x[key] for x in lst] for key in keys(lst[1])))
end

convert_type(::Type{DataType}, x::AbstractString) = datatype(x)
convert_type(::Type{Array{T,1}}, x::Any) where T<:Any = convert_type.(T, x)

convert_type(::Type{T}, x::Missing) where T<:Real = x;
convert_type(::Type{T}, x::Missing) where T<:AbstractString = x;
convert_type(::Type{Any}, x::Any) = x

function convert_type(
    ::Type{Dict{Any,Any}},
    df::DataFrame,
    value_col::Symbol;
    remove_col::Array{Symbol,1}=[]
)
    key_col = setdiff(names(df), [[value_col]; remove_col]);
    d = Dict(values(row[key_col]) => row[value_col] for row in eachrow(df));
    return d
end

convert_type(::Type{T}, x::Any) where T = T(x)

convert_type(::Type{Bool}, x::AbstractString) = lowercase(x) == "true" ? true : false

"""
Returns true/false if the the DataType or object is an array.
"""
isarray(::Type{Array{T,1}}) where T <: Any = true
isarray(x::Array{T,1}) where T <: Any = true
isarray(::Any) = false

"""
Returns an array.
"""
ensurearray(x::Array{T,1}) where T <: Any = x
ensurearray(x::Any) = [x]