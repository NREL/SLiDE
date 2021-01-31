using SLiDE
using DataFrames
import Statistics

# Include works in progress.
# include(joinpath(SLIDE_DIR,"src","build","disagg","_disagg_sector_utils.jl"))
# include(joinpath(SLIDE_DIR,"src","build","disagg","disagg_sector.jl"))

# Read WiNDC output for comparison.
dataset = "state_model"
f_read = joinpath(SLIDE_DIR,"dev","readfiles")
det_in = merge(
    read_from(joinpath(f_read,"7_sectordisagg_int.yml"); run_bash=false),
    read_from(joinpath(f_read,"7_sectordisagg_int_share.yml")),
)
det_out = read_from(joinpath(f_read,"7_sectordisagg_out.yml"); run_bash=false)

# Read original build stream output from WiNDC results so we can be completely consistent
# when we do our calculations later.
d = read_from(joinpath(f_read,"5_disagg_out.yml"); run_bash=true)

share_disagg_sector!("", d)
dis_comp = benchmark_against(d, det_out)

# ------------------------------------------------------------------------------------------


# Save sharing the same way it's saved 
# det[:share] = select!(det[:sector], Not(:aggr))
# det_comp = benchmark_against(det, det_in)

# Extend years.
# [det[k] = extend_year(df, set[:yr]) for (k,df) in det]

# For now, we don't really needd to keep all these other values.
# Let's take them out for now so it won't be as annoying to validate things.
# [det_out[k] = filter_with(df, (yr=[2007,2012], r="md")) for (k,df) in det_out]
# [d[k] = filter_with(df, (yr=[2007,2012], r="md")) for (k,df) in d]



# function _disagg_sector_2(
#     df::DataFrame,
#     dfmap::DataFrame,
#     on::AbstractArray;
#     scheme=:summary=>:disagg,
# )
#     on = _find_sector(df)

#     if !isempty(on)
#         !ismissing(key) && println("  Disaggregating sectors for $key")
#         col = propertynames(df)
#         if length(on) > 1
#             dfmap = _compound_for(dfmap, on; scheme=scheme)
#             (from,to) = (SLiDE._add_id.(scheme[1],on), SLiDE._add_id.(scheme[2],on))
#         else
#             (from,to) = (scheme[1], scheme[2])
#         end

#         df = edit_with(df, Map(dfmap, [:yr;from], [to;:value], [:yr;on], [on;:share], :inner))
#         df[!,:value] = df[:,:value] .* df[:,:share]
#         df = select(df,col)
#     end

#     return df
# end




# lst = [edit_with(dfmap, Rename.([from,to], SLiDE._add_id.([from,to], k)))
#     for k in on]


# If the froms are the same
# ii_same_from = SLiDE._find_constant.(eachrow(df[:,from]))
# ii_same_to = SLiDE._find_constant.(eachrow(df[:,to]))

# ii = ii_same_from .* ii_same_to



# Compound sector sharing -- there's something weird when we have two of the same sector.
# lst = [edit_with(dfmap, Rename.([from,to], SLiDE._add_id.([from,to], k)))
#     for k in col]
# dfmap2 = lst[1] * lst[2]