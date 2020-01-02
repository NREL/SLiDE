using Test
using Logging
using Dates

import InfrastructureSystems

BASE_DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), ".."))
# DATA_DIR = joinpath(BASE_DIR, "data")

include(joinpath(BASE_DIR, "src", "utils", "utils.jl"))