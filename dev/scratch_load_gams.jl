using CSV
using DataFrames
using DelimitedFiles
using SLiDE

# function SLiDE.read_file(file::String; colnames = false)
#     if occursin(".map", file) | occursin(".set", file)
#         return gams_to_dataframe(readlines(file); colnames = colnames)
#     end
# end

function SLiDE.read_file(path::Array{String,1}, file::GAMSInput; shorten = false)
    filepath = joinpath(path..., file.name)
    xf = readlines(filepath)
    df = gams_to_dataframe(xf; colnames = file.col)
    return df
end

path_in_1 = "../data/mapsources/WiNDC/windc_build/build_files/user_defined_schemes/"
files_in_1 = ["bluenote.set"]

path_in_2 = ["../data/mapsources/WiNDC/windc_build/build_files/maps/"]
files_in_2 = readdir(path_in_2[1])

# glist = [GAMSInput(f, [:s1,:s2,:label]) for f  in files_in_2]
# read_file(path_in_2, glist[1])

files_in = [joinpath.(path_in_1, files_in_1); joinpath.(path_in_2[1], files_in_2)]
xf = [[xf = readlines(files_in[ii]) for ii in 3]...;]
df = gams_to_dataframe(xf)