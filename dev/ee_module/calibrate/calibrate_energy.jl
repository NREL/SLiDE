using SLiDE
using DataFrames
using JuMP
import Ipopt
using Complementarity

# years that don't work: 97,98,16

include(joinpath(SLIDE_DIR,"src","build","calibrate","calibrate_energy.jl"))
include(joinpath(SLIDE_DIR,"dev","ee_module","calibrate","constraint_diagnostics.jl"))

name = "state_model_bluenote-ys0det-sg"
dataset = Dataset(name; eem=true)
d, set = build(dataset)

# # If re-building EEM up until disaggregating...
# d = read_from(joinpath(SLIDE_DIR,"dev","readfiles","5_disagg_out.yml"))
# d, set = SLiDE.build_eem(dataset, d, set)

# If reading info...
d = read_from("data/$name/eem/_disagg")
set = Dict{Any,Any}(k=>df[:,1] for (k,df) in read_from("data/$name/eem/sets"))
SLiDE.set_sector!(set, set[:sector])

select!(d[:netgen], Not(:units))

# read_set(build::string)

# ------------------------------------------------------------------------------------------
# Define year(s)
df_yr = DataFrame(yr=2016,)
# Define boundaries.
lb=0.25; ub=1.75; shift=0.5;
df_bounds = DataFrame(
    lb=[lb,lb,0],
    ub=[ub,ub,1000],
    lb_seds=[lb,lb+shift,0],
    ub_seds=[lb,lb+shift,1000],
)
# Define conditions.
cond_list = [
    :market,
    :expdef,
    :incbal,
    :netgen,
    :national,
    :value_share,
    :zero_profit,
]
cond = permute(fill([true,false], length(cond_list)))
# cond = cond[.|(all.(cond), sum.(cond).<=1)]
# cond = [cond[1]]
df_conditions = edit_with(
    DataFrame(cond),
    Rename.(Symbol.(1:length(cond_list)), cond_list),
)
# 
df = crossjoin(
    df_yr,
    df_bounds[[1],:],
    df_conditions,
)
df[!,:model] = Array{Any}(fill(nothing, size(df,1)))

for ii in 1:size(df,1)
    println("\n\n\nii: $ii,\t# of conditions: $(sum(df[ii,cond_list]))")
    local cal = calibrate_energy(d, set, df[ii,:yr];
        lower_bound=df[ii,:lb],
        upper_bound=df[ii,:ub],
        lower_bound_seds=df[ii,:lb_seds],
        upper_bound_seds=df[ii,:ub_seds],
        condition_market=df[ii,:market],
        condition_expdef=df[ii,:expdef],
        condition_incbal=df[ii,:incbal],
        condition_netgen=df[ii,:netgen],
        condition_national=df[ii,:national],
        condition_zero_profit=df[ii,:zero_profit],
        condition_value_share=df[ii,:value_share],
    )
    global df[ii,:model] = cal
    # global df[ii,:model] = collect(keys(cal))
end




# df = DataFrame(lb=0, ub=1000,)
# calib = calibrate_energy(d, set, year; optimize=false)

# ------------------------------------------------------------------------------------------
# This is Ipopt version 3.13.4, running with linear solver mumps.
# NOTE: Other linear solvers might be more efficient (see Ipopt documentation).
# 
# Number of nonzeros in equality constraint Jacobian...:    50951
# Number of nonzeros in inequality constraint Jacobian.:    13936
# Number of nonzeros in Lagrangian Hessian.............:    18252
# 
# Total number of variables............................:    20789
#                      variables with only lower bounds:    17784
#                 variables with lower and upper bounds:     3005
#                      variables with only upper bounds:        0
# Total number of equality constraints.................:     3892
# Total number of inequality constraints...............:     1934
#         inequality constraints with only lower bounds:     1885
#    inequality constraints with lower and upper bounds:        0
#         inequality constraints with only upper bounds:       49
# 
#                             (scaled)                 (unscaled)
# Objective...............:   7.4977388461566452e+03    7.4977388461566448e+08
# Dual infeasibility......:   1.0000000263817383e+02    1.0000000263817381e+07
# Constraint violation....:   2.3981178229498450e+03    2.3981178229498450e+03
# Complementarity.........:   1.7203787054874926e-09    1.7203787054874924e-04
# Overall NLP error.......:   2.3981178229498450e+03    1.0000000263817381e+07
# 
# Number of objective function evaluations             = 660
# Number of objective gradient evaluations             = 85
# Number of equality constraint evaluations            = 660
# Number of inequality constraint evaluations          = 660
# Number of equality constraint Jacobian evaluations   = 1
# Number of inequality constraint Jacobian evaluations = 1
# Number of Lagrangian Hessian evaluations             = 2
# Total CPU secs in IPOPT (w/o function evaluations)   =     69.475
# Total CPU secs in NLP function evaluations           =      1.442