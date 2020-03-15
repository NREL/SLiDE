using CSV
using DataFrames
using DelimitedFiles
using SLiDE

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
path = "../data/mapsources/WiNDC/windc_build/build_files/"

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


