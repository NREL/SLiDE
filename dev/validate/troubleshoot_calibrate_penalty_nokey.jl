
# COMPARE CALIBRATION OUTPUTS.
cal_bluenote = read_with_gdx(f_calibrate_out)
set = read_from(joinpath(SLIDE_DIR,"src","readfiles","setlist.yml"))

PENALTY = [1E4, 1E5, 1E6, 1E7]
INDS = Symbol.(:E, Int.(log10.(PENALTY)))

cal = Dict(k => calibrate(string(k), copy(io), set; penalty_nokey = v) for (k,v) in zip(INDS,PENALTY))


d = [cal_bluenote; [cal[k] for k in sort(collect(keys(cal)))]]
indicator = [:bluenote; INDS]

comp_penalty = compare_summary(d, indicator; complete_summary = true)

k = :id0
df = comp_penalty[k]

vals = find_oftype(df, AbstractFloat)
bench = :bluenote_value

path_save = joinpath(SLIDE_DIR,"dev","validate","penalty_nokey")

function calc_relerr!(df::DataFrame, bench::Symbol, calc::Symbol)
    vals = [bench, calc]
    df[!,Symbol(calc,:_relerr)] .= abs.((df[:,bench] .- df[:,Symbol(calc,:_value)]) ./ df[:,bench])
    return df
end

df_mean = DataFrame(penalty = PENALTY)
df_std = DataFrame(penalty = PENALTY)


for (k,df) in comp_penalty
    for ii in INDS
        calc_relerr!(comp_penalty[k], bench, ii)
    end
    dropmissing!(comp_penalty[k])
    select!(comp_penalty[k], setdiff(propertynames(comp_penalty[k]), [:reldiff,:equal_keys,:equal_values]))

    df = comp_penalty[k]
    df_mean_temp = DataFrame(Matrix(combine_over(df, findindex(df); fun = Statistics.mean)[:,end-3:end])', [k])
    df_std_temp = DataFrame(Matrix(combine_over(df, findindex(df); fun = Statistics.std)[:,end-3:end])', [k])

    global df_mean = [df_mean df_mean_temp]
    global df_std = [df_std df_std_temp]

    CSV.write(joinpath(path_save,"$k.csv"), comp_penalty[k])
end

CSV.write(joinpath(path_save, "mean.csv"), df_mean)
CSV.write(joinpath(path_save, "std.csv"), df_std)