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

bn = merge(
    read_from(joinpath(f_bench, "8b_bluenote_energy.yml"); run_bash=true),
    read_from(joinpath(f_bench, "8b_bluenote_electricity.yml"); run_bash=true),
    read_from(joinpath(f_bench, "8b_bluenote_emissions.yml"); run_bash=true),
)

bn = copy(bn_out)
bn[:trdele] = edit_with(bn[:trdele], Replace.(:t,["imp","exp"],["imports","exports"]))

bn[:netgen][bn[:netgen][:,:dataset].=="seds",:value] *= 10
bn[:trdele][!,:value] *= 10
bn[:ed0][!,:value]    *= 10
bn[:emarg0][!,:value] *= 10
bn[:ned0][!,:value]   *= 10

# # # # seds_out[:energy] = sort(select(
# # # #         indexjoin(seds_out[:energy], maps[:pq], maps[:units_base]; kind=:left),
# # # #     [:yr,:r,:src,:sec,:pq,:base,:units,:value]))

# function _module_impele!(d::Dict)
#     df = filter_with(d[:seds], (src="ele", sec="imports"); drop=:sec)
#     d[:impele] = edit_with(df, Rename(:src,:g))
#     return d[:impele]
# end

# function _module_expele!(d::Dict)
#     df = filter_with(d[:seds], (src="ele", sec="exports"); drop=:sec)
#     d[:expele] = edit_with(df, Rename(:src,:g))
#     return d[:expele]
# end


# ------------------------------------------------------------------------------------------
# f_data = joinpath(SLIDE_DIR,"data")
# f_read = joinpath(SLIDE_DIR,"src","build","readfiles")

# set = merge(
#     read_from(joinpath(f_read,"setlist.yml")),
#     Dict(k=>df[:,1] for (k,df) in read_from(joinpath(f_data,"coresets","eem"))),
# )

# maps = read_from(joinpath(f_read,"maplist.yml"))

# d = read_from(joinpath(f_data,"input","eia"))
# [d[k] = extrapolate_year(df, (yr=set[:yr],)) for (k,df) in d]
d_aggr = read_from("data/state_model/build/aggregate")
d_eem, set, maps = eem("state_model")

maps[:og] = DataFrame(src=set[:as], s="cng")

d = merge!(Dict(), d_eem, d_aggr)

# # # ----- ENERGY -----------------------------------------------------------------------------
# # # Calculate elegen and benchmark. It works! Yay!

# # # @info("printing calculations")
# # eem_elegen!(d, maps)
# # eem_energy!(d, set, maps)
# # eem_co2emis!(d, set, maps)

# # seds_out[:elegen] = sort(select(filter_with(seds_out[:elegen], set), [:yr,:r,:src,:value]))
# # seds_out[:energy] = sort(select(indexjoin(seds_out[:energy], maps[:pq]; kind=:left), [:yr,:r,:src,:sec,:units,:value]))
# # seds_out[:co2emis] = filter_with(seds_out[:co2emis], merge(set, Dict(:dataset=>["epa","seds"])))


# ----- ENERGY -----------------------------------------------------------------------------
d[:convfac] = _module_convfac(d)
d[:cprice] = _module_cprice!(d, maps)
d[:prodbtu] = _module_prodbtu!(d, set)
d[:pedef] = _module_pedef!(d, set)
d[:pe0] = _module_pe0!(d, set)
d[:ps0] = _module_ps0!(d)
d[:prodval] = _module_prodval!(d, set, maps)
d[:shrgas] = _module_shrgas!(d)
d[:netgen] = _module_netgen!(d)
d[:trdele] = _module_trdele!(d)
d[:eq0] = _module_eq0!(d, set)
d[:ed0] = _module_ed0!(d, set, maps)
d[:emarg0] = _module_emarg0!(d, set, maps)
d[:ned0] = _module_ned0!(d)






# maps[:operation] -> operate is WRONG here. Should be *, not /
# :usd_per_kwh
# :kwh


# scheme = :s=>:src
# (from,to) = (scheme[1], scheme[2])


# # Could maybe figure out the crossjoin situation --
# # what do we do if some of the columns overlap but others don't?
# # CHECK THIS by looking at disagg and how we cross join regions and whatnot.
# # I think this really becomes an issue when we have multiple columns that don't overlap.
# # LIKE WE DO FOR FILLING ZEROS WHEN WE UNSTACK? -- FOR ALL OF IT. YAY!


# consumer expeniture survey (CEX - Tom has done this)
# look at expenditure by household and break out by race.
# if ACS responded to CEX, what would they say?
# did this work for the Citizen's climate lobby
# data to break out households by demographics, race -- so we can flexibly 
# cq climate justice webstie -- some of the info from lead
# it's going to look like ej screen?

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