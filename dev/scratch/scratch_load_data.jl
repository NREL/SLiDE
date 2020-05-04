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
READ_DIR = joinpath("data", "readfiles", "parse");
file = joinpath(READ_DIR, "bea_gsp_metro.yml");

# READ_DIR = "dev"
# file = joinpath(READ_DIR, "verify_data.yml")

y = YAML.load(open(joinpath(SLIDE_DIR, file)))

TYPES = string.([IU.subtypes.(IU.subtypes(DataStream))...;])
KEYS = intersect(TYPES, collect(keys(y)))

k = "Operate"
d = y[k]
T = datatype(k)

# function _load_axis(entry::AbstractString)
#     entry = convert_type(String, entry)
#     ("1" == entry || occursin("row", lowercase(entry))) && (entry = "row")
#     ("2" == entry || occursin("col", lowercase(entry))) && (entry = "col")
#     return entry
# end

# _load_axis(entry::Any) = _load_axis(convert_type.(String, entry))