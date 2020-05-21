function stack_by(df, col, val, input, output)
    cols = unique(vcat(names(df), output))

    df[!,:start] = (1:size(df)[1]) .+ 1
    df_split = df[df[:,col] .== val, :]
    df_split = edit_with(df_split, Rename.(input, output))

    sort!(unique!(df_split), :start)
    df_split[!, :stop] .= vcat(df_split[2:end, :start] .- 2, [size(df)[1]])

    [df[!, col] .= "" for col in output]
    [df[row[:start]:row[:stop], col] .= row[col] for row in eachrow(df_split) for col in output]

    df = df[df[:,output[1]] .!= "", :]
    return df[:, cols]
end



# function SLiDE.edit_with(df::DataFrame, x::Drop)
#     if x.val === "all" && x.operation == "occursin"
#         df = edit_with(df, Drop.(names(df)[occursin.(x.col, names(df))], "all", "=="))
#     end

#     !(x.col in names(df)) && (return df)
#     if x.val === "all"  # Drop entire column to remove dead weight right away.
#         df = df[:, setdiff(names(df), [x.col])]
#     else  # Drop rows using an operation or based on a value.
#         if x.val === missing
#             dropmissing!(df, x.col)
#         elseif x.val === "unique"
#             unique!(df, x.col)
#         else
#             df[!,x.col] .= convert_type.(typeof(x.val), df[:,x.col])
#             df = if x.operation == "occursin"
#                 df[.!broadcast(datatype(x.operation), x.val, df[:,x.col]), :]
#             else
#                 df[.!broadcast(datatype(x.operation), df[:,x.col], x.val), :]
#             end
#         end
#     end
#     return df
# end

# function SLiDE.edit_with(df::DataFrame, x::Stack)
#     df = [[edit_with(df[:, occursin.(indicator, names(df))],
#         [Rename.(names(df)[occursin.(indicator, names(df))], x.col);
#             Add(x.var, replace(string(indicator), "_" => " "))]
#     ) for indicator in x.on]...;]
#     return dropmissing(df)
# end

# * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
# SGF
# filename = files_map[occursin.(joinpath("parse","sgf"), files_map)]
# if length(filename) > 0
#     println(string("Standardizing ", filename[1]))
#     y = read_file(filename[1])
#     df = read_file(y["PathIn"], y["CSVInput"])
#     df = edit_with(df, y["Drop"])
#     df = edit_with(df, y["Stack"])
#     df = edit_with(df, y["Map"][1])
#     df = edit_with(df, y["Map"][2])

#     # df = [[edit_with(df_map[:, occursin.(yy, names(df_map))],
#     #         Rename.(names(df_map)[occursin.(yy, names(df_map))], cols))
#     #     for yy in string.(1997:2016)]...;]

#     # df = edit_with(df, [[y[k] for k in ["Drop", "Map", "Order"]]...;])
#     # CSV.write(joinpath(SLIDE_DIR, y["PathOut"]...), df)
# end

# # # * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
# # # SCALE NAICS
# # filename = files_map[occursin.(joinpath("scale", "naics"), files_map)]

# # if length(filename) > 0
# #     println(string("Standardizing ", filename[1]))
# #     y = read_file(filename[1])
# #     df = read_file(y["PathIn"], y["CSVInput"])
    
# #     col = :naics_level
# #     input = [:naics_code, :naics_desc]
# #     vals = ["sector", "subsector", "industry group", "naics industry", "national industry"]
# #     outputs = [Symbol.(replace(val, " " => "_"), ["_code", "_desc"]) for val in vals]

# #     [global df = stack_by(df, col, val, input, output)
# #         for (val, output) in collect(zip(vals, outputs))[1:end-1]]
# #     df = edit_with(df, Rename.(input, outputs[end]))

# #     global df = edit_with(df, y["Order"])
# #     CSV.write(joinpath(SLIDE_DIR, y["PathOut"]...), df)
# # end

