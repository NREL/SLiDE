using Complementarity
using CSV
using Dates
using DataFrames
using DelimitedFiles
using JuMP
using Revise
using XLSX
using YAML

using SLiDE  # see src/SLiDE.jl

READ_DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "data", "readfiles", "1_map", "scale"))

CITIES = ["Baltimore", "Denver", "Madison", "Fargo"]

###########################################################################################
function stack_by_length(df, IND, on, input, output)

    cols = unique(vcat(names(df), output))
    df[!,on] .= convert_type.(String, df[:,on])

    df[!,:start] = (1:size(df)[1]) .+ 1
    df_split = df[length.(df[:,on]) .== IND, :]
    df_split = edit_with(df_split, Rename.(input, output))

    sort!(unique!(df_split), :start)
    df_split[!, :stop] .= vcat(df_split[2:end, :start] .- 2, [size(df)[1]])

    [df[!, col] .= "" for col in output]
    [df[row[:start]:row[:stop], col] .= row[col] for row in eachrow(df_split) for col in output]

    df = df[df[:,output[1]] .!= "", :]
    return df[:, cols]
end

############################################################################################
function stack_by(df, IND, on, input, output)

    cols = unique(vcat(names(df), output))

    df[!,:start] = (1:size(df)[1]) .+ 1
    df_split = df[df[:,on] .== IND, :]
    df_split = edit_with(df_split, Rename.(input, output))

    sort!(unique!(df_split), :start)
    df_split[!, :stop] .= vcat(df_split[2:end, :start] .- 2, [size(df)[1]])

    [df[!, col] .= "" for col in output]
    [df[row[:start]:row[:stop], col] .= row[col] for row in eachrow(df_split) for col in output]

    df = df[df[:,output[1]] .!= "", :]
    return df[:, cols]
end

############################################################################################
function dataframe_stats(df::DataFrame)
    ROW, COL = size(df)
    df_stats = DataFrame(
        col = fill(:sym, COL),
        unique = fill(0, COL),
        miss = fill(0,COL)
    )
    for ii in 1:COL
        col = names(df)[ii]
        df_stats[ii,:col] = col
        df_stats[ii,:unique] = size(unique(df,col),1);
        df_stats[ii,:miss] = ROW-size(dropmissing(df,col),1);
    end
    return df_stats
end

############################################################################################
# y1 = read_file(joinpath(READ_DIR, "scale_census_cbsa.yml"))
# df1 = unique(edit_with(y1));
# CSV.write(joinpath(y1["PathOut"]...), df1)

# y2 = read_file(joinpath(READ_DIR, "scale_census_cbsa_cities.yml"));
# df2 = unique(edit_with(y2));
# CSV.write(joinpath(y2["PathOut"]...), df2)

# y4 = read_file(joinpath(READ_DIR, "scale_census_necta_cities.yml"));
# df4 = unique(edit_with(y4))
# CSV.write(joinpath(y4["PathOut"]...), df4)

# y3 = read_file(joinpath(READ_DIR, "scale_census_necta.yml"));
# df3 = unique(edit_with(y3));
# CSV.write(joinpath(y3["PathOut"]...), df3)

############################################################################################
# READ NAICS
yn = read_file(joinpath(READ_DIR, "scale_naics.yml"));
dfn = unique(edit_with(yn));

dfn[!,:level] .= length.(dfn[:,:level])

# EDIT NAICS INTO MAPPING DATAFRAME
on = :level
input = [:naics_code, :naics_desc]
outputs = [:sector, :subsector, :industry_group, :naics_industry, :national_industry]
outputs = [Symbol.(string.(output, ["_code", "_desc"])) for output in outputs]
INDS = 2:6

# # GROUP DF BASED ON COLUMN LENGTH.
[global dfn = stack_by(dfn, IND, on, input, output)
    for (IND, output) in collect(zip(INDS, outputs))[1:end-1]]
dfn = edit_with(dfn, Rename.(input, outputs[end]))

# REORDER.
cols = reverse(collect(Iterators.flatten(outputs)))
cols = vcat(cols[occursin.(:code, cols)], cols[occursin.(:desc, cols)])
dfn = dfn[:,cols]

CSV.write(joinpath(yn["PathOut"]...), dfn)