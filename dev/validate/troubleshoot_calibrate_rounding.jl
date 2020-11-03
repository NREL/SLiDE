using SLiDE, DataFrames

# RUN NOTES: Unzip windc_1.0.zip (from MS Teams) and add SLiDE/dev/validate/windc_1.0.

function check_constraints!(d::Dict, set::Dict)
    mkt_pa!(d)
    mkt_py!(d)
    mkt_pm!(d)
    prf_y!(d)
    prf_a!(d, set)
end

function mkt_pa!(d::Dict)
    a0 = copy(d[:a0])
    id0_fd0 = combine_over(d[:id0],:s) + combine_over(d[:fd0],:fd)
    d[:mkt_pa] = compare_summary([a0, id0_fd0], [:a0,:id0_fd0]; complete_summary = true)
    return sort!(d[:mkt_pa])
end

function mkt_py!(d::Dict)
    ys0_fs0 = combine_over(d[:ys0],:s) + d[:fs0]
    ms0_y0 = combine_over(d[:ms0],:m) + d[:y0]
    d[:mkt_py] = compare_summary([ys0_fs0, ms0_y0], [:ys0_fs0,:ms0_y0]; complete_summary = true)
    return sort!(d[:mkt_py])
end

function mkt_pm!(d::Dict)
    ms0 = combine_over(d[:ms0],:g)
    md0 = combine_over(d[:md0],:g)
    d[:mkt_pm] = compare_summary([ms0, md0], [:ms0,:md0]; complete_summary = true)
    return sort!(d[:mkt_pm])
end

function prf_y!(d::Dict)
    ys0 = combine_over(d[:ys0],:g)
    id0_va0 = combine_over(d[:id0],:g) + combine_over(d[:va0],:va)
    d[:prf_y] = compare_summary([ys0, id0_va0], [:ms0,:md0]; complete_summary = true)
    return sort!(d[:prf_y])
end

function prf_a!(d::Dict, set::Dict)
    df1 = fill_with((yr = set[:yr], g = set[:g]), 1.0)
    pta0 = d[:a0] * (df1 - d[:ta0]) + d[:x0]
    ptm0 = d[:y0] + d[:m0]*(df1 + d[:tm0]) + combine_over(d[:md0],:m)
    d[:prf_a] = compare_summary([pta0, ptm0], [:pta0,:ptm0]; complete_summary = true)
    return sort!(d[:prf_a])
end

function compare_constraints(d::Dict)
    constraint_keys = [:mkt_pa, :mkt_pm, :mkt_py, :prf_y, :prf_a]
    (d_keys, d_max) = compare_keys(Dict{Symbol,Any}(k => d[k] for k in constraint_keys))
    return (d_keys, d_max)
end

function missing_indices(d)
    d_ans = Dict()
    for (k,df) in d
        df == true && continue
        idx = setdiff(findindex(df),[:yr])
        # d_ans[k] = NamedTuple{Tuple(idx,)}(tuple(Matrix(unique(dropmissing(df[:,idx])))))
        d_ans[k] = unique(dropmissing(df[:,idx]))
        length(idx) == 1 && println("$k\t",idx[1]," ",d_ans[k][:,1])
    end
    return d_ans
end

include(joinpath(SLIDE_DIR,"dev","validate","validation_functions.jl"))

# ------------------------------------------------------------------------------------------
default_dataset = "default"
dataset = "cal_zero_fd_pce_only"
# dataset = "prezero_negatives"

VALIDATE_DIR = joinpath(SLIDE_DIR, "dev", "validate", "readfiles")
f_partition_out = joinpath(VALIDATE_DIR, "partition_o.yml")
f_calibrate_out = joinpath(VALIDATE_DIR, "cal_o.yml")

# set = SLiDE.read_build(dataset, "sets")
set = read_from(joinpath(SLIDE_DIR,"src","readfiles","setlist.yml"))

io = SLiDE.read_build(default_dataset, "partition")
cal = calibrate(dataset, copy(io), set; overwrite = false)

cal_bluenote = read_from(f_calibrate_out)

d_cal_comp = benchmark_against(cal, cal_bluenote; tol = 1E-6)
(d_cal_keys, d_cal_max) = compare_keys(d_cal_comp)

# The calibration values look mostly pretty good, except for id0 and fd0, which have very
# small values for indices that are missing (i.e., = 0) in the benchmark.
display(d_cal_keys)
d_cal_missing = missing_indices(d_cal_keys)

# # SUSPICION: The mkt_pa(i) accounting constraint is the only constraint that does not equate
# # two sums. I wonder if one side is more strictly enforced because it is/isn't a function?
# # Let's see what's up with this constraint...
# check_constraints!(cal, set)
# check_constraints!(cal_bluenote, set)

# (cal_constraints_keys, cal_constraints_max) = compare_constraints(cal)
# (cal_bluenote_constraints_keys, cal_bluenote_constraints_max) = compare_constraints(cal_bluenote)

# # LIKE WE THOUGHT! blueNOTE constraints don't have any key discrepancies.
# # So this has gotta be where the cutoff happens in GAMS, right?
# @info("blueNOTE constraint comparison")
# display(cal_bluenote_constraints_keys)

# @info("SLiDE constraint comparison")
# display(cal_constraints_keys)

# # Here, it's interesting that the missing keys in each constraint are imrg and oth/use.
# @info("Missing keys: SLiDE constraints")
# cal_constraints_missing = missing_indices(cal_constraints_keys)

# # The zero/small value discrepancy for id0 is the same as for each constraint.
# # For prf_y: note that this sets the sum of ys0 over i/g = RHS. We fix the output of ys0 = 0
# # for j/s = [oth,use]. So the sum over these values will = 0.
# if :id0 in keys(d_cal_missing)
#     @info("Missing keys: id0")
#     display(d_cal_missing[:id0])
# end

# # Fixing fd0 (with the exception of fd = pce) is commented in blueNOTE and SLiDE.
# # What's up with this?
# if :fd0 in keys(d_cal_missing)
#     @info("Missing keys: fd0")
#     display(d_cal_missing[:fd0])
# end

# ------------------------------------------------------------------------------------------
# Check that we're fixing things correctly...
# 
# Fix ys0 = 0 for j/s = [oth,use]. This is working how it should be, since (oth,use) are not
# in cal[:ys0]'s set when zeros are dropped.
setdiff(["oth","use"], unique(dropzero(cal[:ys0])[:,:s]))

# (fs0,m0,va0) should be fixed to their original values. Only fs0 completely meets this
# criteria. The others are close-ish, but not quite there.
check_fixed = Dict(k => compare_summary([io[k], cal[k]], [:partition, :cal])
    for k in [:va0,:fs0,:m0])

# # Look at io vs. bluenote calibration.
# @info("blueNOTE: zero -> value?... value -> zero?")
# d_io_bn = compare_summary([io, cal_bluenote], [:io,:cal_bn]; complete_summary = true);
# [println("$k\t",any(ismissing.(df[:,:io_value])), "\t", any(ismissing.(df[:,:cal_bn_value]))) for (k,df) in d_io_bn]

# @info("SLiDE: zero -> value?... value -> zero?")
# d_io = compare_summary([io, cal], [:io,:cal]; complete_summary = true);
# [println("$k\t", any(ismissing.(df[:,:io_value])), "\t", any(ismissing.(df[:,:cal_value]))) for (k,df) in d_io]


# d_io_bn[:fd0][ismissing.(d_io_bn[:fd0][:,:cal_bn_value]),:]