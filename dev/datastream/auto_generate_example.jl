using CSV
using Dates
using DataFrames
using DelimitedFiles
using XLSX
using YAML

using SLiDE  # see src/SLiDE.jl

READ_DIR = joinpath("data", "readfiles")
NROW = 4;

# ******************************************************************************************
files_parse = XLSXInput("generate_yaml.xlsx", "parse", "M1:M180", "parse")
files_parse = write_yaml(READ_DIR, files_parse)

y = read_file(files_parse[1])
files = [[y[k] for k in collect(keys(y))[occursin.("Input", keys(y))]]...;]
file = files[1]

# Find which of these edits are represented in the yaml file of defined edits.
EDITS = ["Rename", "Group", "Match", "Melt", "Add", "Map", "Replace", "Drop", "Operate", "Order"]
KEYS = intersect(EDITS, collect(keys(y)))
if ("Drop" in KEYS && all(get_val.(y["Drop"]) .== "all"))
    KEYS = ["Drop"; setdiff(KEYS, ["Drop"])]
end

# Read data file and shorten to appropriate length.
df = read_file(y["PathIn"], file)
df = df[df[:,:State] .== "WISCONSIN", :][1:NROW,:]

# 
desc = "nass"
pathout = joinpath(SLIDE_DIR, "data", "output_example")
CSV.write(joinpath(pathout, desc * "_00.csv"), df)

for ii in 1:length(KEYS)-1
    # editname = lowercase(KEYS[ii])
    editfile = desc * "_" * lpad(ii,2,'0') * "_" * lowercase(KEYS[ii]) * ".csv"

    global df = edit_with(df, y[KEYS[ii]])
    
    # Ugly, but fine for now.
    # if (desc == "nass" && editname == "operate")
    #     cols = [:yr,:r,:n,:value,:units,:value_0,:factor,:units_0]
    #     global df = df[:,cols]
    # end
    # CSV.write(joinpath(pathout, editfile), df)
    # show(first(df,4))
end

x = y["Operate"]
cols = [setdiff(names(df), unique([x.from; x.to; x.input; x.output]))[1:end-2]; x.output; x.from]
[inp in ensurearray(x.output) ? Symbol(inp, :_0) : inp for inp in x.input]