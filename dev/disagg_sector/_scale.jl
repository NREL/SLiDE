using SLiDE
using DataFrames
import CSV

include(joinpath(SLIDE_DIR,"dev","ee_module","module.jl"))



# ------------------------------------------------------------------------------------------

# dtmp = Dict(k=>d[k] for k in [:shrgas,(:shrgas,:g),(:shrgas,:s),(:shrgas,:g,:s),(:shrgas,:s,:g)])

# ------------------------------------------------------------------------------------------
set = read_from(joinpath("src","build","readfiles","setlist.yml"))

f_read = joinpath(SLIDE_DIR,"dev","readfiles")
d = read_from(joinpath(f_read,"5_disagg_out.yml"); run_bash=true)

# FUNCTION THAT TAKES A PATH AS AN INPUT.
path = joinpath(SLIDE_DIR,"data","coremaps","scale","sector","eem_pmt.csv")
dfmap = read_file(path)[:,1:2]

set[:sector] = unique(dfmap[:,:disagg])

# FUNCTION THAT TAKES A DATAFRAME AS AN INPUT.

# If given a dataframe, figure out which is the disaggregate level.
agg, dis = SLiDE._find_scheme(dfmap)
x = dfmap[:,dis]

# FUNCTION THAT TAKES A LIST AS AN INPUT:
dfscale = read_file(joinpath(SLIDE_DIR,"data","coremaps","scale","sector","bluenote.csv"))[:,1:2]

# Now, given this array, see if there are any invalid codes.
xdiff = setdiff(x, vcat(values.(eachcol(dfscale))...))
if !isempty(xdiff)
    @error("Input array contains non-bluenote codes. To examine user-defined codes, input a DataFrame defining how existing bluenote codes should map to the user-defined codes.")
end

# Determine if there are ANY detail-level codes. If not, we can simply filter parameters.
# Otherwise, perform the disaggregation.
hasdetail = !isempty(intersect(x, dfscale[:,:detail]))

# If there ARE detail-level codes, perform sectoral sharing. And disaggregation.
set_det = SLiDE._set_sector!(copy(set), set[:detail])

det = merge(
    read_from(joinpath("src","build","readfiles","input","detail.yml")),
    Dict(:sector=>:detail),
)
SLiDE._partition_y0!(det, set_det)

df = copy(det[:y0]);
df = select(df, Not(:units));

# ----- SOME method of extend over/with/idk ----
dfmap = copy(dfscale)





# CSV.write("data/state_model/build/share/sector.csv", df)

# x = x[1:3]
x = ["min","col_min","wpd"]

df = scale_with(df, dfmap)
dfmap, x = filter_scale(df, x)
# dfmap = map_year(dfmap, set[:yr])
# dfmap_save = copy(dfmap)

df = copy(d[:ys0])
on = SLiDE._find_sector(df)

# dfmap = scale_for(dfmap, x, on)
# df = scale_share(df, dfmap, on; key=missing)

# ------------------------------------------------------------------------------------------
# set = set[:sector]
# col = [:g,:s]
dfmap1 = SLiDE._extend_over(dfmap, x)
dfmap1 = SLiDE._compound_for(dfmap1, on; scheme=:summary=>:detail)





# df = copy(dfmap)
# idx = _intersect(df, x)
# # from, to = SLiDE._find_scheme(df[:,idx], x)

# key = :id0
# df = d[key]
# on = SLiDE._find_sector(df)
# scale_share(df, dfmap, on)

# col = 
# from, to = find_scheme