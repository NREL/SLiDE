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


# function SLiDE.edit_with(file::T, y::Dict{Any,Any}; shorten::Bool=false) where T<:File
#     df = read_file(y["Path"], file; shorten=shorten);

#     # Specify the order in which edits must occur.
#     EDITS = ["Drop", "Rename", "Group", "Match", "Melt", "Add", "Map", "Map2", "Join", "Replace", "Drop"];

#     # Find which of these edits are represented in the yaml file of defined edits.
#     KEYS = intersect(EDITS, [k for k in keys(y)]);
#     "Drop" in KEYS ? push!(KEYS, "Drop") : nothing

#     [df = edit_with(df, y[k]) for k in KEYS];
    
#     # Add a descriptor to identify the data from the file that was just added.
#     # Then, reorder the columns and set them to the correct types.
#     # This ensures consistency when concattenating.
#     df = "Describe" in keys(y) ? edit_with(df, y["Describe"], file) : df;
#     df = "Order" in keys(y) ? edit_with(df, y["Order"]) : df;
#     return df
# end


# function SLiDE.edit_with(df::DataFrame, x::Drop)
    
#     if x.col in names(df)

#         if occursin(lowercase(x.val), "all")
#             df = df[:, setdiff(names(df), [x.col])]

#         else

#             if typeof(x.val) == String
#                 occursin(lowercase(x.val), "all") ? df = df[:, setdiff(names(df), [x.col])] :
#                     occursin(lowercase(x.val), "missing") ? dropmissing!(df, x.col) :
#                         occursin(lowercase(x.val), "unique") ? unique!(df, x.col) : nothing
#             end
#             # !!!! Add error if broadcast not possible.
#             df = df[.!broadcast(datatype(x.operation), df[:,x.col], x.val), :]
#         end
#     end
#     return df
# end


############################################################################################
# y = read_file(joinpath(READ_DIR, "cfs.yml"))
# # df = read_file(y["Path"], y["CSVInput"])
# df = unique(edit_with(y))

# x_cbsa = Map2("scale/census_cbsa.csv", [:state_code, :cbsa_code], [:state_desc, :cbsa_desc], [:orig_state, :orig_ma], [:a, :b])
# df_cbsa = dropmissing!(edit_with(copy(df), x_cbsa), x_cbsa.to)
# println("CBSA: ", size(df_cbsa))

# x_csa = Map2("scale/census_cbsa.csv", [:state_code, :csa_code], [:state_desc, :csa_desc], [:orig_state, :orig_ma], [:a, :b])
# df_csa = dropmissing!(edit_with(copy(df), x_csa), x_csa.to)
# println("CSA: ", size(df_csa))



############################################################################################
# GSP - METRO
# y = read_file(joinpath(READ_DIR, "gsp_metro.yml"))
# df = read_file(y["Path"], y["CSVInput"])
# df = unique(edit_with(y))


############################################################################################
# y = read_file(joinpath(READ_DIR, "gsp_state.yml"))
# df = read_file(y["Path"], y["CSVInput"])
# df = edit_with(y)

# x = y["Drop"]
# df = edit_with(df, y["Drop"])




############################################################################################
# NASS - WORKING
# y = read_file(joinpath(READ_DIR, "nass.yml"));
# df = read_file(y["Path"], y["CSVInput"]);
# df = edit_with(df, y["Rename"])
# df = edit_with(df, y["Add"])
# df = edit_with(df, y["Match"])
# df = edit_with(df, y["Map"])
# df = edit_with(df, y["Replace"])
# df = edit_with(df, y["Order"])
# df = edit_with(y)

############################################################################################
# PCE
# y = read_file(joinpath(READ_DIR, "pce.yml"))
# # df = read_file(y["Path"], y["CSVInput"])
# df = unique(edit_with(y))


y = read_file(joinpath(READ_DIR, "seds.yml"))
df = read_file(y["Path"], y["CSVInput"])
df = unique(edit_with(y))

############################################################################################
# SGF - WORKING
# y = read_file(joinpath(READ_DIR, "sgf_1997.yml"));
# df = read_file(y["Path"], y["XLSXInput"]);
# df = edit_with(df, y["Rename"])
# df = edit_with(df, y["Group"])
# df = edit_with(df, y["Map"])
# df = unique(edit_with(y))

# x = y["Map2"]
# df_map = read_file(x)
# df_map = dropmissing(unique(df_map[:,unique([x.from; x.to])]))

# y = read_file(joinpath(READ_DIR, "sgf_1998.yml"));
# df = unique(edit_with(y))

# y = read_file(joinpath(READ_DIR, "sgf_1999-2011.yml"));
# df = read_file(y["Path"], y["XLSXInput"][1]);
# df = unique(edit_with(y));

# y = read_file(joinpath(READ_DIR, "sgf_2012-2013.yml"));
# df = read_file(y["Path"], y["CSVInput"]);
# df = edit_with(df, y["Rename"])
# df = edit_with(df, y["Melt"])
# df = edit_with(df, y["Map"])
# df = edit_with(df, y["Drop"])
# df = edit_with(df, y["Replace"])
# df = unique(edit_with(y))

# y = read_file(joinpath(READ_DIR, "sgf_2014-2016.yml"));
# df = read_file(y["Path"], y["CSVInput"][1]);
# df = edit_with(df, y["Rename"])
# df = edit_with(df, y["Map"])
# df = edit_with(df, y["Order"])
# df = unique(edit_with(y))

############################################################################################
# USA TRADE - WORKING
# y = read_file(joinpath(READ_DIR, "usatrd.yml"));
# df = read_file(y["Path"], y["CSVInput"][1]);
# df = edit_with(df, y["Rename"])
# df = edit_with(df, y["Map"])
# df = edit_with(df, y["Match"])
# df = unique(edit_with(y))


# to_drop = ["Population",
#         "General Expenditure, by Function:",
#         "Personal income",
#         "Total Expenditure - General Expenditure - Intergovernmental General Expenditure",
#         "Insurance Trust Expenditure - Unemployment Compensation Systems",
#         "Insurance Trust Expenditure - Workers' Compensation Systems",
#         "Insurance Trust Expenditure - State-Administered Pension Systems",
#         "Insurance Trust Expenditure - Other Insurance Trust Systems"]

# df_map = read_file(y["Map"][1]);


# y = read_file(joinpath(READ_DIR, "gsp_state.yml"));
# df = read_file(y["Path"], y["CSVInput"]);
# df = edit_with(df, y["Rename"])
# df = edit_with(df, y["Melt"])
# df = edit_with(df, y["Map"])
# df = edit_with(df, y["Replace"])
# df = edit_with(df, y["Drop"])

# df = edit_with(df, y["Order"])


# filepath = joinpath(y["Path"]..., y["CSVInput"][2].name)

# # HEAD = findmax(sum.(collect(eachrow(Int.(length.(xf) .!= 0)))) .> 1)[2]
# xf = Array{Any,2}(df)

# ismissing.(values.(collect(eachrow(df))))

# DataFrame(mat[2:end,:], Symbol.(mat[1,:]), makeunique = true)



# mat = mat[.!(sum(length.(collect(eachrow(mat))[1]) .== 0) == size(mat)[2]-1),:]

# df = edit_with(y)

# df = read_file(y["Path"], y["CSVInput"][1]);

# df = edit_with(df, y["Rename"])
# df = edit_with(df, y["Melt"])
# df = edit_with(df, y["Drop"])
# df = edit_with(df, y["Map"])
# df = edit_with(df, y["Order"])


# v = df[1,:commodity]
# r = match(r"(?<aggr>.*)\&(?<sect>.*)", v)

# m = r"[0-9]+"

# x = y["Split"]
# NEWCOL = length(x.output)

# df = edit_with(df, Add.(x.output, fill("",size(x.output))))
# lst = split.(df[:, x.input], Regex(x.on));
# 
# [df[!, x.output[ii]] .= strip.([length(m) >= ii ? m[ii] : "" for m in lst])
#     for ii in 1:length(x.output)]

# x.remove ? df[!,x.input] .= [strip(string(string.(strip.(el)," ")...))
#     for el in lst] : nothing




# df = edit_with(y)

# df0 = read_file(y["Path"], y["CSVInput"])
# df = df0[1:10,:];
# # df = df0

# df = edit_with(df, y["Rename"]);
# # df = edit_with(df, y["Melt"]);
# df = edit_with(df, y["Add"]);
# df = edit_with(df, y["Map"]);
# df = edit_with(df, y["Replace"]);
# df = edit_with(df, y["Order"]);

# show(df)

# x = y["Map"][2]
# cols = unique(push!(names(df), x.output))
# df_map = read_file(x);

# # Rename the input column in the DataFrame to edit to match that in the mapping df.
# # This approach was taken as opposed to editing the mapping df to avoid errors in case
# # the input and output column names are the same. Such is the case if mapping is used to
# # edit column values for consistency without adding a new column to the DataFrame.
# # A left join is used to prevent data loss in the case that a value in the input df is
# # NOT in the input mapping column. If this is the case, this value will map to "missing".
# # Remove excess blank space from the input column to ensure consistency when joining.
# df = edit_with(df, Rename(x.input, x.from));

# all(typeof.(df_map[:,x.from]) .== String) ? df[!,x.from] .= convert_type.(String, df[:,x.from]) : nothing

# df[!, x.from] .= strip.(df[:, x.from]);
# df = join(df, df_map, on = x.from, kind = :left, makeunique = true);

# # show(first(df[:,[x.from,x.to]],3))

# df[ismissing.(df[:,x.to]), x.to] .=
#     convert_type.(String, df[ismissing.(df[:,x.to]), x.from])

# # Return the DataFrame with the columns saved at the top of the method.
# df = x.input == x.output ? edit_with(df, Rename(x.to, x.output)) :
#                             edit_with(df, Rename.([x.from, x.to], [x.input, x.output]))
# return df[:, cols]


# ############################################################################################

# # df = edit_with(df, y["Rename"]);
# # df = edit_with(df, y["Map"]);
# # df = edit_with(df, y["Split"]);

# # df = edit_with(df, y["Split"])
# # df = edit_with(df, y["Split"])

# # Base.lowercase(x::Symbol) = Symbol(lowercase(string(x)))
# # Base.uppercase(x::Symbol) = Symbol(uppercase(string(x)))

# # x = y["Rename"]

# # function z(df::DataFrame, x::Rename)

# #     # Explicitly rename the specified column if it exists in the dataframe.
# #     x.from in names(df) ? rename!(df, x.from => x.to) :

# #     # If we are, instead, changing the CASE of all column names...
# #         lowercase(x.to) == :lower ?
# #             df = edit_with(df, Rename.(names(df), lowercase.(names(df)))) :
# #             lowercase(x.to) == :upper ?
# #                 df = edit_with(df, Rename.(names(df), uppercase.(names(df)))) :
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