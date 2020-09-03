function stack_by(df, col, val, input, output)
    cols = unique(vcat(propertynames(df), output))

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
# SCALE NAICS
filename = files_map[occursin.(joinpath("scale", "naics"), files_map)]

if length(filename) > 0
    println(string("Standardizing ", filename[1]))
    y = read_file(filename[1])
    df = read_file(y["PathIn"], y["CSVInput"])
    
    col = :naics_level
    input = [:naics_code, :naics_desc]
    vals = ["sector", "subsector", "industry group", "naics industry", "national industry"]
    outputs = [Symbol.(replace(val, " " => "_"), ["_code", "_desc"]) for val in vals]

    [global df = stack_by(df, col, val, input, output)
        for (val, output) in collect(zip(vals, outputs))[1:end-1]]
    df = edit_with(df, Rename.(input, outputs[end]))

    global df = edit_with(df, y["Order"])
    CSV.write(joinpath(SLIDE_DIR, y["PathOut"]...), df)
end