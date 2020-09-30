using CSV
using DataFrames
using DelimitedFiles
using SLiDE

# QUESTION: Do we have mapping capabilities for all units?
DATA_DIR = joinpath("data", "input")
MAP_DIR = joinpath("data", "coremaps", "parse")

# Read file names from output directory and isolate csv output files.
files = readdir(joinpath(SLiDE.SLIDE_DIR, DATA_DIR))
files = files[occursin.(".csv", files)]

# Read files and save all units present as well as the associated file name.
df_units = DataFrame()
for f in files
    df = read_file(joinpath(DATA_DIR,f))
    df = unique(df[:,:units])
    d = Dict(:file => f, :units => [[col for col in eachcol(df)]...;])
    global df_units = [df_units; DataFrame(d)]
end

# Read units map for comparison.
df_units_map = read_file(joinpath(MAP_DIR, "units.csv"))

# Units in the output DataFrame that are not in the map::
unlisted_units = setdiff(df_units[:,:units], df_units_map[:,:to])
df_unlisted = filter(row -> row[:units] in unlisted_units, df_units)