using CSV
using Dates
using DataFrames
using DelimitedFiles
using XLSX
using YAML

using SLiDE  # see src/SLiDE.jl

READ_DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "data", "readfiles"))

files_parse = XLSXInput("generate_yaml.xlsx", "parse", "B1:Z150", "parse")
files_parse = write_yaml(READ_DIR, files_parse)
files_parse = run_yaml(files_parse)