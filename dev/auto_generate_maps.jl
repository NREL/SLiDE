using CSV
using Dates
using DataFrames
using DelimitedFiles
using XLSX
using YAML

using SLiDE  # see src/SLiDE.jl



READ_DIR = joinpath("data", "readfiles")

files_map = [
    XLSXInput("generate_yaml.xlsx", "map_parse", "A1:Z150", "map_parse"),
    # XLSXInput("generate_yaml.xlsx", "map_scale", "B1:Z150", "map_scale"),
    # XLSXInput("generate_yaml.xlsx", "map_bluenote", "B1:Z150", "map_bluenote"),
]

files_map = write_yaml(READ_DIR, files_map)
y_read = [read_file(files_map[ii]) for ii in 1:length(files_map)]

files_map = run_yaml(files_map)
df = [read_file(joinpath(y_read[ii]["PathOut"]...)) for ii in 1:length(y_read)];

include("adjust_maps.jl")

# ******************************************************************************************
# EDIT MANUALLY TO CHECK:
# ii_file = 9;
# y = y_read[ii_file];
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

# first(df,4)