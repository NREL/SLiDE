using CSV
using DataFrames
using DelimitedFiles
using YAML
using Query

using SLiDE

READ_DIR = joinpath("data", "readfiles");
# include(joinpath(SLIDE_DIR, "dev", "buildstream", "build_functions.jl"))
# include(joinpath(SLIDE_DIR, "dev", "buildstream", "share_check.jl"))

# ******************************************************************************************
#   READ SHARING DATA.
# ******************************************************************************************
# Read sharing files and do some preliminary editing.
files_share = XLSXInput("generate_yaml.xlsx", "share", "B1:G150", "share")
files_share = write_yaml(READ_DIR, files_share)

y = [read_file(files_share[ii]) for ii in 1:length(files_share)]
files_share = run_yaml(files_share)

shr = Dict(Symbol(y[ii]["PathOut"][end][1:end-4]) =>
    read_file(joinpath(y[ii]["PathOut"]...)) for ii in 1:length(y))

shr[:pce] = sort(filter_with(shr[:pce], set))
shr[:utd] = sort(filter_with(shr[:utd], set))
shr[:gsp] = sort(filter_with(shr[:gsp], set))
shr[:cfs] = sort(filter_with(shr[:cfs], set))

# ******************************************************************************************
# "`pce`: Regional shares of final consumption"
shr[:pce][!,:value] .= shr[:pce][:,:value] ./ sum_over(shr[:pce], :r; keepkeys = true)

# ******************************************************************************************
# "`utd`: Share of total trade by region."
shr[:utd][!,:share] .= shr[:utd][:,:value] ./ sum_over(shr[:utd], :r; keepkeys = true)
shr[:utd][isnan.(shr[:utd][:,:share]),:share] .= (sum_over(shr[:utd], :yr; keepkeys = true) ./
    sum_over(shr[:utd], [:yr,:r]; keepkeys = true))[isnan.(shr[:utd][:,:share])]
shr[:utd] = shr[:utd][.!isnan.(shr[:utd][:,:share]),:]

# "`notrd`: Sectors not included in USA Trade Data."
# shr[:notinc] = DataFrame(s = setdiff(set[:i], shr[:utd][:,:s]))
set[:notrd] = setdiff(set[:i], shr[:utd][:,:s])

# ******************************************************************************************
# # "`gsp`: Calculated gross state product."
# Calcuate GSP and save difference between calculate value and data.
shr[:gsp] = unstack(edit_with(dropzero(shr[:gsp]), Drop(:units,"all","==")), :gdpcat, :value)
shr[:gsp] = edit_with(shr[:gsp], Replace.(Symbol.(set[:gdpcat]),missing,0.0))

shr[:gsp][!,:calc] = shr[:gsp][:,:cmp] + shr[:gsp][:,:gos] + shr[:gsp][:,:taxsbd]
shr[:gsp][!,:diff] = shr[:gsp][:,:calc] - shr[:gsp][:,:gdp]

# "`region`: Regional share of value added"
shr[:region] = edit_with(copy(shr[:gsp][:,[:yr,:r,:s,:gdp]]), Rename(:gdp,:value))
shr[:region][!,:share] .= shr[:region][:,:value] ./ sum_over(shr[:region], :r; keepkeys = true)

temp = Dict()

# Let the used and scrap sectors be an average of other sectors.
# These are the only sectors that have NaN values.
temp[:region] = copy(shr[:region][.!isnan.(shr[:region][:,:share]), [:yr,:r,:s,:share]])
[global shr[:region][shr[:region][:,:s] .== ss, :share] = sum_over(temp[:region], :s) ./
        sum_over(sum_over(temp[:region], :r; keepkeys = true, values_only = false), :s)
    for ss in ["use", "oth"]]

# "`netval`: Factor totals" (units = billion USD)
shr[:netval] = DataFrame(permute((yr = set[:yr], r = set[:r], s = set[:s])))
shr[:netval][!,:sudo] .= shr[:gsp][:,:gdp] - shr[:gsp][:,:taxsbd]
shr[:netval][!,:comp] .= shr[:gsp][:,:cmp] + shr[:gsp][:,:gos]

# "`labor`: Labor share"
# !!** Potential future update might be to define labor component of value added
# demand using region average for stability purposes. i.e. find labor shares that
# match US average but allow for distribution in GSP data.
# shr[:gsp] = fill_zero((yr = set[:yr], r = set[:r], s = set[:s]), shr[:gsp])
# shr[:netval] = fill_zero((yr = set[:yr], r = set[:r], s = set[:s]), shr[:netval])
shr[:labor] = edit_with(fill_zero((yr = set[:yr], r = set[:r], g = set[:g])),
    Rename(:value, :share))

ii = shr[:netval][:,:comp] .!= 0.0
shr[:labor][ii,:share] = shr[:gsp][ii,:cmp] ./ shr[:netval][ii,:comp]

#! In cases where the labor share is zero (e.g. banking and finance), use national average.
# First, join the national average from the BEA Supply/Use data, defined when partitioning
# the BEA data. Find indices to replace, do so, and delete the IO column.
shr[:labor] = innerjoin(shr[:labor], edit_with(io[:lshr0], Rename(:value,:io)),
    on = Pair.([:yr,:g], [:yr,:g]))
ii = .&(shr[:labor][:,:share] .== 0.0, shr[:region][:,:share] .> 0.0)
shr[:labor][ii, :share] .= shr[:labor][ii, :io]
##!! Could include comparelshr here
# shr[:labor] = edit_with(shr[:labor], Drop(:io,"all","=="))

# `wg`: Index pairs with high wage shares
# Pick out (year,region,sector) pairings with wage shares greater than 1.
wg = shr[:labor][:,:share] .> 1
shr[:labor][!,:wg] .= wg

# `hw`: Regions with all years of high wage shares
# Pick out (region,sector) pairings with ALL wage shares greater than 1.
# Do this by multiplying the boolean over all years. If any values are false, all will be false.
df_temp = edit_with(by(shr[:labor], [:r,:g], :wg => prod), Rename(:wg_prod, :hw))
shr[:labor] = innerjoin(shr[:labor], df_temp, on = [:r,:g])
hw = shr[:labor][:,:hw]

# ////begin WiNDC weirdness -- this includes high-wage (r,g) AND (r,g) that are all zeros
# shr[:labor][!,:zero] .= shr[:labor][:,:share] .== 0
# df_temp = by(shr[:labor], [:r,:g], :wg => prod)
# df_temp[!,:zero_prod] = by(shr[:labor], [:r,:g], :zero => prod)[:,:zero_prod]
# df_temp[!,:hw] = Bool.(df_temp[:,:wg_prod] .+ df_temp[:,:zero_prod])
# shr[:labor] = innerjoin(shr[:labor], df_temp[:,[:r,:g,:hw]], on = [:r,:g])
# ////end WiNDC weirdness.

# Sector-level average labor shares.
# ////begin example
# df = shr[:labor][.&(shr[:labor][:,:r] .== "md", shr[:labor][:,:g] .== "eec"),:]
# df[!,:not_wg] .= convert_type.(Float64, .!df[:,:wg])
# df[!,:avg_wg] .= df[:,:share] .* df[:,:not_wg]
# df[!,:avg_wg] .= sum_over(df[:,[:yr,:r,:g,:avg_wg]], :yr; keepkeys = true) ./
#     sum_over(df[:,[:yr,:r,:g,:not_wg]], :yr; keepkeys = true)
# ////end example
shr[:labor][!,:not_wg] .= convert_type.(Float64, .!shr[:labor][:,:wg])
shr[:labor][!,:avg_wg] .= shr[:labor][:,:share] .* shr[:labor][:,:not_wg]
shr[:labor][!,:sec_labor] .= shr[:labor][:,:share] .* shr[:labor][:,:not_wg]

shr[:labor][!,:avg_wg] .= sum_over(shr[:labor][:,[:yr,:r,:g,:avg_wg]], :yr; keepkeys = true) ./
    sum_over(shr[:labor][:,[:yr,:r,:g,:not_wg]], :yr; keepkeys = true)
shr[:labor][!,:sec_labor] .= sum_over(shr[:labor][:,[:yr,:r,:g,:sec_labor]], :r; keepkeys = true) ./
    sum_over(shr[:labor][:,[:yr,:r,:g,:not_wg]], :r; keepkeys = true)

shr[:labor][wg,:share] .= shr[:labor][wg,:avg_wg]
shr[:labor][hw,:share] .= shr[:labor][hw,:sec_labor]

# ******************************************************************************************
# CFS
# `ng`: Sectors not included in the CFS.
# Could also do boolean first and then product to find where all are zero.
# shr[:ng] = by(shr[:cfs], [:g], :value => sum)
shr[:cfs][!,:ng] = sum_over(shr[:cfs], [:orig_state, :dest_state]; keepkeys = true)
shr[:cfs][!,:ng] = shr[:cfs][!,:ng] .== 0.0
shr[:cfs][!,:not_ng] .= .!shr[:cfs][:,:ng]

# `d0`: Local supply-demand. Trade that remains within the same region.
shr[:d0] = shr[:cfs][shr[:cfs][:,:orig_state] .== shr[:cfs][:,:dest_state],:]
shr[:d0] = sort(edit_with(shr[:d0], Rename(:orig_state,:r))[:,[:r,:g,:units,:value,:ng,:not_ng]])

# `mrt0`: Interstate trade (CFS)
shr[:mrt0] = shr[:cfs][shr[:cfs][:,:orig_state] .!= shr[:cfs][:,:dest_state],:]

# `xn0`: National exports (CFS)
shr[:xn0] = sum_over(copy(shr[:mrt0]), :dest_state; values_only = false)
shr[:xn0] = sort(edit_with(shr[:xn0], Rename(:orig_state, :r)))

# `mn0`: National demand (CFS)
shr[:mn0] = sum_over(copy(shr[:mrt0]), :orig_state; values_only = false)
shr[:mn0] = sort(edit_with(shr[:mn0], Rename(:dest_state, :r)))

# Change types for averaging.... We can't do this before with CFS data or it will mess
# things up when we use sum_over to find d0, mrt0, xn0, mn0.
shr[:d0][!,:not_ng] = convert_type.(Float64, shr[:d0][:,:not_ng])
shr[:xn0][!,:not_ng] = convert_type.(Float64, shr[:xn0][:,:not_ng])
shr[:mn0][!,:not_ng] = convert_type.(Float64, shr[:mn0][:,:not_ng])

# 
shr[:d0][!,:value_avg] .= sum_over(shr[:d0][:,[:r,:g,:value]], :g; keepkeys = true) ./
    sum_over(shr[:d0][:,[:r,:g,:not_ng]], :g; keepkeys = true)
shr[:xn0][!,:value_avg] .= sum_over(shr[:xn0][:,[:r,:g,:value]], :g; keepkeys = true) ./
    sum_over(shr[:xn0][:,[:r,:g,:not_ng]], :g; keepkeys = true)
shr[:mn0][!,:value_avg] .= sum_over(shr[:mn0][:,[:r,:g,:value]], :g; keepkeys = true) ./
    sum_over(shr[:mn0][:,[:r,:g,:not_ng]], :g; keepkeys = true)

shr[:d0][shr[:d0][:,:ng],:value] .= shr[:d0][shr[:d0][:,:ng],:value_avg]
shr[:xn0][shr[:xn0][:,:ng],:value] .= shr[:xn0][shr[:xn0][:,:ng],:value_avg]
shr[:mn0][shr[:mn0][:,:ng],:value] .= shr[:mn0][shr[:mn0][:,:ng],:value_avg]

# `rpc`: Regional purchase coefficient
ii = (shr[:mn0][:,:value] + shr[:d0][:,:value]) .!= 0.0
shr[:rpc] = shr[:d0][:,[:r,:g,:value]]
shr[:rpc][ii,:value] ./= (shr[:mn0][ii,:value] + shr[:d0][ii,:value])

shr[:rpc][shr[:rpc][:,:g] .== "uti",:value] .= 0.9

# ******************************************************************************************
# `sgf`: State Government Finance data.
# D.C. is not included in the original data set, so assume its SGFs equal Maryland's.
df_md = copy(shr[:sgf][shr[:sgf][:,:r] .== "md", :])
shr[:sgf] = [shr[:sgf]; edit_with(df_md, Replace(:r, "md", "dc"))]

# Filtering/sorting after adding DC because sorting's expensive.
# Will eventually build extrapolating year/region into filter_with.
shr[:sgf] = sort(filter_with(shr[:sgf], set))

shr[:sgf][!,:share] .= shr[:sgf][:,:value] ./ sum_over(shr[:sgf], :r; keepkeys = true);

# !!** For years: 1998, 2007, 2008, 2009, 2010, 2011, no government
# !!** administration data is listed. In these cases, use all public
# !!** expenditures (police, etc.).
# !!** sgf_shr(yr,i,g)$(sum(i.local, sgf_shr(yr,i,g)) = 0) = sgf_shr(yr,i,'fdd');
# !!!! I checked the sgf_shr BEFORE this line of code, and all shares already sum to 1.
# If this is an issue in other places, here's how I would address it:
ii = isnan.(shr[:sgf][:,:share])
if sum(ii) > 0
    println("Replacing zero sums with final demand.")
    df_fdd = edit_with(shr[:sgf][shr[:sgf][:,:g] .== "fdd",:], Rename(:share,:fdd))[:,[:yr,:r,:fdd]]
    shr[:sgf] = innerjoin(shr[:sgf], df_fdd, on = [:yr,:r])
    
    shr[:sgf][ii,:share] .= shr[:sgf][ii,:fdd]
end


# Save the right columns.
ind = [collect(keys(set)); :t]
for (k,df) in shr    
    cols = propertynames(df)

    global shr[k] = if :share in cols
        edit_with(df[:, intersect(cols, [ind; :share])], Rename(:share, :value))
    elseif :value in cols
        df[:, intersect(cols, [ind; :value])]
    else
        df
    end
end