using CSV
using DataFrames
using DelimitedFiles
using YAML
using SLiDE

DATA_DIR = joinpath("data", "output")
MAP_DIR = joinpath("data", "coremaps")

# Read DataFrames.
df_cbsa_map = read_file(joinpath(MAP_DIR, "scale", "census_cbsa.csv"));
df_cbsa_map[!,:state_code] .= df_cbsa_map[:,:state_desc]
df_cbsa_map = unique(df_cbsa_map[:,[:state_code,:cbsa_code,:csa_code,:cbsa_desc,:csa_desc]])

df_cfs_io = read_file(joinpath(DATA_DIR, "cfs.csv"));
df_gsp_io = dropmissing(read_file(joinpath(DATA_DIR, "gsp_metro.csv")));

# Isolate regional information.
df_cfs = copy(df_cfs_io)
df_gsp = copy(df_gsp_io)

df_cfs = sort(unique(DataFrame(
    state = [df_cfs[:,:orig_state]; df_cfs[:,:dest_state]],
    metro = [df_cfs[:,:orig_metro]; df_cfs[:,:dest_metro]])))
df_gsp = sort(unique(DataFrame(
    GSP_cbsa_code = df_gsp[:,:r],
    GSP_cbsa_desc = df_gsp[:,:r_desc])));

# # ******************************************************************************************
# QUESTION: Are any regions doubly represented?
df = sort(edit_with(copy(df_cfs), Drop(:metro, 99999, "==")));

# ******************************************************************************************
# QUESTIONS: Are there states with both CBSAs and CSAs represented?
df = copy(df_cfs)

x = [Map("scale/census_cbsa.csv", [:state_desc, :cbsa_code], [:cbsa_code, :cbsa_desc], [:state, :metro], [:cbsa_code,:cbsa_desc]),
     Map("scale/census_cbsa.csv", [:state_desc, :csa_code],  [:csa_code, :csa_desc],   [:state, :metro], [:csa_code,:csa_desc])]
df = edit_with(df, x)

df[!,:cbsa] .= .!ismissing.(df[:,:cbsa_desc]);
df[!,:csa]  .= .!ismissing.(df[:,:csa_desc]);

df_summary = join(by(df, :state, :csa => sum), by(df, :state, :cbsa => sum), on = :state);
df_summary[!,:both] .= sum.(eachrow(df_summary[:,[:cbsa_sum,:csa_sum]] .> 0))

if any(df_summary[:,:both] .> 1)
    println("Some states have both CSA and CBSA areas represented.")
end

# ******************************************************************************************
# QUESTION: What overlap 
df = sort(edit_with(copy(df_cfs), Drop(:metro, 99999, "==")));

x = [Map("scale/census_cbsa.csv", [:state_desc, :cbsa_code], [:cbsa_code, :cbsa_desc, :csa_code, :csa_desc], [:state, :metro], [:cbsa_code, :cbsa_desc, :MAPPED_csa_code, :MAPPED_csa_desc]),
     Map("scale/census_cbsa.csv", [:state_desc, :csa_code],  [:csa_code, :csa_desc, :cbsa_code, :cbsa_desc], [:state, :metro], [:csa_code, :csa_desc, :MAPPED_cbsa_code, :MAPPED_cbsa_desc])]
df = edit_with(df, x)

# Reorder.
cols = [[:state, :metro]; names(df)[occursin.(:code, names(df))]; names(df)[occursin.(:desc, names(df))]]
df = df[:,cols]

# Overlap in CSA/CBSA codes?
intersect(df[:,:cbsa_code], df[:,:MAPPED_cbsa_code])
intersect(df[:,:csa_code], df[:,:MAPPED_csa_code])

# ******************************************************************************************
# CFS vs. GSP?
df[!,:cbsa_code_0] .= df[:,:cbsa_code]
df[!,:MAPPED_cbsa_code_0] .= df[:,:MAPPED_cbsa_code]

# df_gsp = join(df_gsp, unique(df[:,[:cbsa_code_0,:cbsa_code]]), on = Pair(:GSP_cbsa_code, :cbsa_code_0), kind = :left)
# df_gsp = join(df_gsp, unique(df[:,[:MAPPED_cbsa_code_0,:MAPPED_cbsa_code]]), on = Pair(:GSP_cbsa_code, :MAPPED_cbsa_code_0), kind = :left)

# QUESTIONS: Are there states with both CBSAs and CSAs represented?
# df = copy(df_cfs)


# # df_metro = read_file("../data/output/cfs_metro.csv");

# # df = sort(unique(DataFrame(ma = [df_metro[:,:orig_ma]; df_metro[:,:dest_ma]])));
# # joincols0 = [:cbsa_code, :csa_code];

# # df_temp = dropmissing(unique(df_cbsa_map[:,joincols0]));

# # for key in allkeys
# #     df_temp = unique(df_cbsa_map[:,joincols0]);
# #     df_temp[!,:ma] .= df_temp[:,Symbol(key,:_code)]

# #     joincols = Symbol.(uppercase(key),:_,joincols0);

# #     df_temp = edit_with(df_temp, Rename.(joincols0, joincols));


# #     global df = join(df, df_temp, on = :ma, kind = :left)
# # end

# # # join(df, df_cbsa_map, on = Pair(:ma))







# # # df_metro_area = sort(unique(df_metro[:,[:orig_ma,:dest_ma]]));
# # # df_metro_area = edit_with(df_metro_area, Drop.([:orig_ma,:dest_ma], 0, "=="));
# # # first(df_metro_area,3)

# # # allflow = [:orig, :dest]
# # # allkeys = [:cbsa, :csa]
# # # for flow in allflow
# # #     for key in allkeys
# # #         joincols = [Symbol.(key, :_, [:code, :desc])];
# # #         df_temp = dropmissing(unique(df_cbsa_map[:,joincols]));

# # #         joincols = Symbol.(flow, :_, joincols)
# # #         df_temp = edit_with(df_temp, Rename.(names(df_temp), joincols));

# # #         global df_metro_area = join(df_metro_area, df_temp,
# # #             on = Pair.(Symbol(flow, :_ma), joincols[1]), kind = :left);
# # #     end
# # # end


# # # df_metro_area[!,:found_csa] .= sum.(eachrow(ismissing.(df_metro_area[:,occursin.(:csa, names(df_metro_area))])))
# # # df_metro_area[!,:found_cbsa] .= sum.(eachrow(ismissing.(df_metro_area[:,occursin.(:cbsa, names(df_metro_area))])))




# x = x[2]
# function SLiDE.edit_with(df::DataFrame, x::Map; kind = :left)
#     # Save all input column names, read the map file, and isolate relevant columns.
#     # # This prevents duplicate columns in the final DataFrame.
#     cols = unique([names(df); x.output])
#     df_map = copy(read_file(x))
#     df_map = unique(df_map[:,unique([x.from; x.to])])
    
#     # If there are duplicate columns in from/to, differentiate between the two to save results.
#     duplicates = intersect(x.from, x.to)
#     if length(duplicates) > 0
#         (ii_from, ii_to) = (occursin.(duplicates, x.from), occursin.(duplicates, x.to));
#         x.from[ii_from] = Symbol.(x.from[ii_from], :_0)
#         [df_map[!,Symbol(col, :_0)] .= df_map[:,col] for col in duplicates]
#     end
    
#     # Rename columns in the mapping DataFrame to temporary values in case any of these
#     # columns were already present in the input DataFrame.
#     temp_to = Symbol.(string.("to_", 1:length(x.to)))
#     temp_from = Symbol.(string.("from_", 1:length(x.from)))
#     df_map = edit_with(df_map, Rename.([x.to; x.from], [temp_to; temp_from]))

#     # Ensure the input and mapping DataFrames are consistent in type. Types from the mapping
#     # DataFrame are used since (!!!! assuming all missing values were dropped), all values
#     # in the mapping DataFrame should be the same.
#     [df[!,col] .= convert_type.(unique(typeof.(skipmissing(df_map[:,col_map]))), df[:,col])
#         for (col_map, col) in zip(temp_from, x.input)]

#     df = join(df, df_map, on = Pair.(x.input, temp_from); kind = kind, makeunique = true)
  
#     # Remove all output column names that might already be in the DataFrame. These will be
#     # overwritten by the columns from the mapping DataFrame. Finally, remane mapping "to"
#     # columns from their temporary to output values.
#     df = df[:, setdiff(names(df), x.output)]
#     df = edit_with(df, Rename.(temp_to, x.output))
#     return df[:,cols]
# end


