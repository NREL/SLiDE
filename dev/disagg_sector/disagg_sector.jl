using SLiDE
using DataFrames
import Statistics

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