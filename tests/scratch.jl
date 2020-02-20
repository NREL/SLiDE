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

############################################################################################
col = :desc
on = "CFS Area"
before = :ma_desc
after = :none
remove = true

lst = split.(df[:,col], Regex(on));

df[!, before] .= strip.([m[1] for m in lst]);
df[!, after] .= strip.([length(m) > 1 ? m[2] : "" for m in lst]);

remove ? df[!, col] .= strip.(string.(df[:,before], " ", df[:,after])) : nothing

############################################################################################
df = SLiDE.edit_with(df, y["Order"]);
first(df,3)

# m1 = match.(r"(?<aggr>.*)\[CFS Area](?<sect>.*)", df[:,col])
# [m[1] for m in lst];