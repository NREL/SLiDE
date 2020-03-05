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

READ_DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "data", "readfiles", "1_map", "std"))
# MAP_DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "data", "coremaps"))

############################################################################################
# TECHNOLOGIES
# y_map = SLiDE.read_file(joinpath(READ_DIR, "std_tech.yml"));
# df_map = unique(SLiDE.edit_with(y_map))
# sort!(df_map, reverse(names(df_map)))
# CSV.write(joinpath(y_map["PathOut"]...), df_map)

############################################################################################
# REGIONS
# y_map = SLiDE.read_file(joinpath(READ_DIR, "std_regions.yml"));
# df_map = unique(SLiDE.edit_with(y_map));
# df_map = vcat(df_map, DataFrame(from = ["C","M","O"], to = ["canada","mexico","other"]));
# sort!(df_map, reverse(names(df_map)))
# CSV.write(joinpath(y_map["PathOut"]...), df_map)

############################################################################################
# SGF
y_map = SLiDE.read_file(joinpath(READ_DIR, "std_sgf.yml"));
# df_map = unique(SLiDE.edit_with(y_map));
df_map = SLiDE.read_file(y_map["Path"], y_map["CSVInput"])

# Make horizontally-concatennated DataFrames one, normalized database.
# None of the Edit DataTypes are quite equiped to handle this.
df_map = df_map[:, Symbol.(names(df_map)[.!occursin.("line_num", names(df_map))])]

df = DataFrame();

for yy in string.(1997:2016)
    df_temp = copy(df_map[:, Symbol.(cols[occursin.(yy, cols)])]);
    df_temp = edit_with(df_temp, Rename.(names(df_temp), y_map["Order"].col[.!occursin.(:windc, y_map["Order"].col)]))
    global df = vcat(df, df_temp);
end

# Other edits...
# df = unique(edit_with(df, y_map["Drop"]))
# df = unique(edit_with(df, y_map["Map"]))
# df = unique(edit_with(df, y_map["Order"]))
# CSV.write(joinpath(y_map["PathOut"]...), df)

