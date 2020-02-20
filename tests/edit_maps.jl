using Complementarity
using CSV
using DataFrames
using JuMP
using Revise
using XLSX
using YAML

using SLiDE  # see src/SLiDE.jl

"""
    Region Maps
"""
df = SLiDE.read_file("../data/coremaps/windc/regions.csv");

# Add mapping for states with leading zeros, relevant for CFS.
df0 = copy(df[length.(df[:,:from]) .== 1,:])
df0[!,:from] .= string.("0", df0[:,:from]);
df = vcat(df, df0);

# Add mapping for Canada, Mexico, and "Other", relevant for CFS.
df = vcat(df,DataFrame(from = ["C","M","O"], to = ["canada","mexico","other"]));

sort!(df,[:to,:from])
CSV.write("../data/coremaps/regions.csv", df);



# """
#     SGF Maps
# """
# df_windc = SLiDE.read_file("../data/coremaps/windc/sgf.csv");

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
# df = SLiDE.edit_with(df, Map("windc/gams/map_sgf.csv", :from, :to, :desc, :code));
# df = SLiDE.edit_with(df, Order([:sgf,:code,:desc,:units], [Any, String, String, String]));

# CSV.write("../data/coremaps/sgf.csv", df);