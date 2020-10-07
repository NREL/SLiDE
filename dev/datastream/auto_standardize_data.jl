using CSV
using Dates
using DataFrames
using DelimitedFiles
using XLSX
using YAML

using SLiDE  # see src/SLiDE.jl


READ_DIR = joinpath("data", "readfiles")

files_parse = XLSXInput("generate_yaml.xlsx", "input2", "B1:Y180", "parse")
files_parse = write_yaml(READ_DIR, files_parse)

files_parse = run_yaml(files_parse)
