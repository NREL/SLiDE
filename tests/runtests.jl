using CSV
using Test
using Logging
using Dates
using DataFrames
using YAML

using SLiDE

import InfrastructureSystems
const IS = InfrastructureSystems

BASE_DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), ".."));
SRC_DIR = joinpath(BASE_DIR, "src");



############################################################################################
# TESTS
# x = Date(2020)
# println(x, " -> ", convert_type(Int64, x))

# x = 6
# println(x, " -> ", convert_type(Float64, x))
# println(x, " -> ", convert_type(String, x))
# println(x, " -> ", convert_type(Symbol, x))

# x = 6.0
# println(x, " -> ", convert_type(Int64, x))
# println(x, " -> ", convert_type(String, x))
# println(x, " -> ", convert_type(Symbol, x))

# x = "6,666"
# println(x, " -> ", convert_type(Float64, x))
# println(x, " -> ", convert_type(Int64, x))
# println(x, " -> ", convert_type(Symbol, x))

# x = Symbol("6")
# println(x, " -> ", convert_type(Float64, x))
# println(x, " -> ", convert_type(Int64, x))
# println(x, " -> ", convert_type(String, x))

# a = "hi there"
# filter(x -> !isspace(x), titlecase(a))