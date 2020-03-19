using CSV
using DataFrames
using DelimitedFiles
using SLiDE

function SLiDE.read_file(file::String; colnames = false)
    if occursin(".map", file) | occursin(".set", file)
        return gams_to_dataframe(readlines(file); colnames = colnames)
    end
end

# function read_file(path::Array{String,1}, file::GAMSInput)
#     filepath = joinpath(path..., file.name)
#     xf = readlines(filepath)
#     df = gams_to_dataframe(xf; colnames = file.col)
#     return df
# end

path_in_1 = "../data/mapsources/WiNDC/windc_build/build_files/user_defined_schemes/"
files_in_1 = ["bluenote.set"]

path_in_2 = "../data/mapsources/WiNDC/windc_build/build_files/maps/"
files_in_2 = readdir(path_in_2)

# * * * * * * * 
# function gams_to_dataframe(xf::Array{String,1}; colnames = false)
#     df = DataFrame(missing = xf)
#     df = edit_with(df, Match(Regex("^(?<missing>\\S+)\\.(?<missing_1>[\\S^,]*)\\s*\"*(?<missing_2>[^\"]*),?"),
#         :missing, [:missing, :missing_1, :missing_2]))
    
#     df_set = match.(r"^\((.*)\)", df)
#     df_isset = df_set .!== nothing
    
#     ROWS, COLS = size(df)
#     df = [[DataFrame(Dict(k => df_isset[ii,k] ? string.(split(df_set[ii,k][1], ",")) : df[ii,k]
#         for k in names(df))) for ii in 1:size(df,1)]...;]
            
#     df = colnames != false ? edit_with(df, Rename.(names(df), colnames)) : df
#     return COLS > 1 ? sort(df, reverse(names(df)[1:2])) : sort(df)
# end

files_in = [joinpath.(path_in_1, files_in_1); joinpath.(path_in_2, files_in_2)]
xf = [[xf = readlines(files_in[ii])[1:2] for ii in 1:8]...;]
df = gams_to_dataframe(xf)