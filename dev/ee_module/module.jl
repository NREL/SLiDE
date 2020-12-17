using SLiDE
using DataFrames
import CSV
import Statistics

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
maps[:og] = DataFrame(src=set[:as], s="cng")
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
    DataFrame(
        from_units = "us dollars (USD) per million btu",
        factor = 1E-3,
        operation = *,
        by_units = "trillion btu",
        to_units = "billions of us dollars (USD)",
    );
    DataFrame(
        from_units = "us dollars (USD) per thousand kilowatthour",
        factor = 1E-3,
        operation = /,
        by_units = "billion kilowatthours",
        to_units = "billions of us dollars (USD)",
    );
]

maps[:units_base] = edit_with(maps[:units_base], Rename.(propertynames(maps[:units_base]), [:base,:units]))
maps[:pq] = edit_with(maps[:pq], Rename.([:pq_code,:src_code], [:pq,:src]))

# ------------------------------------------------------------------------------------------
# Column names! We'll use these later.
cols_elegen = [:yr,:r,:src,:units,:value]

(d, set) = build_data("state_model")

# SETS - Read the sets we already have saved. Then, manually define new ones.
# !!!! DON'T WORRY. Relevant sets will be saved once we know what is and isn't necessary.
# f_set = joinpath(SLIDE_DIR,"src","readfiles","setlist.yml")
# set = read_from(f_set)
set[:sec] = ["com", "ele", "ind", "res", "trn"]
set[:ed] = ["supply"; set[:sec]; "ref"]
set[:demsec] = ["com","ele","ind","ref","res","trn"]
set[:fds_e] = ["com","ind","res","trn"]

set[:src] = ["col", "gas", "ge", "hy", "nu", "oil", "so", "wy"]
set[:e] = ["col", "cru", "ele", "gas", "oil"]
set[:ff] = ["col", "gas", "oil"]

set[:as] = ["cru","gas"]

# SLiDE data.
f_input = joinpath("data","input")
f_eia = joinpath(f_input,"eia")
d = merge(d, read_from(f_eia))

# blueNOTE data (for comparison)
f_read = joinpath(SLIDE_DIR,"dev","readfiles")
bn_int = read_from(joinpath(f_read,"7_bluenote_int.yml"); run_bash = true)

seds_out = read_from(joinpath(f_read, "6_seds_out.yml"); run_bash = true)
seds_out[:elegen] = filter_with(select!(seds_out[:elegen], setdiff(cols_elegen,[:units])), set)
seds_out[:energy] = sort(select(
        indexjoin(seds_out[:energy], maps[:pq], maps[:units_base]; kind=:left),
    [:yr,:r,:src,:sec,:pq,:base,:units,:value]))

# ----- ENERGY -----------------------------------------------------------------------------

# Summing over (msn,source,sector) will be incorporated into the datastream.
# Leaving out for now to make it easier to verify.
IDX = [:yr,:r,:src,:sec,:units]
d[:seds] = edit_with(d[:seds], Combine("sum", IDX))

# Calculate elegen and benchmark. It works! Yay!

# @info("printing calculations")
module_elegen!(d, maps)
module_energy!(d, set, maps)
module_co2emis!(d, set, maps)


d[:convfac] = _module_convfac(d)
d[:cprice] = _module_cprice(d, maps)
d[:prodbtu] = _module_prodbtu(d, set)
_module_pedef!(d, set)
_module_pe0!(d, set)
_module_ps0!(d)
_module_prodval!(d, set, maps)
# _module_shrgas!(d, set)
# _module_netgen!(d)
_module_eq0!(d, set)
# _module_ed0!(d, set)



# # !!!! Should just update in benchmark. This always seems to cause issues.
d_comp = Dict()
seds_comp = merge(seds_out, bn_int)

seds_out_comp = Dict()
for k in intersect(keys(d),keys(seds_comp))
    local col = intersect(propertynames(d[k]), propertynames(seds_comp[k]))
    global d_comp[k] = select(d[k], col)
    global seds_out_comp[k] = select(seds_comp[k], col)    
end

# seds_out_comp[:ed0][!,:value] .*= 10

d_bench = benchmark_against(d_comp, seds_out_comp; tol=1E-4)