include("run.jl")
include(joinpath(SLIDE_DIR,"src","build","disagg.jl"))

io = read_to_check(joinpath(SLIDE_DIR,"data","readfiles","benchmark","disagg","partition.yml"));
shr = read_to_check(joinpath(SLIDE_DIR,"data","readfiles","benchmark","disagg","shr.yml"));
shr[:utd] = filter_with(shr[:utd], set; extrapolate = true)

cal = read_to_check(joinpath(SLIDE_DIR,"data","readfiles","benchmark","disagg","cal.yml"));
:va in propertynames(cal[:va0]) && (cal[:va0] = edit_with(unstack(copy(cal[:va0]), :va, :value), Replace.(Symbol.(set[:va]), missing, 0.0)))
set[:notrd] = setdiff(set[:g], unique(shr[:utd][:,:g]))

bdisagg_out = read_to_check(joinpath(SLIDE_DIR,"data","readfiles","benchmark","disagg","disagg_out.yml"));
bdisagg_int = read_to_check(joinpath(SLIDE_DIR,"data","readfiles","benchmark","disagg","disagg_int.yml"));
bdisagg = merge(bdisagg_out,bdisagg_int)

disagg_bench = Dict()

d = merge(copy(shr),copy(cal),Dict(
        :r => fill_with((r = set[:r],), 1.0),
        (:yr,:r,:g) => fill_with((yr = set[:yr], r = set[:r], g = set[:g]), 1.0)));

(d,set) = disagg!(d,set)


# function _disagg_hhadj(d::Dict)
#     dh = Dict(k => edit_with(copy(d[k]), Rename(:g,:s))
#         for k in [:c0,:ld0,:kd0,:yh0,:bopdef0,:ta0,:a0,:tm0,:ty0,:g0,:i0,:m0])
#     dh[:ys0] = copy(d[:ys0])

#     d[:hhadj] = dh[:c0] -
#         combine_over(dh[:ld0] + dh[:kd0] + dh[:yh0], :s) - dh[:bopdef0] -
#         combine_over(dh[:ta0]*dh[:a0] + dh[:tm0]*dh[:m0] + dh[:ty0]*combine_over(dh[:ys0],:g), :s) +
#         combine_over(dh[:g0] + dh[:i0], :s)
    
#     return d[:hhadj]
# end