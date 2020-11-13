using SLiDE, DataFrames

set = read_from(joinpath(SLIDE_DIR,"src","readfiles","setlist.yml"));

WINDC_DIR = joinpath(SLIDE_DIR,"dev","windc_1.0")
READ_DIR = joinpath(SLIDE_DIR,"dev","readfiles")

seds_inp = read_from(joinpath(READ_DIR, "6_seds_inp.yml"); run_bash = true)
seds_chk = read_from(joinpath(WINDC_DIR,"6_seds_chk"); run_bash = true)
seds_int = read_from(joinpath(WINDC_DIR,"6_seds_int"); run_bash = true)
seds_out_temp = read_from(joinpath(WINDC_DIR,"6_seds_out"); run_bash = true)
seds_out = read_from(joinpath(READ_DIR, "6_seds_out.yml"); run_bash = true)

seds_set = Dict()
for (k,df) in seds_out_temp
    if size(df,2) == 1
        global set[k] = df[:,1]
        global seds_set[k] = df[:,1]
    end
end

d = Dict()
d[:seds] = read_file(joinpath("..","forked","SLiDEData","data","input_1.0","seds_datastream.csv"))
d[:emissions] = read_file(joinpath("..","forked","SLiDEData","data","input_1.0","emissions.csv"))

# d[:seds] = sort(read_file(joinpath(SLIDE_DIR,"data","input","seds.csv")))
d[:heatrate] = sort(read_file(joinpath(SLIDE_DIR,"data","input","heatrate.csv")))
d[:heatrate] = edit_with(d[:heatrate], Rename(:source,:src))

d[:heatrate] = filter_with(d[:heatrate], set; extrapolate = true)

# ------------------------------------------------------------------------------------------
# Let's see what's in these sets...
# sec_use, sec_e, sec_ff, sec_co2
seds_set[:ff] = ["oil","col","gas"]

set_lst = sort(collect(keys(seds_set)))
set_df = [DataFrame([v fill(true, size(v))], [:code, k]) for (k,v) in seds_set]
# [set_df[!,ii] .= convert_type.(Bool, set_df[:,ii]) for ii in 2:size(set_df,2)]
# set_df = indexjoin()
sort!(select!(set_df, [:code; set_lst]), set_lst)

# ------------------------------------------------------------------------------------------
# ELEGEN
# r = "co"
# yr = 2016
# 
# This was added to crosswalk/seds_src.
# df_map = DataFrame(
#     src = ["col","gas","oil","nu","hy","ge","so","wy"],
#     source_code = ["CL","NG","PA","NU","HY","GE","SO","WY"],
#     sector_code = [fill("EI", (3,1)); fill("EG", (5,1))][:,1],
#     units = [fill("billion btu", (3,1)); fill("million kilowatthours", (5,1))][:,1])

k = :elegen
d[k] = read_file(joinpath("..","forked","SLiDEData","data","input_1.0","elegen.csv"))

select!(seds_out[k], [:yr,:r,:src,:value])
d[k] = filter_with(d[k], set; extrapolate = false)
seds_out[k] = filter_with(seds_out[k], set; extrapolate = false)

# 
function _mark_source(d::Dict, k::Symbol)
    return edit_with(d[k], Rename.(propertynames(d[k])[end-1:end],
        Symbol.(propertynames(d[k])[end-1:end], :_, k)))
end

# TODO --- or just map it for now by adding the extrapolation/filter option.
# Maybe a Filter type with the index and the file to read? Just year for now.
# Make a new function to handle this sort of thing. Put it with the editing.
# Call during run_yaml? Or during edit_with() method that takes y::Dict
# -- do the initial editing an then filter.
# 1. Merge indicator/valnames functionality. Automatically check: if there is only one
#       value column, rename it to the indicator. Otherwise, append column names.
# 2. Mark units column if it's there.
function _module_elegen!(d::Dict)
    # If there is only one type of units in the results df,
    # we don't need to edit because it has already been done.
    length(unique(d[:elegen],:units)) == 1 && (return d[:elegen])

    # (!!!!) Let's make this ALL part of the DATASTREAM process!
    # Map - add heatrate conversion (units from -> to for easier mapping)
    # Replace - missing factor -> 1
    # Operate - divide
    # 
    # WHAT ABOUT THE YEAR EXTRAPOLATION???
    # WHEN SHOULD WE EXTRAPOLATE? PROBABLY IN DATASTREAM FOR ALL YEARS, RIGHT?
    # ADD filter = true/extrapolate = true flag for years that should be most of the years.
    #   This means year set must already be defined. Maybe from bea??
    #   We only really extrapolate backward.
    # 
    # (NOT only 2012; only 2007,2012, something like that.)
    x = Map("../input/heatrate.csv",
        [:yr,:src], [:units,:value], [:yr,:src], [:units_heatrate, :heatrate], :left)

    df1 = _mark_source(d,:elegen)
    df2 = _mark_source(d,:heatrate)

    idx = findindex(df1)
    df = indexjoin(df1,df2; valnames = [:elegen,:heatrate], fillmissing = 1.0)
    df[!,:value] .= df[:,:elegen] ./ df[:,:heatrate]
    df = df[:,[idx;:value]]

    d[:elegen] = edit_with(df, [Rename(:units_elegen, :elegen),
        Replace(:elegen,"billion btu","billion kilowatthours")])
    return dropmissing!(d[:elegen])
end

# ------------------------------------------------------------------------------------------
# SEDSENERGY <-> ENERGY DATA

# ------------------------------------------------------------------------------------------
# CO2EMIS
# Do by reading multiple files. And mapping if we can get away with doing that for only one?
# (I think we can!) The calculation we REALLY want relies on energydata.
# 

# Unit conversions:
#   - billion btu -> trillion btu
#   - million kWh -> billion kWh