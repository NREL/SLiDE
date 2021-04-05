using SLiDE, DataFrames

f_dev = joinpath(SLIDE_DIR,"dev","disagg_sector")
include(joinpath(f_dev,"scale_structs.jl"))
include(joinpath(f_dev,"packaged.jl"))
include(joinpath(f_dev,"scale_with.jl"))


# Check...
f_read = joinpath(SLIDE_DIR,"dev","readfiles")
dis_in = read_from(joinpath(f_read,"6_sectordisagg_int_share.yml"))
dis_out = read_from(joinpath(f_read,"6_sectordisagg_out.yml"))
agg_out = read_from(joinpath(f_read,"7_aggr_out.yml"))

setin = read_from(joinpath("src","build","readfiles","setlist.yml"))
din = read_from(joinpath(f_read,"5_disagg_out.yml"); run_bash=false)

path = joinpath(SLIDE_DIR,"data","coremaps","scale","sector","eem_pmt.csv")
dfmap = read_file(path)[:,1:2]

# Filter years -> [2007,2012]
dis_out = Dict(k => filter_with(df, (yr=[2007,2012],)) for (k,df) in dis_out)
agg_out = Dict(k => filter_with(df, (yr=[2007,2012],)) for (k,df) in agg_out if :yr in propertynames(df))
din = Dict{Any,Any}(k => filter_with(df, (yr=[2007,2012],)) for (k,df) in din)


# Read things.
set = merge(Dict(), setin)
d = merge(Dict(), copy(din))
SLiDE._set_sector!(set, set[:summary])

dis, agg = aggregate_with!(d, set)

dis_comp = benchmark_against(dis, dis_out)
agg_comp = benchmark_against(agg, agg_out)


# # ----- DISAGGREGATE SECTOR --------------------------------------------------------------
# d = aggregate_with!(d, set)  # (included)
# dis = copy(d)

# # ----- AGGREGATE --------------------------------------------------------------------------
# path = joinpath(SLIDE_DIR,"data","coremaps","scale","sector","eem_pmt.csv")
# dfmap = read_file(path)[:,1:2]

# index = Mapping(dfmap)
# set_scheme!(index, DataFrame(g=set[:sector]))

# scale_sector!(d, set, index; factor_id=:eem)
# agg = copy(d)


# x = copy(index)
# tax = :ty0
# key = :ys0

# sector = setdiff(propertynames(d[key]), propertynames(d[tax]))

# d[tax] = d[tax] * combine_over(d[key], sector; digits=false)
# scale_sector!(d, set, x, [key,tax]; factor_id=factor_id)







# k = :x0
# df = copy(d[k])
# x1 = compound_for!(copy(index), df[:,ensurearray(find_sector(df))], lst)
# df1a = edit_with(df, Map(x.data, [x.from;], [x.to;], [x.on;], [x.on;], :inner))
# df1b = combine_over(df1a, :dummy; digits=false)

# factor_id = :eem
# d[factor_id] = copy(index)
# x2 = compound_sector!(d, set, k; factor_id=factor_id)
# df2 = scale_with(d[k], x2)

# # # df1 = edit_with(df, Map(x.data, [x.from;], [x.to;], [x.on;], [x.on;], :inner))
# # # df2 = combine_over(df1, :dummy; digits=false)

