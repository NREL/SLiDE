import Ipopt
using JuMP

year = 2016
io_in = read_from("data/state_model/build/eem")
penalty_nokey = SLiDE.DEFAULT_PENALTY_NOKEY

# Read sets.
f_read = joinpath(SLIDE_DIR,"src","build","readfiles")
f_data = joinpath(SLIDE_DIR,"data")
set = merge(
    read_from(joinpath(f_read,"setlist.yml")),
    Dict(k=>df[:,1] for (k,df) in read_from(joinpath(f_data,"coresets","eem"))),
)
set[:g] = unique(dropmissing(io[:ys0])[:,:g])
set[:s] = unique(dropmissing(io[:ys0])[:,:s])
set[:eneg] = ["col","ele","oil"]

# Add bluenote data where we have not yet saved EEM output.
merge!(io_in, Dict(
    :fvs => bn[:fvs],
    :netgen => bn[:netgen],
))

# Isolate year to loop over.
io = Dict(k => filter_with(df, (yr=year,); drop=true) for (k,df) in io_in)

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
SLiDE.add_permutation!(set, (:r,:g,:e))
SLiDE.add_permutation!(set, (:r,:m,:e))

R = copy(set[:r])
G = copy(set[:g])
S = copy(set[:s])
M = copy(set[:m])
SNAT = setdiff(S,set[:eneg])