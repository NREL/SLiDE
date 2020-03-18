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
READ_DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "data", "readfiles", "2_standardize"));

file = "data/test_datastream_97.yml"
y = YAML.load(open(file))

TYPES = string.([IU.subtypes.(IU.subtypes(DataStream))...;])
KEYS = intersect(TYPES, collect(keys(y)))

[y[k] = load_from(datatype(k), y[k]) for k in KEYS]

############################################################################################
# IF IT'S A LIST OF DATAFRAMES...
# k = "Order"
# T = datatype(k)
# d = y[k]

# function SLiDE.load_from(::Type{T}, d::Array{Dict{Any,Any},1}) where T <: Any
#     lst = all(isarray.(T.types)) ? ensurearray(load_from(T, convert_type(DataFrame, d))) :
#         vcat(ensurearray(load_from.(T, d))...)
#     return size(lst)[1] == 1 ? lst[1] : lst
# end

# function SLiDE.load_from(::Type{T}, d::Dict{Any,Any}) where T <: Any
#     it = zip(string.(fieldnames(T)), T.types)

#     if any(isarray.(T.types)) & !all(isarray.(T.types))
#         inps = [isarray(type) ? ensurearray(convert_type.(type, d[field])) :
#             convert_type.(type, d[field]) for (field,type) in it]
#         lst = [T(inps...)]
#     else
#         lst = ensurearray(load_from(T, convert_type(DataFrame, d)))
#     end
#     return size(lst)[1] == 1 ? lst[1] : lst
# end