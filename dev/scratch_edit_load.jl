using Complementarity
using CSV
using DataFrames
using DelimitedFiles
using JuMP
using Revise
using XLSX
using YAML

import InteractiveUtils
const IU = InteractiveUtils

using SLiDE  # see src/SLiDE.jl

# READ YAML FILE.
READ_DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "data", "readfiles", "parse"));
file = joinpath(READ_DIR, "bea_supply.yml");

# file = "data/test_datastream_97.yml"
y = YAML.load(open(file))

TYPES = string.([IU.subtypes.(IU.subtypes(DataStream))...;])
KEYS = intersect(TYPES, collect(keys(y)))

# [y[k] = load_from(datatype(k), y[k]) for k in KEYS]

d = y["Order"]
T = Order