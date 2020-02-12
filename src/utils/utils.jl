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
Extends "strip" to ignore missing fields and numbers.
"""
Base.strip(x::Missing) = x
Base.strip(x::Number) = x

"""
    convert_type(::Type{T}, x::Any)
Converts x into the specified `Type{T}`.
"""
convert_type(::Type{T}, x::Any) where T<:AbstractString = string(x)
convert_type(::Type{T}, x::Date) where T<:Integer = Dates.year(x)

function convert_type(::Type{T}, x::AbstractString) where T<:Integer
    return convert_type(T, convert_type(Float64, x))
end

convert_type(::Type{T}, x::AbstractString) where T<:Real = parse(T, replace(x, "," => ""))
convert_type(::Type{T}, x::Symbol) where T<:Real = convert_type(T, convert_type(String, x))

function convert_type(::Type{DataFrame}, lst::Array{Dict{Any,Any},1})
    return DataFrame(Dict(key => [x[key] for x in lst] for key in keys(lst[1])))
end

convert_type(::Type{DataType}, x::AbstractString) = datatype(x)
convert_type(::Type{Array{T,1}}, x::Any) where T<:Any = convert_type.(T, x)
convert_type(::Type{T}, x::Missing) where T<:Real = x;
convert_type(::Type{Any}, x::Any) = x
convert_type(::Type{T}, x::Any) where T = T(x)

"""
Returns true/false if the the DataType or object is an array.
"""
isarray(::Type{Array{T,1}}) where T <: Any = true
isarray(x::Array{T,1}) where T <: Any = true
isarray(::Any) = false