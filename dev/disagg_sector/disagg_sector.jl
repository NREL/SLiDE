using SLiDE
using DataFrames
import Statistics

include(joinpath(SLIDE_DIR,"src","build","disagg","_disagg_sector_utils.jl"))

(d,set) = build_data("state_model_1.0.1")

# Read to check.
f_read = joinpath("dev","readfiles")
det_bn = merge(
    read_from(joinpath(f_read,"7_sectordisagg_int.yml"); run_bash=true),
    read_from(joinpath(f_read,"7_sectordisagg_int_share.yml")),
)

f_set = joinpath(SLIDE_DIR,"src","build","readfiles","setlist_1.0.1.yml");
set = read_from(f_set);
set[:s_sum] = copy(set[:s])
set[:g_sum] = copy(set[:g])

set_det = copy(set)
set_det[:g] = set[:g_det]
set_det[:s] = set[:s_det]

f_in = joinpath("data","input_1.0.1")
det = Dict()
det[:use_det] = read_file(joinpath(f_in,"use_det.csv"))
det[:supply_det] = read_file(joinpath(f_in,"supply_det.csv"))
det[:sector] = :detail

det = partition("state_model_det", det, set_det; save_build=true)
set[:yr_det] = unique(det[:y0][:,:yr])

f_eem = joinpath("scale","sector","eem_sectors.csv")

_share_aggregate!(det, set, joinpath("scale","sector","eem_sectors.csv"))
_map_year!(set, d)

det[:share_] = _map_year_with(det[:share], maps)


# x = :summary=>set[:yr]
# y = :detail=>[set[:yr_det];2017]

# _map_year(:summary=>set[:yr], :detail=>set[:yr_det])



# det[:share_summary] = _map_year(det[:share_summary], maps)
# det[:share_detail] = _map_year(det[:share_detail], maps)
# det[:share_] = det[:share_detail]

# d[:share_] = det[:share_summary]

# df = _share_bluenote!(d)



# Symbol(string(k)[1:end-1],:_,:0)
# shr = _compound_sectoral_sharing(d[:share_])
# d_new = Dict(k => _aggregate_with(d[k], shr) for k in keys(d) if k !== :share_)





# dropmissing(df * edit_with(dfmap,Rename.([:disagg,:aggr],[col,append(col,:aggr)])))


# !!!! update Map to work for file OR dataframe
# df = copy(d[:share_detail])




    # df_sum = fill_with((yr=[2007,2012],summary=set[:s]), 1.)

    # # !!!! check that user-defined scheme has correct naming.
    # # will also need to make sure path is relative to data/coremaps directory.

    # df_det = edit_with(df_det, [Rename(:detail,:disagg),x])

    # df_sum = df_sum - combine_over(df_det, [:disagg,:aggr])
    # df_sum = edit_with(df_sum, [Rename(:summary,:disagg),x])

    # d[:share_] = vcat(df_sum[:,col], df_det[:,col])
    # return sort!(d[:share_])
# end


# _mix_sector_levels!(d, joinpath("scale","sector","eem_sectors.csv"))

# set[:yr_det] = unique(d[:y0][:,:yr])

# set[:yr] = unique([set[:yr]; 2017:2020])
# set[:yr_det] = unique([set[:yr_det]; 2017])

# Extrapolate years divided at the mean.





# Dict(cut[ii,:det] => ensurearray(cut[ii,:min]:cut[ii,:max]) for ii in 1:size(cut,1))



# cols = Symbol.(yr_det[1:end-1])
# [df[!,col] .= df[:,:sum] .< df[:,col] for col in cols]

# cut = DataFrame(det=yr_det[1:end-1], max=yr_max)
# ii = 1
# jj = 1

# # for ii in 1:size(yr,2)
# df[ii,:sum] .< cut[jj,:max]

# while jj
#     df[]
#     jj+=1
#     jj>size(yr,2) && break
# end




# # Sets and things?

# dfmap = read_file(joinpath("data","coremaps","scale","sector","bluenote.csv"))

# col = :disagg_code

# df_det = filter_with(df, (disagg_code=set[:s_det],))

# set[:ms_all] = df[:,col]
# set[:ms_det] = df_det[:,col]




# set[:s] = set[:s_det]
# set[:as] = set[:s]

# SLiDE._partition_io!(d, set_det)
# SLiDE._partition_fd!(d, set_det)
# SLiDE._partition_va0!(f, set_det)
# SLiDE._partition_x0!(f, set_det)
# SLiDE._partition_m0!(f, set_det)
# SLiDE._partition_fs0!(f, set_det)
# SLiDE._partition_y0!(d, set_det)
# SLiDE._partition_a0!(f, set_det)