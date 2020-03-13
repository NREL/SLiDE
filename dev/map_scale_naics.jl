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

###########################################################################################
function stack_by_length(df, LEN, on, input, output)

    cols = unique(vcat(names(df), output))
    df[!,on] .= convert_type.(String, df[:,on])

    df[!,:start] = (1:size(df)[1]) .+ 1
    df_split = df[length.(df[:,on]) .== LEN, :]
    df_split = edit_with(df_split, Rename.(input, output))

    sort!(unique!(df_split), :start)
    df_split[!, :stop] .= vcat(df_split[2:end, :start] .- 2, [size(df)[1]])

    [df[!, col] .= "" for col in output]
    [df[row[:start]:row[:stop], col] .= row[col] for row in eachrow(df_split) for col in output]

    df = df[df[:,output[1]] .!= "", :]
    return df[:, cols]
end

###########################################################################################
# READ NAICS
yn = read_file(joinpath(READ_DIR, "scale_naics.yml"));
dfn = unique(edit_with(yn));

# EDIT NAICS INTO MAPPING DATAFRAME
on = :naics_code
input = [:naics_code, :naics_desc]
outputs = [:sector, :subsector, :industry_group, :naics_industry, :national_industry]
outputs = [Symbol.(string.(output, ["_code", "_desc"])) for output in outputs]
LENS = 2:6

# GROUP DF BASED ON COLUMN LENGTH.
[global dfn = stack_by_length(dfn, LEN, on, input, output)
    for (LEN, output) in collect(zip(LENS, outputs))[1:end-1]]
dfn = edit_with(dfn, Rename.(input, outputs[end]))

cols = reverse(collect(Iterators.flatten(outputs)))
cols = vcat(cols[occursin.(:code, cols)], cols[occursin.(:desc, cols)])
dfn = dfn[:,cols]