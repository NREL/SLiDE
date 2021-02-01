using SLiDE
using DataFrames
import Statistics

# Read WiNDC output for comparison.
dataset = "state_model"
f_read = joinpath(SLIDE_DIR,"dev","readfiles")

dis_in = merge(
    read_from(joinpath(f_read,"7_sectordisagg_int.yml"); run_bash=false),
    read_from(joinpath(f_read,"7_sectordisagg_int_share.yml")),
)
dis_out = read_from(joinpath(f_read,"7_sectordisagg_out.yml"); run_bash=false)
agg_out = read_from(joinpath(f_read,"8_aggr_out.yml"); run_bash=true)

# Read original build stream output from WiNDC results so we can be completely consistent
# when we do our calculations later.
d = read_from(joinpath(f_read,"5_disagg_out.yml"); run_bash=true)

dis = share_disagg_sector!("", copy(d))
dis_comp = benchmark_against(dis, dis_out)

agg = aggregate_sector!(dis)
agg_comp = benchmark_against(agg, agg_out)