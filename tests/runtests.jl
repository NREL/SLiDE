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