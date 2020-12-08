import CSV, Statistics
using SLiDE, DataFrames

function calc_relerr!(df::DataFrame, bench::Symbol, calc::Symbol)
    vals = [bench, calc]
    df[!,Symbol(calc,:_relerr)] .= abs.((df[:,bench] .- df[:,Symbol(calc,:_value)]) ./ df[:,bench])
    return df
end

# Read calibration information to compare outputs.
VALIDATE_DIR = joinpath(SLIDE_DIR, "dev", "validate", "readfiles")
f_partition_out = joinpath(VALIDATE_DIR, "partition_o.yml")
f_calibrate_out = joinpath(VALIDATE_DIR, "cal_o.yml")

cal_bluenote = read_from(f_calibrate_out)
set = read_from(joinpath(SLIDE_DIR,"src","readfiles","setlist.yml"))
io = SLiDE.read_build("default","partition")

# Define penalties to test and convert to symbols to use as indicators, file names.
PENALTY = [1E4, 1E5, 1E6, 1E7]
INDS = Symbol.(:E, Int.(log10.(PENALTY)))

# Run the calibration routine, varying the penalty.
cal = Dict(k => calibrate(string(k), copy(io), set; penalty_nokey = v, overwrite = true)
    for (k,v) in zip(INDS,PENALTY))

# Complete the summary comparison for each penalty.
# NOTE: ALL RESULTS ARE THE SAME WITHIN A TOLERANCE OF 1E-6.
d = [cal[k] for k in sort(collect(keys(cal)))]
comp_output = compare_summary(d, INDS; complete_summary = false)

# indicator = [:bluenote; INDS]
# d = [cal_bluenote; [cal[k] for k in sort(collect(keys(cal)))]]
# comp_penalty = compare_summary(d, indicator; complete_summary = true)

# # For each penalty, compute the relative error and save it, along with its mean
# # and standard deviation.
# bench = :bluenote_value
# path_save = joinpath(SLIDE_DIR,"dev","validate","penalty_nokey")

# df_mean = DataFrame(penalty = PENALTY)
# df_std = DataFrame(penalty = PENALTY)

# for (k,df) in comp_penalty
#     for ii in INDS
#         calc_relerr!(comp_penalty[k], bench, ii)
#     end
#     dropmissing!(comp_penalty[k])
#     select!(comp_penalty[k], setdiff(propertynames(comp_penalty[k]), [:reldiff,:equal_keys,:equal_values]))

#     df = comp_penalty[k]
#     df_mean_temp = DataFrame(Matrix(combine_over(df, findindex(df); fun = Statistics.mean)[:,end-3:end])', [k])
#     df_std_temp = DataFrame(Matrix(combine_over(df, findindex(df); fun = Statistics.std)[:,end-3:end])', [k])

#     global df_mean = [df_mean df_mean_temp]
#     global df_std = [df_std df_std_temp]

#     CSV.write(joinpath(path_save,"$k.csv"), comp_penalty[k])
# end

# CSV.write(joinpath(path_save, "mean.csv"), df_mean)
# CSV.write(joinpath(path_save, "std.csv"), df_std)