using DataFrames
using Dates
using Printf
using SLiDE

"""
# 1A: Convert Type
See: src/utils/utils.jl

Convert between datatypes using one function. There are some julia functions
(see [signed](https://docs.julialang.org/en/v1/base/numbers/#Base.signed),
[parse](https://docs.julialang.org/en/v1/base/numbers/#Base.parse)) that can do this,
but different functions are required depending on the input type.

This function (and all of its methods) take a more stylistically-julia approach.
This is helpful when a user can specify a desired DataType.
"""

# Helper function for this example to print simple type conversions.
print_convert(x1, x2) = @printf("\t%10s %-9s --> %7s %-9s\n",
    x1, @sprintf("(%s)",typeof(x1)),
    x2, @sprintf("(%s)",typeof(x2)))

# ******************************************************************************************
# Now supports DataFrames (with one "value" column) to dictionary of keys =>value.
# This is more stylistically julia than specifying the conversion in the function name.
NYR = 3  # change if desired

yr = 2020-(NYR-1):2020
r = ["co","wi"]
NR = length(r)

df1 = DataFrame(yr = yr, value = Float64.(1:NYR))
df2 = sort(DataFrame(
    yr = repeat(yr, outer=[NR]),
    r = repeat(r, inner=[NYR]),
    value = Float64.(1:NYR*NR)))
df3 = edit_with(copy(df2), Add(:units, "millions of us dollars (usd)"))

d1 = convert_type(Dict, df1)
d2 = convert_type(Dict, df2)
d3 = convert_type(Dict, df3; drop_cols = :units)

# ******************************************************************************************
# Simple examples.
x = Date(2020)
print_convert(x, convert_type(Int64, x))

x = 1
print_convert(x, convert_type(Float64, x))
print_convert(x, convert_type(String, x))
print_convert(x, convert_type(Symbol, x))

x = 1.0
print_convert(x, convert_type(Int64, x))
print_convert(x, convert_type(String, x))
print_convert(x, convert_type(Symbol, x))

x = "1,234"
print_convert(x, convert_type(Int64, x))
print_convert(x, convert_type(Float64, x))
print_convert(x, convert_type(Symbol, x))

x = Symbol("1")
print_convert(x, convert_type(Int64, x))
print_convert(x, convert_type(Float64, x))
print_convert(x, convert_type(String, x))

x = missing
print_convert(x, convert_type(Int64, x))
print_convert(x, convert_type(Float64, x))
print_convert(x, convert_type(String, x))