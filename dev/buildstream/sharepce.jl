using CSV
using DataFrames
using DelimitedFiles
using YAML
using Query

using SLiDE

# ******************************************************************************************
#   READ BLUENOTE OUTPUT RESULTS TO CHECK.
# ******************************************************************************************
y = read_file(joinpath("dev","buildstream","check_share.yml"));
bluenote = Dict(k => sort(read_file(joinpath(y["SharePath"]..., ensurearray(v["name"])...)))
    for (k,v) in y["ShareInput"])
bluenote = Dict(Symbol(k) => edit_with(v, Rename.(names(v), Symbol.(y["ShareInput"][k]["col"])))
    for (k,v) in bluenote)

# ******************************************************************************************
#   READ SETS AND SLiDE SUPPLY/USE DATA.
# ******************************************************************************************
y = read_file(joinpath("dev","buildstream","setlist.yml"));
set = Dict(Symbol(k) => sort(read_file(joinpath(y["SetPath"]..., ensurearray(v)...)))[:,1]
    for (k,v) in y["SetInput"])

# Define edits to perform on each input DataFrame.
x = Dict()
x[:gsp] = [
    Map(joinpath("crosswalk","gsp.csv"), [:gsp_code], [:windc_code], [:si], [:s], :left);
    Map(joinpath("..","coresets","yr.csv"), [:yr], [:yr], [:yr], [:yr], :left);
    Map(joinpath("..","coresets","r","state.csv"), [:r], [:r], [:r], [:r], :left);
    Drop.([:yr,:r,:s], missing, "==");
    Order([:yr,:r,:gdpcat,:s,:si,:value], [Int, String, String, String, Int, Float64])
];
x[:pce] = [
    Map(joinpath("crosswalk","pce.csv"), [:pg], [:g], [:pg], [:g], :left);
    Map(joinpath("..","coresets","yr.csv"), [:yr], [:yr], [:yr], [:yr], :left);
    Map(joinpath("..","coresets","r","state.csv"), [:r], [:r], [:r], [:r], :left);
    Drop.([:yr,:r,:g], missing, "==");
    Order([:yr,:r,:g,:value], [Int, String, String, Float64])
];
x[:utd] = [
    Add(:share, 0.0);
    Map(joinpath("crosswalk","naics.csv"), [:naics_code], [:windc_code], [:n], [:s], :left);
    Map(joinpath("..","coresets","yr.csv"), [:yr], [:yr], [:yr], [:yr], :left);
    Map(joinpath("..","coresets","r","state.csv"), [:r], [:r], [:r], [:r], :left);
    Drop.([:yr,:r], missing, "==");
    Order([:yr,:r,:s,:t,:value,:n], [Int, String, String, String, Float64, Int])
];
x[:cfs] = [
    Map(joinpath("crosswalk","sctg.csv"), [:sctg_code], [:windc_code], [:sg], [:g], :left);
    Drop(:g, missing, "==")
    # Order([:orig_state,:dest_state,:n,:g,:units,:value],[String,String,Int,String,String,Float64])
]

# Read share info.
shr = Dict()
shr[:cfs] = read_file(joinpath("data", "output", "cfs_state.csv"))
shr[:gsp] = read_file(joinpath("data", "output", "gsp_state.csv"))
shr[:pce] = read_file(joinpath("data", "output", "pce.csv"))
shr[:sgf] = read_file(joinpath("data", "output", "sgf.csv"))
shr[:utd] = read_file(joinpath("data", "output", "utd.csv"))

[global shr[k] = edit_with(shr[k], x[k]) for k in keys(shr) if k in keys(x)]


function filter_with(df::DataFrame, set::Dict)
    cols = find_oftype(df, Not(AbstractFloat))

    cols_sets = intersect(cols, collect(keys(set)));
    vals_sets = [set[k] for k in cols_sets]
    list_sets = NamedTuple{Tuple(cols_sets,)}(vals_sets,)

    df = fill_zero(list_sets, df);
    return df
end


# # ******************************************************************************************
# """
# ## PCE Shares
# """
# shr[:pce][!,:share] .= shr[:pce][:,:value] ./ sum_over(shr[:pce], :r; keepkeys = true)
# # PCE Share. Regional shares of final consumption
# #!  pce_map(r,g,yr) = sum(map(g,pg), pce_raw_units(yr,r,pg,"millions of us dollars (USD)"));
# #!  pce_shr(yr,r,g) = pce_map(r,g,yr) / sum(r.local, pce_map(r,g,yr));

# # ******************************************************************************************
# # # Share of total trade by region.
# # #!  usatrd_(yr,r,s,t) = sum(map(n,s), usatrd(r,n,yr,t));
# # #!  usatrd_shr(yr,r,s,t)$(NOT notinc(s) and sum(r.local, usatrd_(yr,r,s,t)))
# # #!      = usatrd_(yr,r,s,t) / sum(r.local, usatrd_(yr,r,s,t));
# # #!  usatrd_shr(yr,r,s,t)$(NOT notinc(s) AND NOT sum(r.local, usatrd_(yr,r,s,t)))
# # #!      = sum(yr.local, usatrd_(yr,r,s,t)) / sum((r.local,yr.local), usatrd_(yr,r,s,t));
# # shr[:utd] = fill_zero(sum_over(shr[:utd], :n; values_only = false))

# # shr[:utd][!,:share] .= shr[:utd][:,:value] ./ sum_over(shr[:utd], :r; keepkeys = true)
# # shr[:utd][isnan.(shr[:utd][:,:share]),:share] .= (sum_over(shr[:utd], :yr; keepkeys = true) ./
# #     sum_over(shr[:utd], [:yr,:r]; keepkeys = true))[isnan.(shr[:utd][:,:share])]

# # # Sectors not included in USA Trade Data.
# # #!  notinc(s) = yes$(NOT sum(n, map(n,s)));
# # shr[:notinc] = DataFrame(s = setdiff(set[:i], shr[:utd][:,:s]))

# # """
# # ## GSP Shares
# # """
# # df = fill_zero(copy(shr[:sgf]))

# # Labor share of value added from national dataset
# #!  PARAMETER lshr_0(yr,s) "Labor share of value added from national dataset";
# #!  lshr_0(yr,s)$(va_0(yr,'compen',s) + va_0(yr,'surplus',s)) =
# #!      va_0(yr,'compen',s) / (va_0(yr,'compen',s) + va_0(yr,'surplus',s));
# # !!!! I would move to partitionbea.jl
# io[:va0] = edit_with(io[:va0], Rename(:j,:s))
# io[:lshr0] = io[:va0] |> @filter(_.va == set[:va][1])  |> DataFrame
# io[:lshr0] = edit_with(io[:lshr0], Drop(:va, "all", "=="))

# io[:lshr0][!,:value] = io[:va0][io[:va0][:,:va] .== "compen",:value] ./
#     (io[:va0][io[:va0][:,:va] .== "compen",:value] + io[:va0][io[:va0][:,:va] .== "surplus",:value])

# # Calculated gross state product.
# shr[:gsp] = fill_zero(sum_over(shr[:gsp], :si; values_only = false))
# shr[:gsp][!,:calc] .= shr[:gsp][:,:value]

# shr[:gsp][shr[:gsp][:,:gdpcat] .== "gdp",:calc] .=
#     sum_over(shr[:gsp][findall(in(["cmp","gos","taxsbd"]), shr[:gsp][:,:gdpcat]),:], :gdpcat)
# shr[:gsp][!,:diff] = shr[:gsp][:,:calc] - shr[:gsp][:,:value]

# #!  region_shr(yr,r,s)$(sum(r.local, gsp0(yr,r,s,'Reported'))) =
# #!      gsp0(yr,r,s,'Reported') / sum(r.local,  gsp0(yr,r,s,'Reported'));
# #!  region_shr(yr,r,'use')$sum((r.local,s), region_shr(yr,r,s)) =
# #!      sum(s, region_shr(yr,r,s)) / sum((r.local,s), region_shr(yr,r,s));
# #!  region_shr(yr,r,'oth')$sum((r.local,s), region_shr(yr,r,s)) =
# #!      sum(s, region_shr(yr,r,s)) / sum((r.local,s), region_shr(yr,r,s));

# """
# Regional share of value added.
# """
# shr[:region] = shr[:gsp][shr[:gsp][:,:gdpcat] .== "gdp", [:yr,:r,:s,:value]]
# shr[:region][!,:share] .= shr[:region][:,:value] ./ sum_over(shr[:region], :r; keepkeys = true)

# # !!!! Not matching
# for SECT in ["use", "oth"]
#     df_temp = fill_zero((yr = set[:yr], r = set[:r], s = SECT))
#     df_temp[!,:share] .= sum_over(shr[:region], :s) ./
#         sum_over(sum_over(shr[:region], :r; keepkeys = true, values_only = false), :s)
    
#     global shr[:region] = [shr[:region]; df_temp]
# end

# # ******************************************************************************************
# # # # CFS
# # # df_cfs = copy(shr[:cfs])
# # # shr[:cfs] = sort(edit_with(shr[:cfs], x[:cfs]))

# # # # Local supply-demand. Trade that remains within the same region.
# # # #!  PARAMETER d0(r,g) "Local supply-demand (CFS)";
# # # #!  d0_(r,n,sg) = cfs2012_units(r,r,n,sg,"millions of us dollars (USD)");
# # # #!  d0(r,g) = sum(map(sg,g), sum(n, d0_(r,n,sg)));
# # # shr[:d0] = shr[:cfs][shr[:cfs][:,:orig_state] .== shr[:cfs][:,:dest_state],:]
# # # shr[:d0] = edit_with(shr[:d0], Rename(:orig_state,:r))[:,[:r,:n,:g,:units,:value]]
# # # shr[:d0] = sum_over(shr[:d0], :n; values_only = false)

# # # # Interstate trade (CFS)
# # # #!  PARAMETER mrt0(r,r,g) "Interstate trade (CFS)";
# # # #!  mrt0_(r,rr,n,sg)$(NOT SAMEAS(r,rr)) = cfs2012_units(r,rr,n,sg,"millions of us dollars (USD)");
# # # #!  mrt0(r,rr,g) = sum(map(sg,g), sum(n, mrt0_(r,rr,n,sg)));
# # # shr[:mrt0] = shr[:cfs][shr[:cfs][:,:orig_state] .!= shr[:cfs][:,:dest_state],:]
# # # shr[:mrt0] = sum_over(shr[:mrt0], :n; values_only = false)

# # # # National exports (CFS)
# # # #!  PARAMETER xn0(r,g) "National exports (CFS)";
# # # #!  xn0(r,g) = sum(rr, mrt0(r,rr,g));
# # # shr[:x0] = sum_over(shr[:mrt0], :dest_state; values_only = false)
# # # shr[:x0] = edit_with(shr[:x0], Rename(:orig_state, :r))

# # # # National demand (CFS)
# # # #   PARAMETER mn0(r,g) "National demand (CFS)";
# # # #   mn0(r,g) = sum(rr, mrt0(rr,r,g));
# # # shr[:mn0] = sum_over(shr[:mrt0], :orig_state; values_only = false)
# # # shr[:mn0] = edit_with(shr[:mn0], Rename(:dest_state, :r))

# # # # Regional purchase coefficient
# # # #   PARAMETER rpc(*,g) "Regional purchase coefficient";
# # # #   rpc(r,g)$(d0(r,g) + mn0(r,g)) = d0(r,g) / (d0(r,g) + mn0(r,g));
# # # shr[:mn0], shr[:d0] = fill_zero(shr[:mn0], shr[:d0]);
# # # shr[:rpc] = shr[:d0]
# # # shr[:rpc][!,:value] .= shr[:d0][:,:value] ./ (shr[:mn0][:,:value] + shr[:d0][:,:value])




# # # UTI = 0.9
# # # shr[:rpc] = [shr[:rpc];
# # #     DataFrame(permute((
# # #         r = set[:r], g = :uti, units = "billions of us dollard (USD)", value = UTI)))]

# # # # # # ii_zero = shr[:mn0] + shr[:d0] .== 0.0

# # # # # # df = copy(shr[:cfs])

# # # # # # first(df,3)