using CSV
using DataFrames
using DelimitedFiles
using SLiDE

# GET SETS FROM WINDC.
path_windc = joinpath("..","..","WiNDC","windc_build","build_files");
files_build = readdir(path_windc)
files_build = files_build[occursin.(".gms", files_build)];

files_user = readdir(joinpath(path_windc, "user_defined_schemes"));
files_user = files_user[occursin.(".map", files_user)];

files = [files_build; joinpath.("user_defined_schemes", files_user)];

df_sets = DataFrame();

f = files[1]

for f in files
    x = readlines(joinpath(path_windc, f))
    NROW = length(x);

    df_temp = DataFrame(text = x, file = fill(f, size(x)), line = 1:length(x))
    df_temp = df_temp[match.(r"^SET", df_temp[:,:text]) .!== nothing, :]

    # Get set info.
    m = [r"(?<text>.*);", r"(?<text>.*);"];

    x = Match(r"(?<text>.*);", :text, [:text])

    [df_temp = edit_with(df_temp, Match(m, :text, [:text]))
        for m in [r"(?<text>.*);", r"(?<text>.*) /"]]

    df_temp = edit_with(df_temp, Match(r"^SET\s+(?<set_var>\S+)\s*\"*(?<set_desc>[^\"]*)",
        :text, [:set_var, :set_desc]))

    global df_sets = [df_sets; df_temp]
end

df_sets = sort(df_sets[:,[:set_var,:set_desc,:file,:line,:text]], [:set_var,:file])

# for ii in 1:length(x)
#     if x[ii]
# end