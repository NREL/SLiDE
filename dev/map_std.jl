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
# BEA
# y_map = read_file(joinpath(READ_DIR, "std_bea.yml"));
# df_map = unique(SLiDE.edit_with(y_map))
# sort!(df_map, reverse(names(df_map)))
# CSV.write(joinpath(y_map["PathOut"]...), df_map)

############################################################################################
# TECHNOLOGIES
# y_map = read_file(joinpath(READ_DIR, "std_tech.yml"));
# df_map = unique(SLiDE.edit_with(y_map))
# sort!(df_map, reverse(names(df_map)))
# CSV.write(joinpath(y_map["PathOut"]...), df_map)

############################################################################################
# REGIONS
# y_map = read_file(joinpath(READ_DIR, "std_regions.yml"));
# df_map = unique(SLiDE.edit_with(y_map));
# df_map = vcat(df_map, DataFrame(from = ["C","M","O"], to = ["canada","mexico","other"]));
# sort!(df_map, reverse(names(df_map)))
# CSV.write(joinpath(y_map["PathOut"]...), df_map)

############################################################################################
# GSP
# y_map = read_file(joinpath(READ_DIR, "std_gsp.yml"))
# df_map = read_file(y_map["Path"], y_map["CSVInput"])

# df_metro = DataFrame(
#     from = ["Gross domestic product (GDP) by metropolitan area",
#         "Quantity indexes for real GDP by metropolitan area (2009=100.0)",
#         "Real GDP by metropolitan area"],
#     to = ["gdp", "qty", "rgdp"])

# df_map = [df_map; df_metro]
# sort!(df_map, reverse(names(df_map)))
# CSV.write(joinpath(y_map["PathOut"]...), df_map)

############################################################################################
# SGF
y_map = read_file(joinpath(READ_DIR, "std_sgf.yml"));
# df_map = unique(SLiDE.edit_with(y_map));
df_map = read_file(y_map["Path"], y_map["CSVInput"])

# Make horizontally-concatennated DataFrames one, normalized database.
# None of the Edit DataTypes are quite equiped to handle this.
df_map = df_map[:, names(df_map)[.!occursin.("line_num", names(df_map))]]

df = DataFrame();
cols = [:from, :sgf_desc, :units]

for yy in string.(1997:2016)
    df_temp = copy(df_map[:, occursin.(yy, names(df_map))]);
    df_temp = edit_with(df_temp, Rename.(names(df_temp), cols))
    global df = vcat(df, df_temp);
end


function SLiDE.edit_with(df::DataFrame, x::Map2)
    df_map = read_file(x)
    df_map = dropmissing(unique(df_map[:,unique([x.from; x.to])]))
    [df[!,col] .= convert_type.(unique(typeof.(df_map[:,col_map])), df[:,col])
        for (col_map, col) in zip(x.from, x.input)]
    df = join(df, df_map, on = collect(zip(x.input, x.from));
        kind = :left, makeunique = true)

    return df
end




# Other edits...
df = unique(edit_with(df, y_map["Drop"]))
df = unique(edit_with(df, y_map["Map2"]))
df = edit_with(df, Rename(:to, :sgf_windc))

df = unique(edit_with(df, y_map["Order"]))
CSV.write(joinpath(y_map["PathOut"]...), df)




############################################################################################
# NAICS
# yn = read_file(joinpath(READ_DIR, "std_naics.yml"));
# dfn = read_file(yn["Path"], yn["XLSXInput"])
# dfn = edit_with(dfn, yn["Rename"])
# dfn = edit_with(dfn, yn["Match"])

# dfn[!,:naics_level] .= string.(length.(dfn[:,:naics_level]))
# dfn = edit_with(dfn, yn["Replace"])
# CSV.write(joinpath(yn["PathOut"]...), dfn)