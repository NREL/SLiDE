using CSV
using Dates
using DataFrames
using DelimitedFiles
using XLSX
using YAML

using SLiDE  # see src/SLiDE.jl

READ_DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "data", "readfiles"))    # *

files_parse = XLSXInput("generate_yaml.xlsx", "parse", "C1:E180", "parse")                      # *
files_parse = write_yaml(READ_DIR, files_parse) # *

y = read_file(files_parse[1])

files_parse = run_yaml(files_parse);
df = read_file(joinpath(y["PathOut"]...))

# ******************************************************************************************
# EDIT MANUALLY TO CHECK:
# ii_input = 1;
# file = ensurearray(y[collect(keys(y))[occursin.("Input",keys(y))][1]])[ii_input]
# df = read_file(y["Path"], file)

# df = "Drop"    in keys(y) ? edit_with(df, y["Drop"])             : df
# df = "Rename"  in keys(y) ? edit_with(df, y["Rename"])           : df
# df = "Group"   in keys(y) ? edit_with(df, y["Group"])            : df
# df = "Match"   in keys(y) ? edit_with(df, y["Match"])            : df
# df = "Melt"    in keys(y) ? edit_with(df, y["Melt"])             : df
# df = "Add"     in keys(y) ? edit_with(df, y["Add"])              : df
# df = "Map"     in keys(y) ? edit_with(df, y["Map"])              : df
# df = "Replace" in keys(y) ? edit_with(df, y["Replace"])          : df
# df = "Drop"    in keys(y) ? edit_with(df, y["Drop"])             : df
# df = "Operate" in keys(y) ? edit_with(df, y["Operate"])          : df
# df = "Describe"  in keys(y) ? edit_with(df, y["Describe"], file) : df
# df = "Order"   in keys(y) ? edit_with(df, y["Order"])            : df

# x = Drop(:sctg, "-", "occursin")