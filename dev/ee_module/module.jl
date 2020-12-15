using SLiDE
using DataFrames
import CSV

global BTU = "trillion btu"
global KWH = "billion kilowatthours"
global USD = "billions of us dollars (USD)"
global USD_PER_KWH = "us dollars (USD) per thousand kilowatthour"
global USD_PER_BTU = "us dollars (USD) per million btu"
global BTU_PER_BARREL = "million btu per barrel"
global POPULATION = "thousand"
global CHAINED_USD = "millions of chained 2009 us dollars (USD)"

f_eia = joinpath(SLIDE_DIR,"src","build","eia")
include(joinpath(f_eia,"_module_utils.jl"))
include(joinpath(f_eia,"module_bluenote.jl"))
include(joinpath(f_eia,"module_co2emis.jl"))
include(joinpath(f_eia,"module_elegen.jl"))
include(joinpath(f_eia,"module_energy.jl"))

maps = Dict()
maps[:elegen] = read_file(joinpath("data","coremaps","select","elegen.csv"))
maps[:co2perbtu] = read_file(joinpath("data","coremaps","define","co2perbtu.csv"))
maps[:pq] = read_file(joinpath("data","coremaps","crosswalk","seds_pq.csv"))
maps[:units_base] = read_file(joinpath("data","coremaps","define","units.csv"))
maps[:operate] = [
    DataFrame(
        from_units = "trillion btu",
        factor = 1e3,
        operation = /,
        by_units = "btu per kilowatthour",
        to_units = "billion kilowatthours",
    );
    DataFrame(
        from_units = "us dollars (USD) per barrel",
        factor = 1.,
        operation = /,
        by_units = "million btu per barrel",
        to_units = "us dollars (USD) per million btu",
    );
    DataFrame(
        from_units = "billions of us dollars (USD)",
        factor = 1e3,
        operation = /,
        by_units = "trillion btu",
        to_units = "us dollars (USD) per million btu",
    );
    DataFrame(
        from_units = "billions of us dollars (USD)",
        factor = 1e3,
        operation = /,
        by_units = "billion kilowatthours",
        to_units = "us dollars (USD) per thousand kilowatthour",
    );
    DataFrame(
        from_units = "trillion btu",
        factor = 1e-3,
        operation = *,
        by_units = "kilograms CO2 per million btu",
        to_units = "million metric tons of carbon dioxide",
    );
]

maps[:units_base] = edit_with(maps[:units_base], Rename.(propertynames(maps[:units_base]), [:base,:units]))
maps[:pq] = edit_with(maps[:pq], Rename.([:pq_code,:src_code], [:pq,:src]))

# maps[:pq] = SLiDE.sort_unique(select([
#     DataFrame(src="ele", pq=["q","p"], units=[KWH,USD_PER_KWH]);
#     crossjoin(
#         DataFrame(src=setdiff(set[:e],["ele"])),
#         DataFrame(pq=["q","p"], units=[BTU,USD_PER_BTU]),
#     );
# ], [:src,:units,:pq]))

# maps[:units_base] = DataFrame(
#     base  = ["btu","kwh","usd","usd_per_kwh","usd_per_btu","btu_per_barrel","pop","xusd"],
#     units = [BTU,KWH,USD,USD_PER_KWH,USD_PER_BTU,BTU_PER_BARREL,POPULATION,CHAINED_USD],
# )

# ------------------------------------------------------------------------------------------
# Column names! We'll use these later.
cols_elegen = [:yr,:r,:src,:units,:value]

# SETS - Read the sets we already have saved. Then, manually define new ones.
# !!!! DON'T WORRY. Relevant sets will be saved once we know what is and isn't necessary.
f_set = joinpath(SLIDE_DIR,"src","readfiles","setlist.yml")
set = read_from(f_set)
set[:sec] = ["com", "ele", "ind", "res", "trn"]
set[:ed] = ["supply"; set[:sec]; "ref"]
set[:demsec] = ["com","ele","ind","ref","res","trn"]
set[:fds_e] = ["com","ind","res","trn"]

set[:src] = ["col", "gas", "ge", "hy", "nu", "oil", "so", "wy"]
set[:e] = ["col", "cru", "ele", "gas", "oil"]
set[:ff] = ["col", "gas", "oil"]

# SLiDE data.
f_input = joinpath("data","input")
f_eia = joinpath(f_input,"eia")
d = read_from(f_eia)

# blueNOTE data (for comparison)
bn_int = read_from("dev/windc_1.0/7_bluenote_int"; run_bash = true)
bn_int[:pedef] = edit_with(bn_int[:pedef], Rename.([:e,:Val],[:src,:value]))

f_read = joinpath(SLIDE_DIR,"dev","readfiles")
seds_out = read_from(joinpath(f_read, "6_seds_out.yml"); run_bash = true)
seds_out[:elegen] = filter_with(select!(seds_out[:elegen], setdiff(cols_elegen,[:units])), set)

# seds_out[:energy] = sort(select(indexjoin(seds_out[:energy], maps[:pq]; kind=:inner),
#     [:yr,:r,:src,:sec,:pq,:units,:value]))
maps
seds_out[:energy] = sort(select(
        indexjoin(seds_out[:energy], maps[:pq], maps[:units_base]; kind=:left),
    [:yr,:r,:src,:sec,:pq,:base,:units,:value]))

# # Filtering for operations.
# slice = Dict()
# slice[:ref] = DataFrame(permute((
#     src = "ele",
#     sec = ["ind","ref"],
#     base = ["btu","kwh"],
# )))

# slice[:ind] = select(crossjoin(
#     DataFrame(sec=["ind","ref"]), [
#         DataFrame(src=set[:ff], base="btu");
#         DataFrame(src="ele",    base="kwh");
#     ],
# ), [:src,:sec,:base])

# slice[:price_ff] = DataFrame(permute((
#     src=set[:ff],
#     sec="ele",
#     base=["usd","btu","usd_per_btu"],
# )));

# slice[:price_ff] = crossjoin(
#     DataFrame(src=set[:ff], sec="ele"),
#     DataFrame(base=["usd","btu","usd_per_btu"], key=["usd","x","per"])
# );

# slice[:price_ele] = DataFrame(permute((
#     src="ele",
#     sec=set[:sec],
#     base=["usd","kwh","usd_per_kwh"],
# )));

# slice[:price_ele] = crossjoin(
#     DataFrame(src="ele", sec=set[:sec]),
#     DataFrame(base=["usd","kwh","usd_per_kwh"], key=["usd","x","per"]),
# );

# slice[:price] = [
#     crossjoin(DataFrame(src=set[:ff], sec="ele"),  DataFrame(base=["usd","btu","usd_per_btu"], key=["usd","x","per"]));
#     crossjoin(DataFrame(src="ele", sec=set[:sec]), DataFrame(base=["usd","kwh","usd_per_kwh"], key=["usd","x","per"]));
# ]


# ----- ENERGY -----------------------------------------------------------------------------

# tmp_seds = Dict(k => split_with(seds_out[:energy],
#     indexjoin(df, maps[:units_d[base], maps[:pq]; kind=:inner))[1] for (k,df) in slice)
# [tmp_seds[k] = filter_with(tmp_seds[k], (pq="p",)) for k in [:price_ele,:price_ff]]


# Summing over (msn,source,sector) will be incorporated into the datastream.
# Leaving out for now to make it easier to verify.
IDX = [:yr,:r,:src,:sec,:units]
d[:seds] = edit_with(d[:seds], Combine("sum", IDX))

# Calculate elegen and benchmark. It works! Yay!

module_elegen!(d, maps)
module_energy!(d, set, maps)
module_co2emis!(d, set, maps)


bnff = filter_with(copy(bn_int[:pedef]), (src=set[:ff],))
bnele = filter_with(copy(bn_int[:pedef]), (src="ele",))



# See filter with? Maybe I figured it out there??

_bluenote_pedef(d, set)

# CALCULATE pe0:

df_demsec = DataFrame(sec=set[:demsec])
df_energy = filter_with(d[:energy], (src=set[:e], sec=set[:demsec]); drop=true)


# Non-cru:
pedef = crossjoin(d[:pedef], df_demsec)
p = filter_with(df_energy, (pq="p",); drop=true)

df = indexjoin(p, pedef; id=[:p,:pedef], fillmissing=false)
ii = .!ismissing.(df[:,:p])

df[!,:value] .= df[:,:pedef]
df[ii,:value] .= df[ii,:p]

# # cru:
# cprice = 
# df_cru = crossjoin(
#     edit_with(_module_cprice(d, maps), Deselect([:sec],"==")),
#     demsec,
# )

df_cprice = _module_cprice(d, maps)
df_r = combine_over(df_cprice, :r; fun=Statistics.mean)

# # see bluenote_pedef.
# # pe0(yr,r,'cru',demsec) = cprice(yr,r);
# # pe0(yr,r,'cru',demsec)$(not pe0(yr,r,'cru',demsec) and max(0,sedsenergy(r,'q','cru',demsec,yr))) =
# #     (1/sum(rr$cprice(yr,rr), 1)) * sum(rr, cprice(yr,rr));
# q = filter_with(copy(d[:energy]), (src="cru", sec=set[:demsec], pq="q"); drop=true)
# # q[]


# !!!! filter_with. option to specify in drop. Maybe we don't want pq, but we want something else.

# df_zero = permute(df[:, [:yr,:r,:src,:sec,:pq]])
# df_idx = indexjoin(df_zero, filter_with(maps[:pq], (pq="p",)); kind=:inner)
# df_idx = edit_with(df, Add(:value,0.0))


# Specify index to permute. ([:yr,:r,:src,:sec,:pq]). Hardest part will be figuring out
# where to stop 



# REALLY need fill zero support for when only some are specified.
# If given dataframe with no value, add value = 0.
# [:yr,:r,:src,:sec, (:units,:pq)]


# df = copy(d[:pedef])
# crossjoin(d[:pedef], DataFrame(sec=set[:demsec]))





# 

# q_sec = combine_over(df[:,idx;:q], :sec)




# df_sec = select(df_sec, intersect(col,propertynames(df_sec)))

# idx_avg, df_sec = split_with(fill_zero(dropnan(df_sec)), DataFrame(value=0.))

# df = combine_over(df, :sec)
# dfavg = combine_over(df_sec, :r) * combine_over(df[:,[idx;:q]], :sec) /
#         transform_over(combine_over())


# df = copy(df_sec)





# # split_with(df::DataFrame, splitter::NamedTuple) = split_with(df, fill_zero(splitter))
# # !!!! fill zero here causes issues for value

# function split_with(df::DataFrame, splitter::DataFrame)
#     # splitter = splitter[:,findindex(splitter)]
#     idx_join = intersect(propertynames(df), propertynames(splitter))
#     df_in = innerjoin(df, splitter, on=idx_join)
#     df_out = antijoin(df, splitter, on=idx_join)
#     # df_in = fill_zero(df_in, splitter)[1]
#     return df_in, df_out
# end



# !!!! WANT fill_zero that can take an input tuple. Or list of columns.
# df_sec = fill_zero
# dfout = fill_zero((yr=set[:yr], r=set[:r], src=set[:ff]))


# fill_zero(df_sec, (yr=set[:yr], r))


# # df = copy(df_in)
# # colkey = :key
# # value = (:units,:value)

# # value = ensurearray(value)
# # colnew = sort(convert_type.(Symbol, unique(df[:,colkey])))

# # rowkeys = setdiff(propertynames(df), ensurearray(colkey), ensurearray(value))
# # ii0 = length(rowkeys)+1

# # val = findvalue(df[:,value])
# # idx = setdiff(value,val)

# # lst = [unstack(df[:,[rowkeys;[colkey,val]]], colkey, val,
# #         renamecols=x-> (val==:value) ? x : append(val, x))
# #     for val in value]

# # df_ans = indexjoin(lst...; fillmissing=false)



# # ASSUMING ONE VALUE COLUMN TO BEGIN WITH.


# # return indexjoin(lst...; fillmissing=fillmissing)




# # value = ensurearray(value)
# # idx = findindex(df)

# # colnew = convert_type.(Symbol, unique(df[:,colkey]))
# # rowkeys = setdiff(idx, [colkey;value])

# # df_rowkeys = df[:, setdiff(idx,value)]
# # df_unstack = unique(df[:, setdiff(idx,rowkeys)])
# # df_idx = indexjoin(df_rowkeys, df_unstack)


# # df = indexjoin(df, indexjoin(df_rowkeys, df_unstack))
# # idx = 

# # dfperm = unique(df[:,[:units,:key]])

# # df = copy.([df, dfperm])
# # indicator = true
# # skipindex = :units

#     # N = length(df)

#     # col = propertynames.(df)
#     # val = findvalue.(df)
#     # flt = find_oftype.(df, AbstractFloat)

#     # # If there are no values, don't make any changes.
#     # all(length.(val) .== 0) && (return df, id)

#     # # If all value names are already unique, don't edit these.
#     # # !!!! What if they're already unique but there's an indicator?
#     # if length(unique([val...;])) == length([val...;])
#     #     from = fill([], (N,))
#     #     to = fill([], (N,))
#     # else
#     #     isempty(id) && (id = _generate_id(N))
#     #     from = val
#     #     # If there is only one value column / input dataframe, we are NOT including an
#     #     # indicator, and ids are defined, rename that one value column to match the given id.
#     #     to = if (all(length.(val) .== 1) && !indicator)
#     #         ensurearray.(id)
#     #     else
#     #         broadcast.(append, val, id)
#     #     end
#     # end






# !!!! Should just update in benchmark. This always seems to cause issues.
# d_comp = Dict()
# seds_out_comp = Dict()
# for k in intersect(keys(d),keys(seds_out))
#     local col = intersect(propertynames(d[k]), propertynames(seds_out[k]))
#     global d_comp[k] = select(d[k], col)
#     global seds_out_comp[k] = select(seds_out[k], col)
# end

# d_bench = benchmark_against(d_comp, seds_out_comp)