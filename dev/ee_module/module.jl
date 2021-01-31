using SLiDE
using DataFrames
import CSV
import Statistics

# Include development utilities.
f_dev = joinpath(SLIDE_DIR,"dev","ee_module")
include(joinpath(f_dev,"module_constants.jl"))

f_eem = joinpath(SLIDE_DIR,"src","build","eem")
include(joinpath(f_eem,"eem_bluenote.jl"))

f_bench = joinpath("dev","readfiles")
seds_out = read_from(joinpath(f_bench, "6_seds_out.yml"); run_bash=true)
bn_out = read_from(joinpath(f_bench, "7_bluenote_int.yml"); run_bash=true)

d, set, maps = eem()


# # # seds_out[:energy] = sort(select(
# # #         indexjoin(seds_out[:energy], maps[:pq], maps[:units_base]; kind=:left),
# # #     [:yr,:r,:src,:sec,:pq,:base,:units,:value]))


# # ------------------------------------------------------------------------------------------
# f_data = joinpath(SLIDE_DIR,"data")
# f_read = joinpath(SLIDE_DIR,"src","build","readfiles")

# set = merge(
#     read_from(joinpath(f_read,"setlist.yml")),
#     Dict(k=>df[:,1] for (k,df) in read_from(joinpath(f_data,"coresets","eem"))),
# )

# maps = read_from(joinpath(f_read,"maplist.yml"))
# maps[:og] = DataFrame(src=set[:as], s="cng")

# d = read_from(joinpath(f_data,"input","eia"))
# [d[k] = extrapolate_year(df, (yr=set[:yr],)) for (k,df) in d]

# # ----- ENERGY -----------------------------------------------------------------------------
# # Calculate elegen and benchmark. It works! Yay!

# # @info("printing calculations")
# eem_elegen!(d, maps)
# eem_energy!(d, set, maps)
# eem_co2emis!(d, set, maps)

seds_out[:elegen] = sort(select(filter_with(seds_out[:elegen], set), [:yr,:r,:src,:value]))
seds_out[:energy] = sort(select(indexjoin(seds_out[:energy], maps[:pq]; kind=:left), [:yr,:r,:src,:sec,:units,:value]))
# seds_out[:co2emis] = filter_with(seds_out[:co2emis], merge(set, Dict(:dataset=>["epa","seds"])))

# # ----- ENERGY -----------------------------------------------------------------------------
# d[:convfac] = _module_convfac(d)
# d[:cprice] = _module_cprice!(d, maps)
# d[:prodbtu] = _module_prodbtu!(d, set)

# var = :pq
# val = [:units,:value]

# df = copy(d[:energy])
# splitter = DataFrame(permute((src=[set[:ff];"ele"], sec=set[:demsec], pq=["p","q"])))
# splitter = indexjoin(splitter, maps[:pq]; kind=:left)

# df, df_out = split_fill_unstack(copy(d[:energy]), splitter, var, val);


# _module_pedef!(d, set)
# _module_pe0!(d, set)
# _module_ps0!(d)
# _module_prodval!(d, set, maps)
# # _module_shrgas!(d, set)
# # _module_netgen!(d)
# _module_eq0!(d, set)
# # _module_ed0!(d, set)

# # # !!!! Should just update in benchmark. This always seems to cause issues.
# d_comp = Dict()
# seds_comp = merge(seds_out, bn_int)

# seds_out_comp = Dict()
# for k in intersect(keys(d),keys(seds_comp))
#     local col = intersect(propertynames(d[k]), propertynames(seds_comp[k]))
#     global d_comp[k] = select(d[k], col)
#     global seds_out_comp[k] = select(seds_comp[k], col)    
# end

# # seds_out_comp[:ed0][!,:value] .*= 10

# d_bench = benchmark_against(d_comp, seds_out_comp; tol=1E-4)