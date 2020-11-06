using SLiDE

set = read_from(joinpath(SLIDE_DIR,"src","readfiles","setlist.yml"));

WINDC_DIR = joinpath(SLIDE_DIR,"dev","windc_1.0")
READ_DIR = joinpath(SLIDE_DIR,"dev","readfiles")

seds_inp = read_from(joinpath(READ_DIR, "seds_inp.yml"); run_bash = true)
seds_chk = read_from(joinpath(WINDC_DIR,"6_seds_chk"); run_bash = true)
seds_int = read_from(joinpath(WINDC_DIR,"6_seds_int"); run_bash = true)
# seds_out = read_from(joinpath(WINDC_DIR,"6_seds_out"); run_bash = true)
seds_out = read_from(joinpath(READ_DIR, "seds_out.yml"); run_bash = true)

seds_set = Dict()
for (k,df) in seds_out
    if size(df,2) == 1
        global set[k] = df[:,1]
        global seds_set[k] = df[:,1]
        delete!(seds_out,k)
    end
end

df = sort(read_file(joinpath(SLIDE_DIR,"data","input","seds.csv")))

# SEDS parameters used in bluenote.gms (or anywhere else): sedsenergy, co2emis, elegen

# Unit conversions:
#   - billion btu -> trillion btu
#   - million kWh -> billion kWh
# 


# pet_prc, pet_chk, gas_chk, gas_prc, elechk, col_chk, col_prc

# f_partition_out = joinpath(VALIDATE_DIR, "partition_o.yml")
# f_calibrate_out = joinpath(VALIDATE_DIR, "cal_o.yml")

# set = SLiDE.read_build(dataset, "sets")
# set = read_from(joinpath(SLIDE_DIR,"src","readfiles","setlist.yml"))

# io = SLiDE.read_build(default_dataset, "partition")
# cal = calibrate(dataset, copy(io), set; overwrite = false)