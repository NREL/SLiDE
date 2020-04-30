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
file = joinpath(READ_DIR, "bea_supply_det.yml");

# file = "data/test_datastream_97.yml"
y = YAML.load(open(joinpath(SLIDE_DIR, file)))

TYPES = string.([IU.subtypes.(IU.subtypes(DataStream))...;])
KEYS = intersect(TYPES, collect(keys(y)))

# [y[k] = load_from(datatype(k), y[k]) for k in KEYS]


d = y["Order"]
T = Order

# function SLiDE._load_as_type(entry, type::DataType)
#     entry = ensurearray(convert_type.(type, entry))
#     !isarray(type) && (entry = entry[1])
#     return entry
# end

# SLiDE._load_as_type(::Type{T}, entry, type::DataType) where T<:Any = SLiDE._load_as_type(entry, type)
# SLiDE._load_as_type(::Type{Rename}, entry, type::DataType) = SLiDE._load_as_type(_load_case(entry), type)
# SLiDE._load_as_type(::Type{Replace}, entry, type::DataType) = SLiDE._load_as_type(_load_case(entry), type)




# function SLiDE.load_from(::Type{T}, df::DataFrame) where T <: Any
#     (fields, types) = (fieldnames(T), T.types)

#     # Print warning if DataFrame is missing required columns.
#     missing_fields = setdiff(fields, names(df))
#     if length(missing_fields) > 0
#         @warn(string("DataFrame columns missing required fields to fill DataType ", Rename),
#             missing_fields)
#     end

#     # If one of the struct fields is an ARRAY, we here assume that it is the length of the
#     # entire DataFrame, and all other fields are duplicates.
#     if any(isarray.(T.types))
#         inps = [SLiDE._load_as_type(T, df[:, f], t) for (f,t) in zip(fields, types)]
#         lst = [T(inps...)]
#     # If each row in the input df fills one and only one struct,
#     # create a list of structures from each DataFrame row.
#     else
#         lst = [T((SLiDE._load_as_type(T, row[f], t) for (f,t) in zip(fields, types))...)
#             for row in eachrow(df)]
#     end
#     return size(lst)[1] == 1 ? lst[1] : lst
# end