# BLUE_DIR = joinpath("data", "windc_output", "2z_build_windcdatabase")
# bluenote_lst = [x for x in readdir(joinpath(SLIDE_DIR, BLUE_DIR)) if occursin(".csv", x)]
# bio_shr = Dict(Symbol(k[1:end-4]) => sort(edit_with(
#     read_file(joinpath(BLUE_DIR, k)), Rename(:Val, :value))) for k in bluenote_lst)

k = :region;    shr[k] = shr[k][:,intersect(propertynames(shr[k]), [collect(keys(set)); :share])]
k = :labor;     shr[k] = shr[k][:,intersect(propertynames(shr[k]), [collect(keys(set)); :share])]
k = :rpc;       shr[k] = shr[k][:,intersect(propertynames(shr[k]), [collect(keys(set)); :value])]