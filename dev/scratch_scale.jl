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

READ_DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "data", "readfiles", "1_map", "scale"))

CITIES = ["Baltimore", "Denver", "Madison", "Fargo"]

############################################################################################
function dataframe_stats(df::DataFrame)
    ROW, COL = size(df)
    df_stats = DataFrame(
        col = fill(:sym, COL),
        unique = fill(0, COL),
        miss = fill(0,COL)
    )
    for ii in 1:COL
        col = names(df)[ii]
        df_stats[ii,:col] = col
        df_stats[ii,:unique] = size(unique(df,col),1);
        df_stats[ii,:miss] = ROW-size(dropmissing(df,col),1);
    end
    return df_stats
end

############################################################################################
# y1 = read_file(joinpath(READ_DIR, "scale_census_cbsa.yml"))
# df1 = unique(edit_with(y1));
# CSV.write(joinpath(y1["PathOut"]...), df1)

# y2 = read_file(joinpath(READ_DIR, "scale_census_cbsa_cities.yml"));
# df2 = unique(edit_with(y2));
# CSV.write(joinpath(y2["PathOut"]...), df2)

# y4 = read_file(joinpath(READ_DIR, "scale_census_necta_cities.yml"));
# df4 = unique(edit_with(y4))
# CSV.write(joinpath(y4["PathOut"]...), df4)

# y3 = read_file(joinpath(READ_DIR, "scale_census_necta.yml"));
# df3 = unique(edit_with(y3));
# CSV.write(joinpath(y3["PathOut"]...), df3)

yn = read_file(joinpath(READ_DIR, "scale_naics.yml"));
dfn = unique(edit_with(yn));