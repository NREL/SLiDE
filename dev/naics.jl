using CSV
using Dates
using DataFrames
using DelimitedFiles
using XLSX
using YAML

using SLiDE  # see src/SLiDE.jl

# path = ["data", "datasources", "BEA_2007_2012"]
# x1 = XLSXInput("Supply_2007_2012_DET.xlsx", "NAICS Codes", "A5:B1025", "sector")

READ_DIR = joinpath("data", "readfiles")

files_map = [
    XLSXInput("generate_yaml.xlsx", "map_scale", "K1:K150", "map_scale"),
]

files_map = write_yaml(READ_DIR, files_map)
y_read = [read_file(files_map[ii]) for ii in 1:length(files_map)]

# files_map = run_yaml(files_map)
# df = [read_file(joinpath(y_read[ii]["PathOut"]...)) for ii in 1:length(y_read)];

# df = read_file(joinpath(y_read[1]["PathOut"]...))

# # Unstack.
# cols = [:bea_code, :bea_desc]
# levels = ["sector", "summary", "underlying", "detail"]
# df_bea = [[edit_with(unique(copy(df[:,occursin.(level, names(df))])),
#         [Rename.(names(df)[occursin.(level, names(df))], cols); Add(:bea_level, level)])
#     for level in levels]...;]
# df_pnaics = read_file("data/coremaps/parse/naics.csv")
# df_snaics = read_file("data/coremaps/scale/naics_codes.csv")



# include(joinpath(SLIDE_DIR, "dev", "datastream", "adjust_maps.jl"))

# ******************************************************************************************
# EDIT MANUALLY TO CHECK:
ii_file = length(y_read);
y = y_read[ii_file];
files = [[y[k] for k in collect(keys(y))[occursin.("Input", keys(y))]]...;]

for ii_input in 1:1
    file = files[ii_input]
    println(file)
    global df = read_file(y["PathIn"], file)

    "Drop"     in keys(y) && (df = edit_with(df, y["Drop"]))
    "Rename"   in keys(y) && (df = edit_with(df, y["Rename"]))
    "Group"    in keys(y) && (df = edit_with(df, y["Group"]))
    "Match"    in keys(y) && (df = edit_with(df, y["Match"]))
    "Melt"     in keys(y) && (df = edit_with(df, y["Melt"]))
    "Add"      in keys(y) && (df = edit_with(df, y["Add"]))
    "Map"      in keys(y) && (df = edit_with(df, y["Map"]))
    "Replace"  in keys(y) && (df = edit_with(df, y["Replace"]))
    "Drop"     in keys(y) && (df = edit_with(df, y["Drop"]))
    "Operate"  in keys(y) && (df = edit_with(df, y["Operate"]))
    "Describe" in keys(y) && (df = edit_with(df, y["Describe"], file))
    "Order"    in keys(y) && (df = edit_with(df, y["Order"]))
end


function _expand_range(x::T) where T <: AbstractString
    if occursin("-", x)
        if all(string(strip(x)) .!= ["31-33", "44-45", "48-49"])
            x = split(x, "-")
            x = ensurearray(convert_type(Int, x[1]):convert_type(Int, x[1][1:end-1] * x[end][end]))
        end
    else
        x = convert_type(Int, x)
    end
    return x
end

function _expand_range(x::String)
    if match(r"\D", x) !== nothing
        x = [_expand_range.(split(x, ","))...;]
    else
        x = convert_type(Int, x)
    end
    return x
end

_expand_range(x::Missing) = x

# ******************************************************************************************
# MAP NAICS
cols = names(df)
col_set = [:naics_code]


ROWS, COLS = size(df)
df = [[DataFrame(Dict(cols[jj] =>
        cols[jj] in col_set ? _expand_range(df[ii,jj]) : df[ii,jj]
    for jj in 1:COLS)) for ii in 1:ROWS]...;]
df = edit_with(df[:,cols],
    Map("parse/naics.csv", [:naics_code], [:naics_level, :naics_desc], [:naics_code], [:naics_level, :naics_desc]))

# ******************************************************************************************
# UNSTACK BEA
cols_std = [:bea_code, :bea_desc]
cols = [:bea_code, :naics_code, :bea_level, :naics_level, :bea_desc, :naics_desc]

levels = ["sector", "summary", "underlying", "detail"]

df_map = [[edit_with(unique(copy(df[:, names(df)[occursin.(level, names(df))]])),
        [Rename.(names(df)[occursin.(level, names(df))], cols_std); Add(:bea_level, level)])
    for level in levels]...;]

# df_map = df[:,cols]

# ******************************************************************************************
# full list of windc codes and desciptions, with levels for scaling (normal form)
#   names: windc_code, windc_desc, windc_level
cols_map = [:bea_code, :naics_code, :sctg_code, :bea_windc_code, :naics_windc_code, :sctg_windc_code, :bea_level, :naics_level, :bea_desc, :naics_desc, :sctg_desc]

# Add WINDC codes to BEA.
fb_bea = joinpath("parse", "bea.csv")
x_bea = Map(fb_bea, [:bea_code], [:bea_windc,:category], [:bea_code], [:bea_windc_code, :bea_category])

df_map = edit_with(df_map, x_bea)

df_temp = unique(copy(df[:,[:detail_code, :naics_code, :naics_desc, :naics_level]]))
df_map = join(df_map, df_temp, on = Pair(:bea_code, :detail_code), kind = :left)

# Add NAICS
x_naics = Map(joinpath("parse", "naics.csv"), [:naics_code], [:naics_desc, :naics_level], [:naics_code], [:naics_desc, :naics_level])
x_naics_windc = Map(joinpath("bluenote", "utd_naics.csv"), [:naics_code], [:windc_code], [:naics_code], [:naics_windc_code])

df_map = edit_with(df_map, x_naics; kind = :outer)
df_map = edit_with(df_map, x_naics_windc; kind = :outer)

# ******************************************************************************************
# Add SCTG codes, etc.
df_sctg = read_file(joinpath("data","mapsources","Manual","sctg_to_naics.csv"))
x_sctg_windc = Map(joinpath("bluenote", "cfs_sctg.csv"), [:sctg_code], [:sctg_desc, :windc_code], [:sctg_code], [:sctg_desc, :sctg_windc_code])
df_sctg = edit_with(df_sctg, x_sctg_windc; kind = :outer)

# df_map = join(df_map, df_sctg, on = :naics_code, kind = :outer)



df_map = sort(df_map[:, intersect(cols_map, names(df_map))])