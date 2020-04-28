using CSV
using Dates
using DataFrames
using DelimitedFiles
using XLSX
using YAML

using SLiDE  # see src/SLiDE.jl

READ_DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "data", "readfiles"))    # *

files_parse = XLSXInput("generate_yaml.xlsx", "parse", "V1:V180", "parse")                      # *
files_parse = write_yaml(READ_DIR, files_parse) # *

y = [read_file(files_parse[ii]) for ii in 1:length(files_parse)]

files_parse = run_yaml(files_parse);
df = [read_file(joinpath(y[ii]["PathOut"]...)) for ii in 1:length(y)]

# ******************************************************************************************
# EDIT MANUALLY TO CHECK:
# ii_file = length(y);
# y = y[ii_file];
# files = [[y[k] for k in collect(keys(y))[occursin.("Input", keys(y))]]...;]

# ii_input = 1;
# for ii_input in 1:1
#     file = files[ii_input]
#     println(file)
#     global df = read_file(y["Path"], file)

#     global df = "Drop"    in keys(y) ? edit_with(df, y["Drop"])             : df
#     global df = "Rename"  in keys(y) ? edit_with(df, y["Rename"])           : df
#     global df = "Group"   in keys(y) ? edit_with(df, y["Group"])            : df
#     global df = "Match"   in keys(y) ? edit_with(df, y["Match"])            : df
#     global df = "Melt"    in keys(y) ? edit_with(df, y["Melt"])             : df
#     global df = "Add"     in keys(y) ? edit_with(df, y["Add"])              : df
#     global df = "Map"     in keys(y) ? edit_with(df, y["Map"])              : df
#     global df = "Replace" in keys(y) ? edit_with(df, y["Replace"])          : df
#     global df = "Drop"    in keys(y) ? edit_with(df, y["Drop"])             : df
#     global df = "Operate" in keys(y) ? edit_with(df, y["Operate"])          : df
#     global df = "Describe"  in keys(y) ? edit_with(df, y["Describe"], file) : df
#     global df = "Order"   in keys(y) ? edit_with(df, y["Order"])            : df
# end

# println("Done.")
# first(df,4)