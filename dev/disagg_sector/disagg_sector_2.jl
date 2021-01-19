using SLiDE
using DataFrames
import Statistics

version = "1.0.1"
include(joinpath(SLIDE_DIR,"src","build","disagg","_disagg_sector_utils.jl"))

f_read = joinpath(SLIDE_DIR,"dev","readfiles")
dataset = "state_model_det"

# (d,set) = build_data("state_model_1.0.1")
# d = read_from(joinpath(f_read,"5_disagg_out.yml"); run_bash=true)

set = read_from(joinpath("src","build","readfiles","setlist_$version.yml"))  # !!!! version
[set[k] = set[:detail] for k in [:g,:s]]

det = merge(read_from(joinpath("src","build","readfiles","partition","detail_$version.yml")),  # !!!! version
    Dict(:sector=>:detail))
det = partition(dataset, det, set)

# set[:yr_det] = unique(det[:y0][:,:yr])

f_eem = joinpath("scale","sector","eem_sectors.csv")
_share_aggregate!(det, set, f_eem)
_map_year!(det, set)


