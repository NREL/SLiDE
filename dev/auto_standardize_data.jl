using CSV
using Dates
using DataFrames
using DelimitedFiles
using XLSX
using YAML

using SLiDE  # see src/SLiDE.jl

# function SLiDE.edit_with(df::DataFrame, x::Operate)
#     # Perform operation on columns. Isolate columns to be operated on.
#     # Append original columns that might be replaced "_0" to preserve information.
#     df_val = convert_type.(Float64, copy(df[:,x.input]))
#     x.output in x.input ? df = edit_with(df, Rename(x.output, Symbol(x.output, :_0))) :
#         nothing
#     df[!,x.output] .= broadcast(datatype(x.operation), [col for col in eachcol(df_val)]...)

#     # !!!! SOS how do we deal with floating point arithmetic? (ex: 1.1 + 0.1 = 1.2000000000000002)
#     df[!,x.output] .= round.(df[:,x.output], digits=8)

#     # Adjust labeling columns.
#     for (from, to) in zip(x.from, x.to)
#         if from in names(df) && to in names(df) && from !== to
#             df_comment = dropmissing(unique(df[:, [from; to]]))
#             df[!, Symbol(from, :_0)] .= df[:,from]
#             df = edit_with(df, Replace.(from, df_comment[:,from], df_comment[:,to]))
#         end
#     end
    
#     # Reorder DataFrame columns to show all columns involved in the operation last.
#     # This could aid in troubleshooting.
#     cols = intersect([setdiff(x.input, [x.output]); Symbol(x.output, :_0); x.output;
#         reverse(sort([Symbol.(x.from, :_0); x.from])); reverse(sort(x.to))], names(df));
#     return df[:,[setdiff(names(df), cols); cols]]
# end



READ_DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "data", "readfiles"))

files_parse = XLSXInput("generate_yaml.xlsx", "parse", "I1:I180", "parse")
files_parse = write_yaml(READ_DIR, files_parse)
y = read_file(joinpath(READ_DIR, files_parse[1]))

files_parse = run_yaml(files_parse)
df = read_file(joinpath(y["PathOut"]...))


# df = read_file("../data/output/nass.csv")
# df = unique(edit_with(df, Drop(:value, 0.0, "==")), :units_0)

# for ii in 1:length(y["CSVInput"])
#     df = read_file(y["Path"], y["CSVInput"][ii])

#     df = edit_with(df, y["Drop"])
#     df = edit_with(df, y["Rename"])
#     # # df = edit_with(df, y["Group"])
#     # df = edit_with(df, y["Match"])
#     df = edit_with(df, y["Melt"])
#     # # # # df = edit_with(df, y["Add"])
#     df = edit_with(df, y["Map"])

#     println(ii, " ", unique(df[:,:component]))
# end


# df = read_file(y["Path"], y["XLSXInput"])
# df = read_file(y["Path"], y["CSVInput"][3])

# # # # # # # # # # df = edit_with(y)

# # x = Map("parse/units.csv",
# #     [:from], [:to, :factor, :units_factor], [:units], [:units,:factor,:units_factor])

# setrounding(Float64,RoundDown) do
#     x / y
# end


# df = edit_with(df, y["Drop"])
# df = edit_with(df, y["Rename"])
# # # # df = edit_with(df, y["Group"])
# df = edit_with(df, y["Match"])
# df = edit_with(df, y["Melt"])
# # # # # # df = edit_with(df, y["Add"])
# df = edit_with(df, y["Map"])
# df = edit_with(df, y["Replace"])
# df = edit_with(df, y["Drop"])
# # df = edit_with(df, y["Operate"])
# # # df = edit_with(df, y["Order"])


# any(occursin.())



# x = y["Map"]
# # kind = :left
# # cols = unique([names(df); x.output])
# # df_map = read_file(x)
# # df_map = unique(df_map[:,unique([x.from; x.to])])

# # temp_to = Symbol.(string.("to_", 1:length(x.to)))
# # temp_from = Symbol.(string.("from_", 1:length(x.from)))
# # df_map = edit_with(df_map, Rename.([x.to; x.from], [temp_to; temp_from]))

# # [df[!,col] .= convert_type.(unique(typeof.(df_map[:,col_map])), df[:,col])
# #     for (col_map, col) in zip(temp_from, x.input)]

# # df = join(df, df_map, on = Pair.(x.input, temp_from);
# #     kind = kind, makeunique = true)

# # df = df[:, setdiff(names(df), x.output)]

# # x = y["Replace"][end];
# # # df[!, x.col] .= convert_type.(String, df[:, x.col])
# # # x.from == "missing" ?
# # #     all(typeof.(df[:,x.col]) .== Missing) ? df[ismissing.(df[:,x.col]), x.col] .= x.to :
# # #         df = edit_with(df, Add(x.col, x.to))
# # #     df[!, x.col][strip.(string.(df[:,x.col])) .== x.from] .= x.to

# # df = edit_with(df, y["Replace"])

# # # # df = read_file("../data/output/seds.csv")

# # # df = unique(edit_with(df, Drop(:value, 0.0, "==")), :units)

# # # x_seds = Operate("*", [:units], [:units_factor], [:value, :factor], :value)
# # # df_seds = edit_with(df, x_seds)