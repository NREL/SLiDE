function read_to_check(x::String)
    y = read_file(x)
    d = Dict(k => sort(read_file(joinpath(SLIDE_DIR, y["Path"]..., ensurearray(v["name"])...)))
        for (k,v) in y["Input"])
    return Dict(Symbol(k) => edit_with(v, Rename.(propertynames(v), Symbol.(y["Input"][k]["col"])))
        for (k,v) in d)
end

# READ SETS
y = read_file(joinpath("data", "readfiles", "list_sets.yml"));
set = Dict((length(ensurearray(k)) == 1 ? Symbol(k) : Tuple(Symbol.(k))) =>
    sort(read_file(joinpath(y["Path"]..., ensurearray(v)...)))[:,1] for (k,v) in y["Input"])

# ******************************************************************************************
#   READ BLUENOTE OUTPUT RESULTS TO CHECK.
# ******************************************************************************************
println("  Reading i/o data...")
bio = read_to_check(joinpath(SLIDE_DIR,"calibrate","data_temp","check_io.yml"));

println("  Reading share data...")
bshr = read_to_check(joinpath(SLIDE_DIR,"calibrate","data_temp","check_share.yml"));
set[:notrd] = bshr[:notrd][:,:s];

# println("  Reading calibration data...")
# bcal = read_to_check(joinpath(SLIDE_DIR,"calibrate","data_temp","check_cal.yml"));
# if :va in propertynames(bcal[:va0])
#     valcols = Symbol.(unique(bcal[:va0][:,:va]))
#     bcal[:va0] = unstack(bcal[:va0], :va, :value)
#     bcal[:va0] = edit_with(bcal[:va0], Replace.(valcols,missing,0.0))
# end

# println("  Read disaggregation intermediary data...")
# bdisagg_int = read_to_check(joinpath(SLIDE_DIR,"calibrate","data_temp","check_disagg_int.yml"));

# println("  Read disaggregation output (this will take a minute)...")
# bdisagg_out = read_to_check(joinpath(SLIDE_DIR,"calibrate","data_temp","check_disagg.yml"));
# bdisagg = merge(bdisagg_int, bdisagg_out)

# disagg_check = Dict(k => missing for k in keys(bdisagg))

# k = :netval
# d = bshr[k]
# for (k,d) in bshr
#     if :gdpcat in propertynames(d)
#         global bshr[k] = unstack(d, :gdpcat, :value)
#         global bshr[k] = edit_with(bshr[k],
#             Replace.(setdiff(propertynames(bshr[k]),[:yr,:r,:g]), missing, 0.0))
#     end
# end

# # GSP -- LABOR
# bshr[:wg][!,:wg] .= true
# bshr[:hw][!,:hw] .= true

# bshr[:labor] = leftjoin(bshr[:labor], bshr[:hw], on = Pair.([:r,:g], [:r,:g]))
# bshr[:labor] = leftjoin(bshr[:labor], bshr[:wg], on = Pair.([:yr,:r,:g], [:yr,:r,:g]))
# bshr[:labor] = edit_with(bshr[:labor], Replace.([:hw,:wg], missing, false))