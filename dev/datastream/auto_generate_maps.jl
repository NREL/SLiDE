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
    XLSXInput("generate_yaml.xlsx", "map_parse",     "B1:Z150", "map_parse"),
    XLSXInput("generate_yaml.xlsx", "map_scale",     "B1:Z150", "map_scale"),
    XLSXInput("generate_yaml.xlsx", "map_bluenote",  "B1:Z150", "map_bluenote"),
    XLSXInput("generate_yaml.xlsx", "map_crosswalk", "B1:Z150", "map_crosswalk")
]

files_map = write_yaml(READ_DIR, files_map)
files_map = run_yaml(files_map)
include(joinpath(SLIDE_DIR, "dev", "datastream", "adjust_maps.jl"))
