using CSV
using Dates
using DataFrames
using DelimitedFiles
using XLSX
using YAML

using SLiDE  # see src/SLiDE.jl

READ_DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "data", "readfiles"))

files_parse = XLSXInput("generate_yaml.xlsx", "parse", "F1:F150", "parse")
files_parse = write_yaml(READ_DIR, files_parse)
# files_parse = run_yaml(files_parse)

y = read_file(joinpath(READ_DIR, files_parse[1]))
df = read_file(y["Path"], y["CSVInput"][1]; shorten = 2)

# df = edit_with(df, y["Drop"])
# df = edit_with(df, y["Rename"])
# df = edit_with(df, y["Match"])
# df = edit_with(df, y["Melt"])
# df = edit_with(df, y["Map"])
# df = edit_with(df, y["Replace"])

# df = edit_with(df, y["Drop"])