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

files = [
    XLSXInput("generate_yaml.xlsx", "experiment", "C1:C150", "usgs"),
]

files = write_yaml(READ_DIR, files)
y_read = [read_file(files[ii]) for ii in 1:length(files)]

# files = run_yaml(files)

# include(joinpath(SLIDE_DIR, "dev", "datastream", "adjust_maps.jl"))
# df = [read_file(joinpath(y_read[ii]["PathOut"]...)) for ii in 1:length(y_read)];

# ******************************************************************************************
# EDIT MANUALLY TO CHECK:
ii_file = length(y_read);
y = y_read[ii_file];
files = [[y[k] for k in collect(keys(y))[occursin.("Input", keys(y))]]...;]

ii_input = 1;
# for ii_input in 1:1
    file = files[ii_input]
#     println(file)
    df = read_file(y["PathIn"], file)

    "Drop"     in keys(y) && (df = edit_with(df, y["Drop"]))
    "Rename"   in keys(y) && (df = edit_with(df, y["Rename"]))
#     # "Group"    in keys(y) && (df = edit_with(df, y["Group"]))
# #     "Stack"    in keys(y) && (df = edit_with(df, y["Stack"]))
#     "Match"    in keys(y) && (df = edit_with(df, y["Match"]))
    "Melt"     in keys(y) && (df = edit_with(df, y["Melt"]))
# # #     "Add"      in keys(y) && (df = edit_with(df, y["Add"]))
    "Map"      in keys(y) && (df = edit_with(df, y["Map"]))
    "Replace"  in keys(y) && (df = edit_with(df, y["Replace"]))
# # #     "Drop"     in keys(y) && (df = edit_with(df, y["Drop"]))
# # #     "Operate"  in keys(y) && (df = edit_with(df, y["Operate"]))
# # #     "Describe" in keys(y) && (df = edit_with(df, y["Describe"], file))
#     "Order"    in keys(y) && (df = edit_with(df, y["Order"]))
# # # end