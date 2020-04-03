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

files = ["bea_supply.csv", "cfs.csv", "crude_oil.csv", "emissions.csv", "gsp_state.csv",
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
# df_mult = unique(df_units_map[:, [:to]]);

# unused_units = setdiff(df_units_map[:,:to], df_units[:,:units])
# unlisted_units = setdiff(df_units[:,:units], df_units_map[:,:to])
# listed_units = intersect(df_units[:,:units], df_units_map[:,:to])

# df_unused = filter(row -> row[:to] in unused_units, df_units_map)
# df_unlisted = filter(row -> row[:units] in unlisted_units, df_units)
# df_listed = sort(filter(row -> row[:units] in listed_units, df_units), :units)



# df_convert = unique(df_units_map[:,[:to]]);
# df_convert = edit_with(df_convert, Rename(:to, :cleaned))
# df_convert = edit_with(df_convert, Add.([:factor, :to], [1E0, ""]))


# df_convert[!,:factor] .= 1E0;


# df_mult = edit_with(df_mult, Add(:factor, 1))

# df_convert = DataFrame(from = ["millions of us dollars (USD)", "thousands of us dollars (USD)", "us dollars (USD)"],
#     factor = [1E0, 1E-3, 1E-6],
#     to = ["millions of us dollars (USD)", "millions of us dollars (USD)", "millions of us dollars (USD)"])


# df_mult = unique(dfu[occursin.("dollar", dfu[:,:to]),:], :to)[:, [:to]]

# df_mult = unique(df)

# dfu_std

# DataFrame(from = [])



############################################################################################
# EXPERIMENT: How do the sector and good sets compare?
# Answer: They are the same.
# path = "../data/windc_output/3_build"
# files = readdir(path)
# files = files[occursin.(".csv", files)]

# g = []
# s = []

# for f in files
#     df = CSV.read(joinpath(path, f))
#     global g = (:g in names(df)) ? sort(unique([g; df[:,:g]])) : g
#     global s = (:s in names(df)) ? sort(unique([s; df[:,:s]])) : s
# end

############################################################################################
# EXPERIMENT: Is there overlap in the gsp/pce/tech/bea maps?
# Answer: Some... Idk if this matters. Probably not.
#   trn - tech, pce, bea
#   (pce, rec) - pce, bea
#   (com, oil, res) - tech, bea
# path = "../data/mapsources/WiNDC/windc_datastream/core_maps/gams"

# df_tech = DataFrame()
# [global df_tech = unique(sort([df_tech; CSV.read(joinpath(path, f))[:,[:from,:to]]], :to))
#     for f in ["map_seds_energy_tech.csv", "map_emissions.csv"]]

# df_bea = sort(CSV.read(joinpath(path, "../bea_all.csv"))[:,[:from,:to,:category]], :to)
# df_gsp = sort(CSV.read(joinpath(path, "map_pce.csv"))[:,[:from,:to]], :to)
# df_pce = sort(CSV.read(joinpath(path, "map_gsp.csv"))[:,[:from,:to]], :to)

############################################################################################


# xf = readdlm(joinpath(path, "maps/mapcfs.map"), '\t', Any, ',')
# df = DataFrame(xf)

# function gams_to_dataframe(filename::String, colnames = false)
#     return gams_to_dataframe(readlines(filename); colnames = colnames)
# end

# function SLiDE.convert_type(::Type{DataFrame}, xf::Array{String,1}; colnames = false)

#     xf = [string.(split(reduce(replace, ["." => "|", "\t\"" => "|", "\"," => "", "\"" => ""],
#         init = row), "|")) for row in xf]
#     xf = permutedims(hcat(xf...))
#     ROWS, COLS = size(xf)

#     m = [match.(r"\((.*)\)", row) for row in xf]

#     df = vcat([DataFrame(Dict(jj => m[ii,jj] != nothing ? string.(split(m[ii,jj][1], ",")) : xf[ii,jj]
#         for jj in 1:COLS)) for ii in 1:ROWS]...)

#     df = edit_with(df, Rename.(names(df), colnames != false ? colnames :
#         [:missing; Symbol.(:missing_, 1:COLS-1)]))

#     return sort(df, reverse(names(df)[1:end-1]))
# end


