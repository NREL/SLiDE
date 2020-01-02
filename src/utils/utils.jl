using Dates

# Functions that change types:
"""
    convert_type(::Type{T}, x::Any)
Converts x into the specified `Type{T}`.
"""
convert_type(::Type{T}, x::Any) where T = T(x)
convert_type(::Type{T}, x::Any) where T <: AbstractString = string(x)

convert_type(::Type{T}, x::Date) where T <: Integer = Dates.year(x)

convert_type(::Type{T}, x::AbstractString) where T <: Real = parse(T, replace(x, "," => ""))
convert_type(::Type{T}, x::AbstractString) where T <: Integer = convert_type(T, convert_type(Float64, x))

convert_type(::Type{T}, x::Symbol) where T <: Real = convert_type(T, convert_type(String, x))

# TESTS
x = Date(2020)
println(x, " -> ", convert_type(Int64, x))

x = 6
println(x, " -> ", convert_type(Float64, x))
println(x, " -> ", convert_type(String, x))
println(x, " -> ", convert_type(Symbol, x))

x = 6.0
println(x, " -> ", convert_type(Int64, x))
println(x, " -> ", convert_type(String, x))
println(x, " -> ", convert_type(Symbol, x))

x = "6,666"
println(x, " -> ", convert_type(Float64, x))
println(x, " -> ", convert_type(Int64, x))
println(x, " -> ", convert_type(Symbol, x))

x = Symbol("6")
println(x, " -> ", convert_type(Float64, x))
println(x, " -> ", convert_type(Int64, x))
println(x, " -> ", convert_type(String, x))

# a = "hi there"
# filter(x -> !isspace(x), titlecase(a))