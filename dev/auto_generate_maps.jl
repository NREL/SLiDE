using CSV
using Dates
using DataFrames
using DelimitedFiles
using XLSX
using YAML

using SLiDE  # see src/SLiDE.jl

READ_DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "data", "readfiles"))

files_map = [XLSXInput("generate_yaml.xlsx", "map_parse", "A1:Z150", "map_parse"),
            #  XLSXInput("generate_yaml.xlsx", "map_scale", "B1:Z150", "map_scale"),
            #  XLSXInput("generate_yaml.xlsx", "map_bluenote", "B1:Z150", "map_bluenote"),
            ]

files_map = write_yaml(READ_DIR, files_map)
# y = read_file(joinpath(READ_DIR, files_map[1]))

files_map = run_yaml(files_map)
# df = read_file(joinpath(y["PathOut"]...));

include("adjust_maps.jl")