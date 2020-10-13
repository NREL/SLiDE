using SLiDE
using DataFrames

dfseds = read_file("data/input/seds.csv")
dfseds = read_file("data/input/seds.csv")

dfmsn = read_file("data/coremaps/parse/msn.csv")

path = joinpath(SLIDE_DIR,"data_save","mapsources","WiNDC","windc_build","seds_files")
files = readdir(path)
d = Dict(Symbol(f[1:end-4]) => read_file(joinpath(path, f)) for f in files)