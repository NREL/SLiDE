using CSV
using DataFrames

# ------------------------------------------------------------------------------
# WORKING
# d = y["mapping"][2]

# mapfile = d["file"]
# from = d["from"]
# to = d["to"]
# input = df[:, d["input"]]

# df_map = CSV.read("core_maps/$mapfile.csv", silencewarnings = true)
# dict_map = Dict(k => v for (k, v) in zip(df_map[!, from], df_map[!, to]));

# output = map(x -> dict_map[x], input);
# df[!, d["output"]] .= output
# ------------------------------------------------------------------------------

# dataframe_mapping(df, y)

df_maps = Dict(k => CSV.read("core_maps/$k.csv", silencewarnings = true)
    for k in unique([v for d in y["mapping"] for v in [d["file"]]]))

for d in y["mapping"]
    global df[!, d["input"]]  .= string.(strip.(df[!, d["input"]]))
    global df[!, d["output"]] .= map_with_dataframe(df[!, d["input"]], df_maps[d["file"]];
        from = d["from"], to = d["to"])

    # This code works if the dictionary of map dataframes was NOT
    # defined, using the method of map_with_dataframe() that takes a
    # dataframe as an argument in place of the core_map file name.
    # df[!, d["output"]] .= map_with_dataframe(df[!, d["input"]], d["file"];
    #     from = d["from"], to = d["to"])
end