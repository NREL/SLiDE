using CSV
using DataFrames
using DelimitedFiles
using YAML
using SLiDE

# path_slide = joinpath("..","data","output")
# path_stream_out = joinpath("..","data","windc_output","1_stream_output")
# path_bluenote = joinpath("..","data","windc_output","2_stream")

df_cbsa = read_file("../data/coremaps/scale/census_cbsa.csv");
df_cbsa = edit_with(df_cbsa, Map("parse/regions.csv", [:from],[:to],[:state_desc],[:state_desc]));

df_cfs = read_file("../data/output/cfs.csv");
df_cfs = edit_with(df_cfs, [Map("parse/regions.csv", [:from],[:to],[:orig_state],[:orig_state]);
                            Map("parse/regions.csv", [:from],[:to],[:dest_state],[:dest_state])]);

df_trade = sort(unique(copy(df_cfs[:,[:orig_state,:orig_ma,:dest_state,:dest_ma]])));

cols = [:state,:ma];

df_regions = sort(unique([
    edit_with(df_trade[:,[:orig_state, :orig_ma]], Rename.([:orig_state, :orig_ma], cols));
    edit_with(df_trade[:,[:dest_state, :dest_ma]], Rename.([:dest_state, :dest_ma], cols))]));


# ******************************************************************************************
# QUESTION: Are any regions doubly represented?


# ******************************************************************************************
# QUESTIONS: Are there states with both CBSAs and CSAs represented?
df = copy(df_regions)
allkeys = [:cbsa,:csa];

for key in allkeys

    joincols = [:state_desc; Symbol.(key, :_, [:code, :desc])];
    df_temp = dropmissing(unique(df_cbsa[:,joincols]));
    df_temp = edit_with(df_temp, Rename.(names(df_temp), joincols));

    global df = join(df, df_temp,
        on = Pair.([:state,:ma], joincols[1:2]), kind = :left);
end

df[!,:cbsa] .= .!ismissing.(df[:,:cbsa_desc]);
df[!,:csa] .= .!ismissing.(df[:,:csa_desc]);

df_summary = join(by(df, :state, :csa => sum), by(df, :state, :cbsa => sum), on = :state);
df_summary[!,:num_type] .= sum.(eachrow(df_summary[:,[:cbsa_sum,:csa_sum]] .> 0))







# df[!,:both] .= sum.(eachrow(df[:,[:has_cbsa_sum,:has_csa_sum]])) .> 0


# df_metro = read_file("../data/output/cfs_metro.csv");

# df = sort(unique(DataFrame(ma = [df_metro[:,:orig_ma]; df_metro[:,:dest_ma]])));
# joincols0 = [:cbsa_code, :csa_code];

# df_temp = dropmissing(unique(df_cbsa[:,joincols0]));

# for key in allkeys
#     df_temp = unique(df_cbsa[:,joincols0]);
#     df_temp[!,:ma] .= df_temp[:,Symbol(key,:_code)]

#     joincols = Symbol.(uppercase(key),:_,joincols0);

#     df_temp = edit_with(df_temp, Rename.(joincols0, joincols));


#     global df = join(df, df_temp, on = :ma, kind = :left)
# end

# # join(df, df_cbsa, on = Pair(:ma))







# # df_metro_area = sort(unique(df_metro[:,[:orig_ma,:dest_ma]]));
# # df_metro_area = edit_with(df_metro_area, Drop.([:orig_ma,:dest_ma], 0, "=="));
# # first(df_metro_area,3)

# # allflow = [:orig, :dest]
# # allkeys = [:cbsa, :csa]
# # for flow in allflow
# #     for key in allkeys
# #         joincols = [Symbol.(key, :_, [:code, :desc])];
# #         df_temp = dropmissing(unique(df_cbsa[:,joincols]));

# #         joincols = Symbol.(flow, :_, joincols)
# #         df_temp = edit_with(df_temp, Rename.(names(df_temp), joincols));

# #         global df_metro_area = join(df_metro_area, df_temp,
# #             on = Pair.(Symbol(flow, :_ma), joincols[1]), kind = :left);
# #     end
# # end


# # df_metro_area[!,:found_csa] .= sum.(eachrow(ismissing.(df_metro_area[:,occursin.(:csa, names(df_metro_area))])))
# # df_metro_area[!,:found_cbsa] .= sum.(eachrow(ismissing.(df_metro_area[:,occursin.(:cbsa, names(df_metro_area))])))

# # first(df_metro_area,4)