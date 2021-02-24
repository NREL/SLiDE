using SLiDE
using DataFrames
import CSV
import Statistics

# Include development utilities.
f_dev = joinpath(SLIDE_DIR,"dev","ee_module")
include(joinpath(f_dev,"module_constants.jl"))

f_eem = joinpath(SLIDE_DIR,"src","build","eem")
include(joinpath(f_eem,"eem_bluenote.jl"))
include(joinpath(SLIDE_DIR,"src/build/disagg/disagg_energy.jl"))

f_bench = joinpath("dev","readfiles")

bn = merge(
    read_from(joinpath(f_bench, "8b_bluenote_energy.yml"); run_bash=true),
    read_from(joinpath(f_bench, "8b_bluenote_electricity.yml"); run_bash=true),
    read_from(joinpath(f_bench, "8b_bluenote_emissions.yml"); run_bash=true),
    read_from(joinpath(f_bench, "8b_bluenote_share.yml"); run_bash=true),
    # read_from(joinpath(f_bench, "8b_bluenote_check.yml"); run_bash=true),
    read_from("dev/windc_1.0/4_eem/8b_bluenote_chk"; run_bash=true),
)

bn1 = read_from(joinpath(f_bench, "8b_bluenote1_shrgas.yml"); run_bash=true)
bn2 = read_from(joinpath(f_bench, "8b_bluenote2_unfiltered.yml"); run_bash=true)
bn3 = read_from(joinpath(f_bench, "8b_bluenote3_filtered.yml"); run_bash=true)

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
d_aggr = read_from("data/state_model/build/aggregate")
d_eem, set, maps = eem("state_model")

d = merge!(Dict(), d_eem, d_aggr)
SLiDE._set_sector!(set, unique(d[:ys0][:,:s]))

# ------------------------------------------------------------------------------------------
# Address some discrepancies in energy values.
bn[:trdele] = edit_with(bn[:trdele], Replace.(:t,["imp","exp"],["imports","exports"]))

# bn[:netgen][bn[:netgen][:,:dataset].=="seds",:value] *= 10
# bn[:trdele][!,:value] *= 10
# bn[:ed0][!,:value]    *= 10
# bn[:emarg0][!,:value] *= 10
# bn[:ned0][!,:value]   *= 10
bn[:pctgen][!,:value] /= 100

# Fix some errors in bn2 output values.
function correct_bluenote!(d)
    [d[k][[x in set[:e] for x in d[k][:,:g]], :value] *= 10 for k in [:md0,:cd0,:id0]]
    [d[k][d[k][:,:g].=="ele",:value] *= 10 for k in [:x0,:m0]]

    d[:ys0][.&(
        [x in set[:e] for x in d[:ys0][:,:g]],
        d[:ys0][:,:s].==d[:ys0][:,:g],
    ),:value] *= 10

    SLiDE._disagg_hhadj!(d)
    return d
end

# bn2 = correct_bluenote!(bn2)
# bn3 = correct_bluenote!(bn3)
# delete!(bn3, :hhadj)

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
d[:pctgen] = _module_pctgen!(d, set)
d[:eq0] = _module_eq0!(d, set)
d[:ed0] = _module_ed0!(d, set, maps)
d[:emarg0] = _module_emarg0!(d, set, maps)
d[:ned0] = _module_ned0!(d)

d1 = copy(d)

disagg_energy!(d, set, maps)

parameters = collect(keys(SLiDE.build_parameters("parameters")))
# d2 = Dict(k => d[k] for k in [parameters;:inpshr])
d3 = Dict(k => d[k] for k in parameters)

dcomp = benchmark_against(d1, bn)
# dcomp1 = benchmark_against(d1, bn1)
# dcomp2 = benchmark_against(d2, merge(bn2, bn))
dcomp3 = benchmark_against(d3, bn3)

# # # # Could maybe figure out the crossjoin situation --
# # # # what do we do if some of the columns overlap but others don't?
# # # # CHECK THIS by looking at disagg and how we cross join regions and whatnot.
# # # # I think this really becomes an issue when we have multiple columns that don't overlap.
# # # # LIKE WE DO FOR FILLING ZEROS WHEN WE UNSTACK? -- FOR ALL OF IT. YAY!


# # # consumer expeniture survey (CEX - Tom has done this)
# # # look at expenditure by household and break out by race.
# # # if ACS responded to CEX, what would they say?
# # # did this work for the Citizen's climate lobby
# # # data to break out households by demographics, race -- so we can flexibly 
# # # cq climate justice webstie -- some of the info from lead
# # # it's going to look like ej screen?

# # # # # !!!! Should just update in benchmark. This always seems to cause issues.
# # # d_comp = Dict()
# # # seds_comp = merge(seds_out, bn_int)

# # # seds_out_comp = Dict()
# # # for k in intersect(keys(d),keys(seds_comp))
# # #     local col = intersect(propertynames(d[k]), propertynames(seds_comp[k]))
# # #     global d_comp[k] = select(d[k], col)
# # #     global seds_out_comp[k] = select(seds_comp[k], col)    
# # # end

# # # # seds_out_comp[:ed0][!,:value] .*= 10

# # # d_bench = benchmark_against(d_comp, seds_out_comp; tol=1E-4)