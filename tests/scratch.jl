using Complementarity
using CSV
using DataFrames
using DelimitedFiles
using JuMP
using Revise
using XLSX
using YAML

using SLiDE  # see src/SLiDE.jl

# READ YAML FILE.
READ_DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "data", "readfiles", "2_standardize"));
# DATA_DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "data", "datasources", "USATradeOnline"));
y = SLiDE.read_file(joinpath(READ_DIR, "usatrd.yml"));

# df = CSV.read(joinpath(DATA_DIR, "State Exports by NAICS Commodities.csv"); header = 4)
# y["Path"] = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", y["Path"]...))




# v = df[1,:commodity]
# r = match(r"(?<aggr>.*)\&(?<sect>.*)", v)

# m = r"[0-9]+"

# x = y["Split"]
# NEWCOL = length(x.output)

# df = SLiDE.edit_with(df, Add.(x.output, fill("",size(x.output))))
# lst = split.(df[:, x.input], Regex(x.on));
# 
# [df[!, x.output[ii]] .= strip.([length(m) >= ii ? m[ii] : "" for m in lst])
#     for ii in 1:length(x.output)]

# x.remove ? df[!,x.input] .= [strip(string(string.(strip.(el)," ")...))
#     for el in lst] : nothing




# df = SLiDE.edit_with(y)

# df0 = SLiDE.read_file(y["Path"], y["CSVInput"])
# df = df0[1:10,:];
# # df = df0

# df = SLiDE.edit_with(df, y["Rename"]);
# # df = SLiDE.edit_with(df, y["Melt"]);
# df = SLiDE.edit_with(df, y["Add"]);
# df = SLiDE.edit_with(df, y["Map"]);
# df = SLiDE.edit_with(df, y["Replace"]);
# df = SLiDE.edit_with(df, y["Order"]);

# show(df)

# x = y["Map"][2]
# cols = unique(push!(names(df), x.output))
# df_map = SLiDE.read_file(x);

# # Rename the input column in the DataFrame to edit to match that in the mapping df.
# # This approach was taken as opposed to editing the mapping df to avoid errors in case
# # the input and output column names are the same. Such is the case if mapping is used to
# # edit column values for consistency without adding a new column to the DataFrame.
# # A left join is used to prevent data loss in the case that a value in the input df is
# # NOT in the input mapping column. If this is the case, this value will map to "missing".
# # Remove excess blank space from the input column to ensure consistency when joining.
# df = SLiDE.edit_with(df, Rename(x.input, x.from));

# all(typeof.(df_map[:,x.from]) .== String) ? df[!,x.from] .= convert_type.(String, df[:,x.from]) : nothing

# df[!, x.from] .= strip.(df[:, x.from]);
# df = join(df, df_map, on = x.from, kind = :left, makeunique = true);

# # show(first(df[:,[x.from,x.to]],3))

# df[ismissing.(df[:,x.to]), x.to] .=
#     convert_type.(String, df[ismissing.(df[:,x.to]), x.from])

# # Return the DataFrame with the columns saved at the top of the method.
# df = x.input == x.output ? SLiDE.edit_with(df, Rename(x.to, x.output)) :
#                             SLiDE.edit_with(df, Rename.([x.from, x.to], [x.input, x.output]))
# return df[:, cols]


# ############################################################################################

# # df = SLiDE.edit_with(df, y["Rename"]);
# # df = SLiDE.edit_with(df, y["Map"]);
# # df = SLiDE.edit_with(df, y["Split"]);

# # df = SLiDE.edit_with(df, y["Split"])
# # df = SLiDE.edit_with(df, y["Split"])

# # Base.lowercase(x::Symbol) = Symbol(lowercase(string(x)))
# # Base.uppercase(x::Symbol) = Symbol(uppercase(string(x)))

# # x = y["Rename"]

# # function z(df::DataFrame, x::Rename)

# #     # Explicitly rename the specified column if it exists in the dataframe.
# #     x.from in names(df) ? rename!(df, x.from => x.to) :

# #     # If we are, instead, changing the CASE of all column names...
# #         lowercase(x.to) == :lower ?
# #             df = SLiDE.edit_with(df, Rename.(names(df), lowercase.(names(df)))) :
# #             lowercase(x.to) == :upper ?
# #                 df = SLiDE.edit_with(df, Rename.(names(df), uppercase.(names(df)))) :
# #                 nothing

# #     return df
# # end

# # df = z(df, x)
# # show(first(df,3))
# # show("")

# # df = z(df, Rename(:lower,:upper))
# # show(first(df,3))

# # df = DataFrame(a = ["1", 1])
# # CSV.write("test.csv", df)

# # df2 = CSV.read("test.csv")