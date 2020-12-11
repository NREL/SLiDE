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
        operation = /,
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
set[:demsec] = ["com","ind","res","trn"]

set[:src] = ["col", "gas", "ge", "hy", "nu", "oil", "so", "wy"]
set[:e] = ["col", "cru", "ele", "gas", "oil"]
set[:ff] = ["col", "gas", "oil"]

# SLiDE data.
f_input = joinpath("data","input")
f_eia = joinpath(f_input,"eia")
d = read_from(f_eia)

# blueNOTE data (for comparison)
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

# col = intersect(propertynames(d[:energy]), propertynames(seds_out[:energy]));
# benchmark_against(d[:elegen][:,[:yr,:r,:src,:value]], seds_out[:elegen])
# benchmark_against(d[:energy][:,col], seds_out[:energy][:,col])

set[:co2dim] = unique(d[:emissions][:,:src])

id=[:btu,:co2perbtu]
df = filter_with(d[:energy], (src=set[:e], sec=set[:sec], units=BTU))
df = convertjoin(df, maps[:co2perbtu]; id=id)
df = convertjoin(df, maps[:operate]; id=id)