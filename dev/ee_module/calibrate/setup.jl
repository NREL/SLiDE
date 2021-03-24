import Ipopt
using JuMP

global lb = 0.25
global ub = 1.75
global lb_seds = 0.75
global ub_seds = 1.25
penalty_nokey = SLiDE.DEFAULT_PENALTY_NOKEY

year = 2016
io_in = read_from(joinpath(SLIDE_DIR,"data","state_model","build","eem"))

f_bench = joinpath(SLIDE_DIR,"dev","readfiles")
f_read = joinpath(SLIDE_DIR,"src","build","readfiles")
f_data = joinpath(SLIDE_DIR,"data")

# Read bluenote output for comparison / to fill in data we have not yet saved.
bn = merge(
    read_from(joinpath(f_bench, "8b_bluenote_energy.yml"); run_bash=true),
    read_from(joinpath(f_bench, "8b_bluenote_electricity.yml"); run_bash=true),
    read_from(joinpath(f_bench, "8b_bluenote_emissions.yml"); run_bash=true),
    read_from(joinpath(f_bench, "8b_bluenote_share.yml"); run_bash=true),
    read_from("dev/windc_1.0/4_eem/8b_bluenote_chk"; run_bash=true),
)

# !!!! Add bluenote data where we have not yet saved EEM output and filter year.
merge!(io_in, Dict(
    :fvs => bn[:fvs],
    :netgen => bn[:netgen],
))
io = Dict(k => filter_with(df, (yr=year,); drop=true) for (k,df) in io_in)

# Read sets and edit as needed (!!!!). Eventually, this will come from the EEM output.
# We will need to save the sets that correspond with each run stage (summary, scaled, EEM)
# so we can maybe make one "read data" function, or option for "build" that build step and
# get the associated info. We can do this by adding a method to build()
set = merge(
    read_from(joinpath(f_read,"setlist.yml")),
    Dict(k=>df[:,1] for (k,df) in read_from(joinpath(f_data,"coresets","eem"))),
)
set[:g] = unique(dropmissing(io[:ys0])[:,:g])
set[:s] = unique(dropmissing(io[:ys0])[:,:s])
set[:eneg] = ["col","ele","oil"]

# Calculate additional values for constraints.
io[:va0] = io[:ld0] + io[:kd0]
[io[append(k,:nat)] = combine_over(io[k],:r) for k in [:ys0,:x0,:m0,:va0,:g0,:i0,:cd0]]
[io[append(:fvs,k)] = filter_with(io[:fvs], (parameter=k,); drop=true) for k in ["ld0","kd0"]]

io[:netgen] = filter_with(io[:netgen], (dataset="seds",); drop=true)

# Fill zeros and convert to a dictionary of dictionaries.
d = Dict(k => convert_type(Dict, fill_zero(df; with=set)) for (k,df) in copy(io))

# Save set permutations and names.
SLiDE._calibration_set!(set)
SLiDE.add_permutation!(set, (:r,:e))
SLiDE.add_permutation!(set, (:r,:e,:g))
SLiDE.add_permutation!(set, (:r,:e,:s))
SLiDE.add_permutation!(set, (:r,:g,:e))
SLiDE.add_permutation!(set, (:r,:m,:e))