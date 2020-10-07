using CSV
using Dates
using DataFrames
using DelimitedFiles
using XLSX
using YAML
using InteractiveUtils
const IU = InteractiveUtils

using SLiDE  # see src/SLiDE.jl

READ_DIR = joinpath("data", "readfiles")

files_map = XLSXInput("generate_yaml.xlsx", "map_experiment", "B1:D150", "map_experiment")
files_map = write_yaml(READ_DIR, files_map)
y_read = [read_file(files_map[ii]) for ii in 1:length(files_map)]

ind = Symbol.([m[:ind] for m in match.(r"\_(?<ind>\w*).yml", files_map)])
files_map = run_yaml(files_map)
df = [read_file(joinpath(y_read[ii]["PathOut"]...)) for ii in 1:length(y_read)];

cols = names.(df)

# for ii in 1:length(df)
#     global df[ii] = sort(edit_with(df[ii],
#         Rename.(propertynames(df[ii])[2:end], Symbol.(propertynames(df[ii])[2:end], :_, ii))))
# end

"""
Check 1: Are the two WiNDC BEA maps the same? -- YES
"""
cols_windc = intersect(names.(df[1:2])...)

df_windc = [edit_with(df[ii][:,cols_windc],
    Rename.(cols_windc[2:end], Symbol.(cols_windc[2:end], :_, ind[ii]))) for ii in 1:2]
cols_windc = sort(unique([names.(df_windc)...;]))

df_windc = outerjoin(df_windc[1], df_windc[2], on = :bea_code)
df_windc = df_windc[:,cols_windc]

df_windc_miss = df_windc[ismissing.(df_windc[:,2]), :]
dropmissing!(df_windc)

df_windc[!,:windc_det_equal] .= df_windc[:,2] .== df_windc[:,3]
df_windc[!,:windc_sum_equal] .= df_windc[:,4] .== df_windc[:,5]