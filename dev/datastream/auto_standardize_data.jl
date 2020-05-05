using CSV
using Dates
using DataFrames
using DelimitedFiles
using XLSX
using YAML

using SLiDE  # see src/SLiDE.jl

READ_DIR = joinpath("data", "readfiles")

files_parse = XLSXInput("generate_yaml.xlsx", "parse", "B1:Z180", "parse")

files_parse = write_yaml(READ_DIR, files_parse)
y_read = [read_file(files_parse[ii]) for ii in 1:length(files_parse)]

files_parse = run_yaml(files_parse)
# df = [read_file(joinpath(y_read[ii]["PathOut"]...)) for ii in 1:length(y_read)]

# ******************************************************************************************
# EDIT MANUALLY TO CHECK:
# ii_file = length(y_read)
# y = y_read[ii_file];
# files = [[y[k] for k in collect(keys(y))[occursin.("Input", keys(y))]]...;]

# for ii_input in 1:1
#     file = files[ii_input]
#     println(file)
#     global df = read_file(y["Path"], file)

#     "Drop"     in keys(y) && (df = edit_with(df, y["Drop"]))
#     "Rename"   in keys(y) && (df = edit_with(df, y["Rename"]))
#     "Group"    in keys(y) && (df = edit_with(df, y["Group"]))
#     "Match"    in keys(y) && (df = edit_with(df, y["Match"]))
#     "Melt"     in keys(y) && (df = edit_with(df, y["Melt"]))
#     "Add"      in keys(y) && (df = edit_with(df, y["Add"]))
#     "Map"      in keys(y) && (df = edit_with(df, y["Map"]))
#     "Replace"  in keys(y) && (df = edit_with(df, y["Replace"]))
#     "Drop"     in keys(y) && (df = edit_with(df, y["Drop"]))
#     "Operate"  in keys(y) && (df = edit_with(df, y["Operate"]))
#     "Describe" in keys(y) && (df = edit_with(df, y["Describe"], file))
#     "Order"    in keys(y) && (df = edit_with(df, y["Order"]))
# end

# first(df,4)