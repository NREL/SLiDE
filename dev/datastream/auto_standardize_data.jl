using CSV
using Dates
using DataFrames
using DelimitedFiles
using XLSX
using YAML

using SLiDE  # see src/SLiDE.jl

READ_DIR = joinpath("data", "readfiles")

files_parse = XLSXInput("generate_yaml.xlsx", "parse", "M1:M180", "parse")

files_parse = write_yaml(READ_DIR, files_parse)
y_read = [read_file(files_parse[ii]) for ii in 1:length(files_parse)]

# files_parse = run_yaml(files_parse)
# df = [read_file(joinpath(y_read[ii]["PathOut"]...)) for ii in 1:length(y_read)]

# ******************************************************************************************
# EDIT MANUALLY TO CHECK:
ii_file = length(y_read)
y = y_read[ii_file];
files = [[y[k] for k in collect(keys(y))[occursin.("Input", keys(y))]]...;]

# for ii_input in 1:1
#     file = files[ii_input]
#     println(file)
#     global df = read_file(y["PathIn"], file)
    
#     "Drop"     in keys(y) && (df = edit_with(df, y["Drop"]))
#     "Rename"   in keys(y) && (df = edit_with(df, y["Rename"]))
#     "Group"    in keys(y) && (df = edit_with(df, y["Group"]))
#     "Match"    in keys(y) && (df = edit_with(df, y["Match"]))
#     "Melt"     in keys(y) && (df = edit_with(df, y["Melt"]))
#     "Add"      in keys(y) && (df = edit_with(df, y["Add"]))
#     "Map"      in keys(y) && (df = edit_with(df, y["Map"]))
#     "Replace"  in keys(y) && (df = edit_with(df, y["Replace"]))
#     "Drop"     in keys(y) && (df = edit_with(df, y["Drop"]))
#     "Operate"  in keys(y) && (df = edit_with(df, y["Operate"]))
#     "Describe" in keys(y) && (df = edit_with(df, y["Describe"], file))
#     "Order"    in keys(y) && (df = edit_with(df, y["Order"]))
# end


file = files[1]
df = read_file(y["PathIn"], file)

EDITS = ["Rename", "Group", "Match", "Melt", "Add", "Map", "Replace", "Drop", "Operate", "Order"]

# Find which of these edits are represented in the yaml file of defined edits.
KEYS = intersect(EDITS, collect(keys(y)))

# ("Drop" in KEYS && all(get_val.(y["Drop"]) .== "all")) && (KEYS = ["Drop"; setdiff(KEYS, ["Drop"])])
if ("Drop" in KEYS && all(get_val.(y["Drop"]) .== "all"))
    KEYS = ["Drop"; setdiff(KEYS, ["Drop"])]
end

NKEEP = 10;
df = df[df[:,:State] .== "WISCONSIN", :][1:NKEEP,:]

pathout = joinpath(SLIDE_DIR,"data","output_example")
CSV.write(joinpath(pathout, string("nass_00.csv")), df)

for ii in 1:length(KEYS)
    editname = lowercase(KEYS[ii])
    editfile = string("nass_0$ii", "_$editname.csv")

    global df = edit_with(df, y[KEYS[ii]])
    if editname == "operate"
        cols = [:yr,:r,:n,:value,:units,:value_0,:factor,:units_0,:units_factor]
        global df = df[:,cols]
    end
    CSV.write(joinpath(pathout, editfile), df)
    # show(first(df,4))
end

# first(df,4)