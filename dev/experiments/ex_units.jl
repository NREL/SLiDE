using CSV
using DataFrames
using DelimitedFiles
using SLiDE

############################################################################################
# EXPERIMENT: Units?
# Answer: 
path = "../data/output"
files = readdir(path)
files = files[occursin.(".csv", files)]

files = ["supply.csv", "cfs.csv", "crude_oil.csv", "emissions.csv", "gsp_state.csv", "gsp_metro.csv", "gsp_county.csv",
    "heatrate.csv", "nass.csv", "pce.csv", "seds.csv", "sgf_1997.csv", "utd.csv"];

df_units = DataFrame()

for f in files
    
    df = read_file(joinpath(path,f))
    # df = unique(df[:, occursin.(:units, names(df))])
    df = unique(df[:,:units])
    d = Dict(:file => f, :units => [[col for col in eachcol(df)]...;])
    global df_units = [df_units; DataFrame(d)]
end

# fseds = "../data/mapsources/WiNDC/windc_datastream/core_maps/seds.csv"
# funits = "../data/mapsources/WiNDC/windc_datastream/core_maps/units.csv"
# fseds = "../data/output/seds.csv"
funits = "../data/coremaps/parse/units.csv"

# df_seds = read_file(fseds)
# dfs = edit_with(unique(dfs[:,[:units_abbv,:units]]), Rename.([:units_abbv,:units], [:from,:to]))

df_units_map = read_file(funits);

# unused_units = setdiff(df_units_map[:,:to], df_units[:,:units])
# unlisted_units = setdiff(df_units[:,:units], df_units_map[:,:to])
# listed_units = intersect(df_units[:,:units], df_units_map[:,:to])

# df_unused = filter(row -> row[:to] in unused_units, df_units_map)
# df_unlisted = filter(row -> row[:units] in unlisted_units, df_units)
# df_listed = sort(filter(row -> row[:units] in listed_units, df_units), :units)