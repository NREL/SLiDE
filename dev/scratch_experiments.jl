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
files = joinpath.(path, files)
files = files[[9]]

df = read_file(files[1])

# units = DataFrame()

# for f in files
#     df = read_file(joinpath(path,f))
#     df = unique(df[:, occursin.(:units, names(df))])

#     d = Dict(:file => f, :units => [[col for col in eachcol(df)]...;])
#     global units = [units; DataFrame(d)]
# end

fseds = "../data/mapsources/WiNDC/windc_datastream/core_maps/seds.csv"
funits = "../data/mapsources/WiNDC/windc_datastream/core_maps/units.csv"

# dfs = read_file(fseds)
# dfs = edit_with(unique(dfs[:,[:units_abbv,:units]]), Rename.([:units_abbv,:units], [:from,:to]))

# df_units = read_file(funits)

# df_mult = unique(df_units[:, [:to]])
# df_mult = edit_with(df_mult, Add(:factor, 1))


["Drop", "Rename", "Group", "Match", "Melt", "Add", "Map", "Replace"]


# df = DataFrame(IOCode = ["22", "23"], Name = ["Utilities", "Construction"]);
# editor = [Rename(from = :IOCode, to = :input_code),
#           Rename(from = :Name,   to = :input_desc)]


# df = DataFrame(
#     input_code = ["Colorado", "22", "23", "Wisconsin", "22", "23"],
#     value = ["",1,2,"",3,4]);
# editor = Group(
#     file   = joinpath("parse", "regions.csv"),
#     from   = :from,
#     to     = :to,
#     input  = :input_code,
#     output = :region);
# edit_with(df, editor)




# df = DataFrame(IOCode = ["Colorado", "111CA", "113FF", "Colorado", "111CA", "113FF"],
#     Name = ["", "Farms", "Forestry, fishing, and related activities", "", "Farms", "Forestry, fishing, and related activities"])

y = read_file(joinpath(["..", "tests", "data", "test_datastream.yml"]...))
df = read_file(joinpath(["..", "tests", "data", "test_datastream.csv"]...))
df = edit_with(df, y["Rename"])


df2 = DataFrame(input_code = ["Colorado", "Fishing", "Logging", "Wisconsin", "Fishing", "Logging"],
    value = [missing,1,2,missing,3,4]);

# editor = Drop(col = :linenum, val = "all", operation = "==")
# df = edit_with(df, editor)


# y = read_file(joinpath(["..", "tests", "data", "test_datastream.yml"]...))
# df = read_file(y["Path"], y["CSVInput"])
# df = edit_with(df, [[y[k] for k in ["Drop"]]...;])

# editor = Rename(from = :IOCode, to = :input_code)
# df = edit_with(df, editor)

# editor = Group(file = joinpath("parse", "regions.csv"),
#     from = :from,
#     to = :to,
#     input = :input_code,
#     output = :region)
# df = edit_with(df, editor)

# editor = Match(on = r"\((?<input_code>.*)\)",
#     input = :input_code,
#     output = [:input_code])
# df = edit_with(df, editor)


# editor = Melt(on = [:input_code, :region],
#     var = :output_desc,
#     val = :value)
# df = edit_with(df, editor)


# df = DataFrame(output_desc = [fill("Utilities", (4,1)); fill("Construction", (4,1))],
#     value = [1:6; missing; 8],
#     input_code = string.([22,23,22,23,22,23,22,23]),
#     region = ["co", "co", "wi", "wi", "co", "co", "wi", "wi"])

# editor = Map(file = joinpath("parse", "bea.csv",
#     ))



# df = DataFrame(linenum = 1:2, input_code = ["A", "B"], value = [1, 2])
# editor = Drop(col = :linenum, val = "all", operation = "==")
# df = edit_with(df, editor)

# df = DataFrame(IOCode = ["A", "B"], value = [1, 2])
# editor = Rename(from = :IOCode, to = :input_code)
# df = edit_with(df, editor)

# df = DataFrame(linenum = 1:6,
#     input_code = ["Colorado", "NAICS: A", "NAICS: B", "Wisconsin", "A", "B"],
#     value = ["", 1, 2, "", 3, 4])
# editor = Group(file = joinpath("parse", "regions.csv"),
#     from = :from,
#     to = :to,
#     input = :input_code,
#     output = :region)
# df = edit_with(df, editor)




# dfn = read_file("../data/coremaps/parse/naics.csv")
# dfn1 = unique(dfn[.!occursin.(" ", dfn[:,:naics_desc]),:], :naics_desc)

# dfb = read_file("../data/coremaps/parse/bea.csv")
# dfb1 = unique(dfb[.!occursin.(" ", dfb[:,:bea_desc]),:], :bea_desc)


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


