using SLiDE, DataFrames

# PROBLEM: Calculated hw is different in SLiDE vs. blueNOTE and, therefore,
# calculated labor share is different. Labor share is used when disaggregating to find ld0.

VALIDATE_DIR = joinpath(SLIDE_DIR,"dev","validate")
WINDC_DIR = joinpath(VALIDATE_DIR,"windc_1.0")
READ_DIR = joinpath(VALIDATE_DIR,"readfiles")

include(joinpath(VALIDATE_DIR,"validation_functions.jl"))
f_partition_out = joinpath(READ_DIR, "partition_o.yml")
f_calibrate_out = joinpath(READ_DIR, "cal_o.yml")
f_share_out = joinpath(READ_DIR, "share_o.yml")
f_disagg_out = joinpath(READ_DIR, "disagg_o.yml")

cal_bluenote = read_from(f_calibrate_out)
shr_bluenote = read_from(f_share_out)
shr_bluenote_int = read_from(joinpath(WINDC_DIR,"4_share_int"))

dataset = "default"
set = read_from(joinpath(SLIDE_DIR,"src","readfiles","setlist.yml"))

# Use blueNOTE calibration result for va0 when comparing the method, so we know any
# discrepancies are due to the method and NOT due to rounding errors in the calibration
# routine. Using the SLiDE input sharing info is fine because these are already consistent
# with blueNOTE and edited as necessary.
d = merge(Dict(:va0 => cal_bluenote[:va0]),
    SLiDE.read_build(dataset, "share_i"))
SLiDE.share_region!(d,set)
SLiDE.share_labor!(d,set)

indicator = [:slide,:bluenote]

# Explicitly save labor share BEFORE averages are substituted based on hw and wg.
# These are the same! So we know we're good up to this point.
k = :labor_shr_pre_avg
d[k] = copy(d[:labor_calc][:,[findindex(d[:labor_calc]); k]])
d[k] = sort(edit_with(d[k], Rename(k,:value)))

compare_summary([dropzero(d[k]), dropzero(shr_bluenote_int[k])], indicator)

# Compare wg and hw. wg looks good, but hw is OFF.
d_temp = Dict(k => d[k] = unique(d[k][d[k][:,:value],1:end-1]) for k in [:hw,:wg])
k = :wg; compare_summary([d_temp[k], shr_bluenote_int[k]], indicator)
k = :hw; compare_summary([d_temp[k], shr_bluenote_int[k]], indicator; complete_summary = true)

# Join the calculation df with blueNOTE's hw index so we can see which step in the process
# threw us off.
k = :hw
shr_bluenote_int[k][!,k] .= true;
df = indexjoin([copy(d[:labor_calc]), shr_bluenote_int[k]];
    indicator = indicator, fillmissing = false)

# hw was calculated before any averages were applied, so :slide_labor_shr_pre_avg will tell
# us where this disconnect happened. Recall: SLiDE and blueNOTE values up to this point are
# the same, so there was a difference in logic here.
df[df[:,:bluenote_hw] .=== true, :]

# It looks like a lot of the values in :slide_labor_shr_pre_avg are zero, so we'll see if
# there are any NON-ZERO values for which blueNOTE's hw = true.. And all of the non-zero
# values are also included in SLiDE's hw!
# 
# Since hw is supposed to represent (region,sector) pairings with ALL wage shares > 1,
# I think we should stick with the SLiDE determination of hw.
df[.&(df[:,:bluenote_hw] .=== true, df[:,:slide_labor_shr_pre_avg] .!== 0.0), :]