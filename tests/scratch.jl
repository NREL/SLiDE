using Complementarity
using CSV
using DataFrames
using JuMP
using Revise
using XLSX
using YAML

using SLiDE  # see src/SLiDE.jl

# READ YAML FILE.
DATA_DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "tests", "data"));
y = SLiDE.read_file(joinpath(DATA_DIR, "map_datastream.yml"));
df = SLiDE.read_file(y["Path"], y["XLSXInput"])

df = SLiDE.edit_with(df, y["Rename"]);
df = SLiDE.edit_with(df, y["Map"]);
df = SLiDE.edit_with(df, y["Split"]);