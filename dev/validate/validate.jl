using SLiDE, DataFrames
import Statistics
import CSV

include(joinpath(SLIDE_DIR,"dev","validate","validation_functions.jl"))
include(joinpath(SLIDE_DIR,"dev","readfiles","read_bluenote.jl"))

# ------------------------------------------------------------------------------------------
dataset = SLiDE.DEFAULT_DATASET

set = SLiDE.read_build(dataset, "sets");
set = read_from(joinpath(SLIDE_DIR,"src","readfiles","setlist.yml"));

io  = SLiDE.read_build(dataset, "partition")
cal = SLiDE.read_build(dataset, "calibrate")
shr = SLiDE.read_build(dataset, "share")
dis = SLiDE.read_build(dataset, "disagg")

# COMPARE PARTITION OUTPUTS. Compare blueNOTE data generated by partitionbea.gms with the
# SLiDE-generated partition data. These are consistent!
io_bluenote = read_from(f_partition_out)
d_io_comp = benchmark_against(io, io_bluenote)

# COMPARE SHARE OUTPUTS. (need to check on the difference in labor)
shr_bluenote = read_from(f_share_out)
shr_bluenote[:utd] = extrapolate_year(shr_bluenote[:utd], set[:yr])
shr = SLiDE.read_build(dataset, "share")
d_shr_comp = benchmark_against(shr, shr_bluenote)

# Here it gets a little more complicated...

# COMPARE CALIBRATION OUTPUTS.
cal_bluenote = read_from(f_calibrate_out)
cal = SLiDE.read_build(dataset, "calibrate")
d_cal_comp = benchmark_against(cal, cal_bluenote; tol = 1E-5)

(d_cal_keys, d_cal_max) = compare_keys(d_cal_comp)
df_cal_min = compare_minimum(cal, cal_bluenote)

# COMPARE DISAGGREGATIION OUTPUTS.
dis_bluenote = read_from(f_disagg_out)
dis = SLiDE.read_build(dataset, "disagg")
d_dis_comp = benchmark_against(dis, dis_bluenote; tol = 1E-3)

(d_dis_keys, d_dis_max) = compare_keys(d_dis_comp)
df_dis_min = compare_minimum(dis, dis_bluenote)

# ------------------------------------------------------------------------------------------
# COMPARE DISAGGREGATIION PROCESS. Here, we feed the blueNOTE-generated (from calibration and
# sharing) disaggregation input data into our disaggregation process and compare the
# blueNOTE and SLiDE disaggregation outputs.
dis_inp = merge(shr_bluenote, cal_bluenote)
set = read_from(joinpath(SLIDE_DIR,"src","readfiles","setlist.yml"))
(dis_process, set_process) = disagg("windc_benchmark", dis_inp, set; overwrite = false)

d_dis_process_comp = benchmark_against(dis_process, dis_bluenote; tol = 1E-6)