using SLiDE, DataFrames

include(joinpath(SLIDE_DIR,"dev","disagg_sector","scale_structs.jl"))

# Check...
f_read = joinpath(SLIDE_DIR,"dev","readfiles")
dis_in = read_from(joinpath(f_read,"6_sectordisagg_int_share.yml"))
dis_out = read_from(joinpath(f_read,"6_sectordisagg_out.yml"))

set = read_from(joinpath("src","build","readfiles","setlist.yml"))
din = read_from(joinpath(f_read,"5_disagg_out.yml"); run_bash=false)

path = joinpath(SLIDE_DIR,"data","coremaps","scale","sector","eem_pmt.csv")
dfmap = read_file(path)[:,1:2]
set[:sector] = unique(dfmap[:,:disagg])

# Filter years -> [2007,2012]
dis_out = Dict(k => filter_with(df, (yr=[2007,2012],)) for (k,df) in dis_out)
din = Dict{Any,Any}(k => filter_with(df, (yr=[2007,2012],)) for (k,df) in din)

set = merge(Dict(), set)
d = merge(Dict(), copy(din))

# # ----- SHARE SECTOR -----------------------------------------------------------------------
# # function share_sector(d::Dict, set::Dict)
    path = joinpath(SLIDE_DIR,"data","coremaps","scale","sector","bluenote.csv")
    dfmap = read_file(path)[:,1:2]

    # Get the detail-level info so we can disaggregate.
    set_det = SLiDE._set_sector!(copy(set), set[:detail])
    det = merge(
        read_from(joinpath("src","build","readfiles","input","detail.yml")),
        Dict(:sector=>:detail),
    )
    SLiDE._partition_y0!(det, set_det)

    df = select(det[:y0], Not(:units));

    # Initialize scaling information.
    factor = Factor(df)
    index = Index(dfmap)
    lst = copy(set[:sector])

    # 
    set_scheme!(factor, index)
    share_with!(factor, index)
    filter_with!(factor, index, lst)

#     return factor
# end

# ----- DISAGGREGATE SECTOR ----------------------------------------------------------------
scale_sector!(d, set, factor)

dcomp = benchmark_against(d, dis_out)