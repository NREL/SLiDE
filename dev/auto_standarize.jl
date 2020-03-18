using Complementarity
using CSV
using Dates
using DataFrames
using DelimitedFiles
using JuMP
using Revise
using XLSX
using YAML

using SLiDE  # see src/SLiDE.jl

# * * * * * * * * * * * * * * * * * *
READ_DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "data", "readfiles"))

files_map = [XLSXInput("generate_yaml.xlsx", "map_parse", "B1:Z150", "map_parse"),
             XLSXInput("generate_yaml.xlsx", "map_scale", "B1:Z150", "map_scale")]

files_map = write_yaml(READ_DIR, files_map)
files_map = run_yaml(files_map)

include("adjust_maps.jl")

files_parse = XLSXInput("generate_yaml.xlsx", "parse", "B1:Z150", "parse")
files_parse = write_yaml(READ_DIR, files_parse)
files_parse = run_yaml(files_parse)