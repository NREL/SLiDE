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

# * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
# PARSE NAICS
filename = files_map[occursin.(joinpath("parse","naics"), files_map)]
if length(filename) > 0
    println(string("Standardizing ", filename[1]))
    y = read_file(filename[1])
    df = read_file(y["Path"], y["XLSXInput"])
    df = edit_with(df, vcat([vcat(y[k]) for k in ["Rename", "Match"]]...))
    df[!,:naics_level] .= string.(length.(df[:,:naics_level]))
    df = edit_with(df, vcat([vcat(y[k]) for k in ["Replace", "Order"]]...))
    CSV.write(joinpath(SLIDE_DIR, y["PathOut"]...), unique(df))
end

# * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
# SGF
filename = files_map[occursin.(joinpath("parse","sgf"), files_map)]
if length(filename) > 0
    println(string("Standardizing ", filename[1]))
    y = read_file(filename[1])
    df_map = read_file(y["Path"], y["CSVInput"])
    df_map = edit_with(df_map, y["Drop"])

    # Make horizontally-concatennated DataFrames one, normalized database.
    # None of the Edit DataTypes are quite equiped to handle this.
    # df_map = df_map[:, names(df_map)[.!occursin.("line_num", names(df_map))]]
    cols = [:from, :sgf_desc, :units]
    df = vcat([edit_with(df_map[:, occursin.(yy, names(df_map))],
            Rename.(names(df_map)[occursin.(yy, names(df_map))], cols))
        for yy in string.(1997:2016)]...)

    df = edit_with(df, vcat([vcat(y[k]) for k in ["Drop", "Map", "Order"]]...))
    CSV.write(joinpath(SLIDE_DIR, y["PathOut"]...), df)
end

# * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
# SCALE NAICS
filename = files_map[occursin.(joinpath("scale", "naics"), files_map)]

if length(filename) > 0
    println(string("Standardizing ", filename[1]))
    y = read_file(filename[1])
    df = read_file(y["Path"], y["CSVInput"])
    
    col = :naics_level
    input = [:naics_code, :naics_desc]
    vals = ["sector", "subsector", "industry_group", "naics_industry", "national_industry"]
    outputs = [Symbol.(val, ["_code", "_desc"]) for val in vals]

    [global df = stack_by(df, col, val, input, output)
        for (val, output) in collect(zip(vals, outputs))[1:end-1]]
    df = edit_with(df, Rename.(input, outputs[end]))

    df = edit_with(df, y["Order"])
    CSV.write(joinpath(SLIDE_DIR, y["PathOut"]...), df)
end