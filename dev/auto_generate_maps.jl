using CSV
using Dates
using DataFrames
using DelimitedFiles
using XLSX
using YAML

using SLiDE  # see src/SLiDE.jl

READ_DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "data", "readfiles"))

files_map = [XLSXInput("generate_yaml.xlsx", "map_parse", "B1:Z150", "map_parse")]
            #  XLSXInput("generate_yaml.xlsx", "map_scale", "B1:Z150", "map_scale")]

files_map = write_yaml(READ_DIR, files_map)
files_map = run_yaml(files_map)

# include("adjust_maps.jl")

# ******************************************************************************************
#   N E W
# ******************************************************************************************
# df = read_file("../data/output/gsp_state.csv")
# dfm = read_file("../data/mapsources/WiNDC/windc_build/build_files/maps/mapgsp.map")
# x = Map2("../mapsources/WiNDC/windc_build/build_files/maps/mapgsp.map",
#     [:missing],
#     [:missing_1, :missing_2],
#     [:industry_id],
#     [:windc_code, :windc_desc])
# # df = edit_with(df, x)[:,[:industry_id,:industry_code,:windc_code,:industry_desc, :windc_desc]]
# dfw = read_file("../data/windc_output/2_stream/gsp_units.csv");

# ******************************************************************************************
# df = read_file("../data/output/pce.csv");
# dfm = read_file("../data/mapsources/WiNDC/windc_build/build_files/maps/mappce.map"; colnames = [:a,:b,:c]);
# first(df,4)