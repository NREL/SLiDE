using CSV
using Dates
using DataFrames
using DelimitedFiles
using XLSX
using YAML
using InteractiveUtils
const IU = InteractiveUtils

using SLiDE  # see src/SLiDE.jl

READ_DIR = joinpath("data", "readfiles")

files_map = [
    # XLSXInput("generate_yaml.xlsx", "map_parse", "B1:Z150", "map_parse"),
    # XLSXInput("generate_yaml.xlsx", "map_scale", "B1:Z150", "map_scale"),
    XLSXInput("generate_yaml.xlsx", "map_bluenote", "B1:Z150", "map_bluenote")
]

files_map = write_yaml(READ_DIR, files_map)
# y_read = [read_file(files_map[ii]) for ii in 1:length(files_map)]

files_map = run_yaml(files_map)
# df = [read_file(joinpath(y_read[ii]["PathOut"]...)) for ii in 1:length(y_read)];

include(joinpath(SLIDE_DIR, "dev", "datastream", "adjust_maps.jl"))

# ******************************************************************************************
# EDIT MANUALLY TO CHECK:
# ii_file = length(y_read);
# y = y_read[ii_file];
# files = [[y[k] for k in collect(keys(y))[occursin.("Input", keys(y))]]...;]
# 
# ii_input = 1;
# for ii_input in 1:1
#     file = files[ii_input]
#     println(file)
#     global df = read_file(y["PathIn"], file)

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