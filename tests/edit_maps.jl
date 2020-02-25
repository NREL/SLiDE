using Complementarity
using CSV
using DataFrames
using JuMP
using Revise
using XLSX
using YAML

using SLiDE  # see src/SLiDE.jl

DATA_DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "data")); 
MAP_DIR = joinpath(DATA_DIR, "coremaps");
WINDC_DIR = joinpath(MAP_DIR, "windc");
GAMS_DIR = joinpath(WINDC_DIR, "gams");

# filename = "bea_all_detailed.csv"
# df = SLiDE.read_file(joinpath(WINDC_DIR, filename));

# ############################################################################################

"""
    Metro Area Maps
"""
y = SLiDE.read_file(joinpath(DATA_DIR, "readfiles", "1_map", "cfs_area.yml"));
df = SLiDE.edit_with(y)
CSV.write(joinpath(y["PathOut"]...), df)

"""
    US Region Maps
"""

y = SLiDE.read_file(joinpath(DATA_DIR, "readfiles", "1_map", "state_to_region_01.yml"));
CSV.write(joinpath(y["PathOut"]...), SLiDE.edit_with(y));

y = SLiDE.read_file(joinpath(DATA_DIR, "readfiles", "1_map", "state_to_region_02.yml"))
CSV.write(joinpath(y["PathOut"]...), df2);

y = SLiDE.read_file(joinpath(DATA_DIR, "readfiles", "1_map", "state_to_region_03.yml"))
df3 = SLiDE.edit_with(y);
sort!(df3, reverse(names(df3)));
CSV.write(joinpath(y["PathOut"]...), df3);

"""
## Region Maps

- Add leading zeros to single-digit integer codes (for CFS state mapping)
- Add CFS codes for Canada/Mexico/Other
"""
# filename = "regions.csv"
# df = SLiDE.read_file(joinpath(WINDC_DIR, filename));

# df_pce = SLiDE.read_file(joinpath(DATA_DIR, "datasources", "PCE", "SAEXP1_1997_2017_ALL_AREAS_.csv"));
# df_pce = copy(SLiDE.edit_with(df_pce, Rename.([:GeoFIPS,:GeoName], [:a,:b]))[:, [:a,:b]]);
# dropmissing!(unique!(df_pce), :b);

# df_pce = SLiDE.edit_with(df_pce, Map("regions.csv", :from, :to, :to, :to));

# # Add mapping for states with leading zeros, relevant for CFS.
# df0 = copy(df[length.(df[:,:from]) .== 1,:])
# df0[!,:from] .= string.("0", df0[:,:from]);
# df = vcat(df, df0);

# # Add mapping for Canada, Mexico, and "Other", relevant for CFS.
# df = vcat(df,DataFrame(from = ["C","M","O"], to = ["canada","mexico","other"]));

# sort!(df,[:to,:from])
# CSV.write(joinpath(MAP_DIR, filename), df);

# """
# ## SGF Maps

# # - Remove line
# """
# filename = "sgf.csv"
# df_windc = SLiDE.read_file(joinpath(WINDC_DIR, filename));

# # Make horizontally-concatennated DataFrames one, normalized database.
# # None of the Edit DataTypes are quite equiped to handle this.
# cols = string.(names(df_windc));
# df_windc = df_windc[:, Symbol.(cols[.!occursin.("line_num", cols)])]

# cols = string.(names(df_windc));
# df = DataFrame();

# for yy in string.(1997:2016)
#     df_temp = copy(df_windc[:, Symbol.(cols[occursin.(yy, cols)])]);
#     df_temp = SLiDE.edit_with(df_temp, Rename.(names(df_temp), [:sgf,:desc,:units]))
#     global df = vcat(df, df_temp);
# end

# df = dropmissing(df);
# df = unique(df, :sgf);

# # Edit the rest with edit_with() features...
# # df_map = SLiDE.read_file(joinpath(GAMS_DIR, "map_sgf.csv"))
# df = SLiDE.edit_with(df, Map(joinpath(GAMS_DIR, "map_sgf.csv"), :from, :to, :desc, :code));
# df = SLiDE.edit_with(df, Order([:sgf,:code,:desc,:units], [Any, String, String, String]));

# CSV.write(joinpath(MAP_DIR, filename), df);

############################################################################################
# HARD-CODED MAPS

"""
## Hazmat
Data added from CFS supplemental files.
Hard-coded in windc_datastream/parse_2012cfs.py.
"""
filename = "hazmat.csv"
df = DataFrame(
    code = ["P", "H", "N"],
    desc = ["Class 3 HAZMAT (flammable liquids)", "Other HAZMAT", "Not HAZMAT"]
)
CSV.write(joinpath(MAP_DIR, filename), df)

"""
## Carbon Content
Hard-coded in windc_datastream/all_gamsify.py.
Might transfer to general map convert_units.csv.
"""
filename = "carbon_content.csv"
df = DataFrame(
    source = ["col", "gas", "oil", "cru"],
    factor = [95, 53, 70, 70],
    units = fill("kilograms CO2 per million btu", 4)
)
CSV.write(joinpath(MAP_DIR, filename), df)