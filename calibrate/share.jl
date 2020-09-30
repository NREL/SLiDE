using CSV
using DataFrames
using DelimitedFiles
using YAML
using Query

using SLiDE

READ_DIR = joinpath("data", "readfiles");
# include(joinpath(SLIDE_DIR, "dev", "buildstream", "share_check.jl"))

# ******************************************************************************************
#   READ SHARING DATA.
# ******************************************************************************************
# Read sharing files and do some preliminary editing.
# files_share = XLSXInput("generate_yaml.xlsx", "share", "B1:G150", "share")
# files_share = write_yaml(READ_DIR, files_share)

# y = [read_file(files_share[ii]) for ii in 1:length(files_share)]
# files_share = run_yaml(files_share)

# nshr = Dict(Symbol(y[ii]["PathOut"][end][1:end-4]) =>
#     read_file(joinpath(y[ii]["PathOut"]...)) for ii in 1:length(y))

# nshr[:pce] = sort(filter_with(nshr[:pce], set))
# nshr[:utd] = sort(filter_with(nshr[:utd], set))
# nshr[:gsp] = sort(filter_with(nshr[:gsp], set))
# nshr[:cfs] = sort(filter_with(nshr[:cfs], set))

# bshr[:utd] = edit_with(bshr[:utd], Rename(:g,:s))
# bshr[:pce] = edit_with(bshr[:pce], Rename(:s,:g))

"`pce`: Regional shares of final consumption"
function _share_pce!(d::Dict)
    d[:pce] /= transform_over(d[:pce], :r)
end

"`utd`: Share of total trade by region."
function _share_utd!(d::Dict, set::Dict)
    df = d[:utd] / transform_over(d[:utd], :r)

    df_yr = transform_over(d[:utd], :yr) / transform_over(d[:utd], [:yr,:r])
    df[isnan.(df[:,:value]),:value] .= df_yr[isnan.(df[:,:value]),:value]

    d[:utd] = dropmissing(df[.!isnan.(df[:,:value]),:])

    set[:notrd] = setdiff(set[:s], d[:utd][:,:s])
end

"`gsp`: Calculated gross state product."
function _share_gsp!(d::Dict, set::Dict)
    df = d[:gsp]
    :gdpcat in propertynames(d[:gsp]) && (df = unstack(dropzero(d[:gsp]), :gdpcat, :value))

    df = edit_with(df, Replace.(Symbol.(set[:gdpcat]),missing,0.0))

    # df[!,:sudo] .= df[:,:gdp] - df[:,:taxsbd]
    # df[!,:comp] .= df[:,:cmp] + df[:,:gos]

    df[!,:calc] .= df[:,:cmp] + df[:,:gos] + df[:,:taxsbd]
    df[!,:diff] .= df[:,:calc] - df[:,:gdp]

    d[:gsp] = df
end

"`region`: Regional share of value added"
function _share_region!(d::Dict, set::Dict)
    cols = [:yr,:r,:s,:value]
    df = if :gsp in propertynames(d[:gsp])
        filter_with(d[:gsp], (gdpcat = "gdp",))[:,cols]
    else
        edit_with(copy(d[:gsp]), Rename(:gdp,:value))[:,cols]
    end

    df = df / transform_over(df, :r)

    # Let the used and scrap sectors be an average of other sectors.
    # These are the only sectors that have NaN values.
    df = df[.!isnan.(df[:,:value]),:]
    df_s  = combine_over(df, :s)
    df_s /= transform_over(df_s, :r)

    df_s = crossjoin(DataFrame(s = set[:oth,:use]), df_s)[:,cols]

    d[:region] = dropmissing(sort([df; df_s]))
end

"`netval`: Factor totals"
function _share_netval!(d::Dict)
    cols = [:yr,:r,:s,:sudo,:comp]
    df = copy(d[:gsp])
    df[!,:sudo] .= df[:,:gdp] - df[:,:taxsbd]
    df[!,:comp] .= df[:,:cmp] + df[:,:gos]
    d[:netval] = df[:,cols]
end

d = Dict(k => edit_with(copy(nshr[k]), Drop(:units,"all","==")) for k in keys(nshr))
_share_pce!(d)
_share_utd!(d, set)
_share_gsp!(d, set)
_share_region!(d, set)
_share_netval!(d)

cols = [:yr,:r,:s,:labor]

df = d[:gsp][:,[:yr,:r,:s,:cmp]] / d[:netval][:,[:yr,:r,:s,:comp]]

SLiDE._join_to_operate(df, d[:region], io[:lshr0])



# # # ******************************************************************************************
# # # # "`gsp`: Calculated gross state product."
# # # Calcuate GSP and save difference between calculate value and data.

# # # "`netval`: Factor totals" (units = billion USD)
# # nshr[:netval] = DataFrame(permute((yr = set[:yr], r = set[:r], s = set[:s])))
# # nshr[:netval][!,:sudo] .= nshr[:gsp][:,:gdp] - nshr[:gsp][:,:taxsbd]
# # nshr[:netval][!,:comp] .= nshr[:gsp][:,:cmp] + nshr[:gsp][:,:gos]

# # # "`labor`: Labor share"
# # # !!** Potential future update might be to define labor component of value added
# # # demand using region average for stability purposes. i.e. find labor shares that
# # # match US average but allow for distribution in GSP data.
# # # nshr[:gsp] = fill_zero((yr = set[:yr], r = set[:r], s = set[:s]), nshr[:gsp])
# # # nshr[:netval] = fill_zero((yr = set[:yr], r = set[:r], s = set[:s]), nshr[:netval])
# # nshr[:labor] = edit_with(fill_zero((yr = set[:yr], r = set[:r], g = set[:g])),
# #     Rename(:value, :share))

# # ii = nshr[:netval][:,:comp] .!= 0.0
# # nshr[:labor][ii,:share] = nshr[:gsp][ii,:cmp] ./ nshr[:netval][ii,:comp]

# # #! In cases where the labor share is zero (e.g. banking and finance), use national average.
# # # First, join the national average from the BEA Supply/Use data, defined when partitioning
# # # the BEA data. Find indices to replace, do so, and delete the IO column.
# # nshr[:labor] = innerjoin(nshr[:labor], edit_with(io[:lnshr0], Rename(:value,:io)),
# #     on = Pair.([:yr,:g], [:yr,:g]))
# # ii = .&(nshr[:labor][:,:share] .== 0.0, nshr[:region][:,:share] .> 0.0)
# # nshr[:labor][ii, :share] .= nshr[:labor][ii, :io]
# # ##!! Could include comparelnshr here
# # # nshr[:labor] = edit_with(nshr[:labor], Drop(:io,"all","=="))

# # # `wg`: Index pairs with high wage shares
# # # Pick out (year,region,sector) pairings with wage shares greater than 1.
# # wg = nshr[:labor][:,:share] .> 1
# # nshr[:labor][!,:wg] .= wg

# # # `hw`: Regions with all years of high wage shares
# # # Pick out (region,sector) pairings with ALL wage shares greater than 1.
# # # Do this by multiplying the boolean over all years. If any values are false, all will be false.
# # df_temp = edit_with(by(nshr[:labor], [:r,:g], :wg => prod), Rename(:wg_prod, :hw))
# # nshr[:labor] = innerjoin(nshr[:labor], df_temp, on = [:r,:g])
# # hw = nshr[:labor][:,:hw]

# # # ////begin WiNDC weirdness -- this includes high-wage (r,g) AND (r,g) that are all zeros
# # # nshr[:labor][!,:zero] .= nshr[:labor][:,:share] .== 0
# # # df_temp = by(nshr[:labor], [:r,:g], :wg => prod)
# # # df_temp[!,:zero_prod] = by(nshr[:labor], [:r,:g], :zero => prod)[:,:zero_prod]
# # # df_temp[!,:hw] = Bool.(df_temp[:,:wg_prod] .+ df_temp[:,:zero_prod])
# # # nshr[:labor] = innerjoin(nshr[:labor], df_temp[:,[:r,:g,:hw]], on = [:r,:g])
# # # ////end WiNDC weirdness.

# # # Sector-level average labor shares.
# # # ////begin example
# # # df = nshr[:labor][.&(nshr[:labor][:,:r] .== "md", nshr[:labor][:,:g] .== "eec"),:]
# # # df[!,:not_wg] .= convert_type.(Float64, .!df[:,:wg])
# # # df[!,:avg_wg] .= df[:,:share] .* df[:,:not_wg]
# # # df[!,:avg_wg] .= sum_over(df[:,[:yr,:r,:g,:avg_wg]], :yr; keepkeys = true) ./
# # #     sum_over(df[:,[:yr,:r,:g,:not_wg]], :yr; keepkeys = true)
# # # ////end example
# # nshr[:labor][!,:not_wg] .= convert_type.(Float64, .!nshr[:labor][:,:wg])
# # nshr[:labor][!,:avg_wg] .= nshr[:labor][:,:share] .* nshr[:labor][:,:not_wg]
# # nshr[:labor][!,:sec_labor] .= nshr[:labor][:,:share] .* nshr[:labor][:,:not_wg]

# # nshr[:labor][!,:avg_wg] .= sum_over(nshr[:labor][:,[:yr,:r,:g,:avg_wg]], :yr; keepkeys = true) ./
# #     sum_over(nshr[:labor][:,[:yr,:r,:g,:not_wg]], :yr; keepkeys = true)
# # nshr[:labor][!,:sec_labor] .= sum_over(nshr[:labor][:,[:yr,:r,:g,:sec_labor]], :r; keepkeys = true) ./
# #     sum_over(nshr[:labor][:,[:yr,:r,:g,:not_wg]], :r; keepkeys = true)

# # nshr[:labor][wg,:share] .= nshr[:labor][wg,:avg_wg]
# # nshr[:labor][hw,:share] .= nshr[:labor][hw,:sec_labor]

# # # ******************************************************************************************
# # # CFS
# # # `ng`: Sectors not included in the CFS.
# # # Could also do boolean first and then product to find where all are zero.
# # # nshr[:ng] = by(nshr[:cfs], [:g], :value => sum)
# # nshr[:cfs][!,:ng] = sum_over(nshr[:cfs], [:orig_state, :dest_state]; keepkeys = true)
# # nshr[:cfs][!,:ng] = nshr[:cfs][!,:ng] .== 0.0
# # nshr[:cfs][!,:not_ng] .= .!nshr[:cfs][:,:ng]

# # # `d0`: Local supply-demand. Trade that remains within the same region.
# # nshr[:d0] = nshr[:cfs][nshr[:cfs][:,:orig_state] .== nshr[:cfs][:,:dest_state],:]
# # nshr[:d0] = sort(edit_with(nshr[:d0], Rename(:orig_state,:r))[:,[:r,:g,:units,:value,:ng,:not_ng]])

# # # `mrt0`: Interstate trade (CFS)
# # nshr[:mrt0] = nshr[:cfs][nshr[:cfs][:,:orig_state] .!= nshr[:cfs][:,:dest_state],:]

# # # `xn0`: National exports (CFS)
# # nshr[:xn0] = sum_over(copy(nshr[:mrt0]), :dest_state; values_only = false)
# # nshr[:xn0] = sort(edit_with(nshr[:xn0], Rename(:orig_state, :r)))

# # # `mn0`: National demand (CFS)
# # nshr[:mn0] = sum_over(copy(nshr[:mrt0]), :orig_state; values_only = false)
# # nshr[:mn0] = sort(edit_with(nshr[:mn0], Rename(:dest_state, :r)))

# # # Change types for averaging.... We can't do this before with CFS data or it will mess
# # # things up when we use sum_over to find d0, mrt0, xn0, mn0.
# # nshr[:d0][!,:not_ng] = convert_type.(Float64, nshr[:d0][:,:not_ng])
# # nshr[:xn0][!,:not_ng] = convert_type.(Float64, nshr[:xn0][:,:not_ng])
# # nshr[:mn0][!,:not_ng] = convert_type.(Float64, nshr[:mn0][:,:not_ng])

# # # 
# # nshr[:d0][!,:value_avg] .= sum_over(nshr[:d0][:,[:r,:g,:value]], :g; keepkeys = true) ./
# #     sum_over(nshr[:d0][:,[:r,:g,:not_ng]], :g; keepkeys = true)
# # nshr[:xn0][!,:value_avg] .= sum_over(nshr[:xn0][:,[:r,:g,:value]], :g; keepkeys = true) ./
# #     sum_over(nshr[:xn0][:,[:r,:g,:not_ng]], :g; keepkeys = true)
# # nshr[:mn0][!,:value_avg] .= sum_over(nshr[:mn0][:,[:r,:g,:value]], :g; keepkeys = true) ./
# #     sum_over(nshr[:mn0][:,[:r,:g,:not_ng]], :g; keepkeys = true)

# # nshr[:d0][nshr[:d0][:,:ng],:value] .= nshr[:d0][nshr[:d0][:,:ng],:value_avg]
# # nshr[:xn0][nshr[:xn0][:,:ng],:value] .= nshr[:xn0][nshr[:xn0][:,:ng],:value_avg]
# # nshr[:mn0][nshr[:mn0][:,:ng],:value] .= nshr[:mn0][nshr[:mn0][:,:ng],:value_avg]

# # # `rpc`: Regional purchase coefficient
# # ii = (nshr[:mn0][:,:value] + nshr[:d0][:,:value]) .!= 0.0
# # nshr[:rpc] = nshr[:d0][:,[:r,:g,:value]]
# # nshr[:rpc][ii,:value] ./= (nshr[:mn0][ii,:value] + nshr[:d0][ii,:value])

# # nshr[:rpc][nshr[:rpc][:,:g] .== "uti",:value] .= 0.9

# # # ******************************************************************************************
# # # `sgf`: State Government Finance data.
# # # D.C. is not included in the original data set, so assume its SGFs equal Maryland's.
# # df_md = copy(nshr[:sgf][nshr[:sgf][:,:r] .== "md", :])
# # nshr[:sgf] = [nshr[:sgf]; edit_with(df_md, Replace(:r, "md", "dc"))]

# # # Filtering/sorting after adding DC because sorting's expensive.
# # # Will eventually build extrapolating year/region into filter_with.
# # nshr[:sgf] = sort(filter_with(nshr[:sgf], set))

# # nshr[:sgf][!,:share] .= nshr[:sgf][:,:value] ./ sum_over(nshr[:sgf], :r; keepkeys = true);

# # # !!** For years: 1998, 2007, 2008, 2009, 2010, 2011, no government
# # # !!** administration data is listed. In these cases, use all public
# # # !!** expenditures (police, etc.).
# # # !!** sgf_nshr(yr,i,g)$(sum(i.local, sgf_nshr(yr,i,g)) = 0) = sgf_nshr(yr,i,'fdd');
# # # !!!! I checked the sgf_nshr BEFORE this line of code, and all shares already sum to 1.
# # # If this is an issue in other places, here's how I would address it:
# # ii = isnan.(nshr[:sgf][:,:share])
# # if sum(ii) > 0
# #     println("Replacing zero sums with final demand.")
# #     df_fdd = edit_with(nshr[:sgf][nshr[:sgf][:,:g] .== "fdd",:], Rename(:share,:fdd))[:,[:yr,:r,:fdd]]
# #     nshr[:sgf] = innerjoin(nshr[:sgf], df_fdd, on = [:yr,:r])
    
# #     nshr[:sgf][ii,:share] .= nshr[:sgf][ii,:fdd]
# # end


# # # Save the right columns.
# # ind = [collect(keys(set)); :t]
# # for (k,df) in nshr    
# #     cols = propertynames(df)

# #     global nshr[k] = if :share in cols
# #         edit_with(df[:, intersect(cols, [ind; :share])], Rename(:share, :value))
# #     elseif :value in cols
# #         df[:, intersect(cols, [ind; :value])]
# #     else
# #         df
# #     end
# # end