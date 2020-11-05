using SLiDE

READ_DIR = joinpath(SLIDE_DIR,"dev","readfiles")
!@isdefined(io_bluenote)  && (io_bluenote  = read_from(joinpath(READ_DIR, "2_partition_out.yml")))
!@isdefined(cal_bluenote) && (cal_bluenote = read_from(joinpath(READ_DIR, "3_calibrate_out.yml")))
!@isdefined(shr_bluenote) && (shr_bluenote = read_from(joinpath(READ_DIR, "4_share_out.yml")))
!@isdefined(dis_bluenote) && (dis_bluenote = read_from(joinpath(READ_DIR, "5_disagg_out.yml")))

seds_inp_bluenote = read_from(joinpath(READ_DIR, "6_seds_inp.yml"))
seds_out_bluenote = read_from(joinpath(READ_DIR, "6_seds_out.yml"))