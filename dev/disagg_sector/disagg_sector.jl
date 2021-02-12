using SLiDE
using DataFrames
import Statistics

# Read WiNDC output for comparison.
dataset = "state_model"
f_read = joinpath(SLIDE_DIR,"dev","readfiles")

# dis_in = merge(
#     read_from(joinpath(f_read,"7_sectordisagg_int.yml"); run_bash=false),
#     read_from(joinpath(f_read,"7_sectordisagg_int_share.yml")),
# )
# dis_out = read_from(joinpath(f_read,"7_sectordisagg_out.yml"); run_bash=false)
# agg_out = read_from(joinpath(f_read,"8_aggr_out.yml"); run_bash=true)

# ------------------------------------------------------------------------------------------
# Read original build stream output from WiNDC results so we can be completely consistent
# when we do our calculations. This is just for development so we know it's all 
d = read_from(joinpath(f_read,"5_disagg_out.yml"); run_bash=true)
dataset = "state_model"

path = joinpath(SLIDE_DIR,"data","coremaps","scale","sector","eem_pmt.csv")

dfmap = read_file(path)

set = read_from(joinpath("src","build","readfiles","setlist.yml"))
set[:sector] = unique(dfmap[:,:disagg])

(d,set) = share_sector!(dataset, d, set)
(dis,set) = disagg_sector!(dataset, copy(d), set)
(agg,set) = aggregate_sector!(dataset, copy(dis), set; path=path)

# dis_comp = benchmark_against(dis, dis_out)
# agg_comp = benchmark_against(agg, agg_out)