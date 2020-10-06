using CSV
using DataFrames
using DelimitedFiles
using YAML
using Query

using SLiDE

"""
    share_labor!(d::Dict, set::Dict)
"""
function share_labor!(d::Dict, set::Dict)
    println("  Calculating labor share")
    !(:region in collect(keys(d))) && share_region!(d, set)
    _share_lshr0!(d, set)

    cols = [:yr,:r,:s,:value]
    df = copy(d[:gsp])
    df[!,:value] .= df[:,:cmp] ./ df[:,:comp]
    df = dropnan(df[:,cols])

    df = SLiDE._join_to_operate(df, d[:region], d[:lshr0])
    df = edit_with(df, Rename.([:x1,:x2,:x3], [:value,:region,:lshr0]))

    # Use the national average labor share (calculated when partitioning)
    # in cases where the labor share is zero (e.g. banking, finance, etc.).
    ii = .&(df[:,:value] .== 0.0, df[:,:region] .> 0.0)
    df[ii,:value] .= df[ii,:lshr0]
    df = fill_zero(df)

    # Save labor to input in functions to calculate annual and regional average wage shares.
    d[:labor] = df[:,cols]
    d[:labor_temp] = copy(d[:labor])

    df[!,:wg] .= _share_wg!(d, set)[:,:value]
    df[!,:hw] .= _share_hw!(d, set)[:,:value]
    df[!,:avg_wg] = _share_avg_wg!(d)[:,:value]
    df[!,:sec_labor] = _share_sec_labor!(d)[:,:value]

    df[!,:labor_temp] .= df[:,:value]

    wg = .&(df[:,:wg], df[:,:avg_wg] .!== 0.0)
    df[wg,:value] .= df[wg,:avg_wg]
    df[df[:,:hw],:value] .= df[df[:,:hw],:sec_labor]
    d[:labor] = dropnan(df[:,cols])
    d[:labor_calc] = df
end

"""
    share_region!(d::Dict, set::Dict)
`region`: Regional share of value added
"""
function share_region!(d::Dict, set::Dict)
    println("  Calculating regional share of value added")
    :gdpcat in propertynames(d[:gsp]) && _share_gsp!(d, set)

    cols = [:yr,:r,:s,:value]
    df = edit_with(copy(d[:gsp]), Rename(:gdp,:value))[:,cols]
    df = df / transform_over(df, :r)

    # Let the used and scrap sectors be an average of other sectors.
    # These are the only sectors that have NaN values.
    df = df[.!isnan.(df[:,:value]),:]
    df_s  = combine_over(df, :s)
    df_s /= transform_over(df_s, :r)

    df_s = crossjoin(DataFrame(s = set[:oth,:use]), df_s)

    d[:region] = dropnan(dropmissing(sort([df; df_s])))
    verify_over(d[:region],:r) !== true && @error("Regional shares don't sum to 1.")
    return d[:region]
end

"`gsp`: Calculated gross state product."
function _share_gsp!(d::Dict, set::Dict)
    df = copy(d[:gsp])
    :gdpcat in propertynames(d[:gsp]) && (df = unstack(dropzero(d[:gsp]), :gdpcat, :value))
    
    # df = edit_with(df, Replace.(Symbol.(set[:gdpcat]),missing,0.0))
    df = edit_with(df, Replace.(find_oftype(df, AbstractFloat), missing, 0.0))

    df[!,:sudo] .= df[:,:gdp] - df[:,:taxsbd]
    df[!,:comp] .= df[:,:cmp] + df[:,:gos]

    df[!,:calc] .= df[:,:cmp] + df[:,:gos] + df[:,:taxsbd]
    df[!,:diff] .= df[:,:calc] - df[:,:gdp]

    d[:gsp] = df
end

"`lshr0`: Labor share of value added"
function _share_lshr0!(d::Dict, set::Dict)
    va0 = edit_with(unstack(copy(d[:va0]), :va, :value),
        [Replace.(Symbol.(set[:va]), missing, 0.0); Drop(:units,"all","==")])
    
    d[:lshr0]  = va0[:,[:yr,:s,:compen]]
    d[:lshr0] /= (va0[:,[:yr,:s,:compen]] + va0[:,[:yr,:s,:surplus]])

    # !!!!! _partition_lshr0 needs to come after calibration.
    # Order is: io, calibrate, share, disagg.
    d[:lshr0][va0[:,:surplus] .< 0,:value] .= 1.0
    dropmissing!(d[:lshr0])
end

# " `netval`: Factor totals"
# function _share_netval!(d::Dict)
#     cols = [:yr,:r,:s,:sudo,:comp]
#     df = copy(d[:gsp])
#     df[!,:sudo] .= df[:,:gdp] - df[:,:taxsbd]
#     df[!,:comp] .= df[:,:cmp] + df[:,:gos]
#     d[:netval] = df[:,cols]
# end

"`wg(yr,r,s)`: Index pairs with high wage shares (>1)"
function _share_wg!(d::Dict, set::Dict)
    d[:wg] = copy(d[:labor])
    d[:wg][!,:value] .= d[:wg][:,:value] .> 1
    set[:wg] = values.(eachrow(d[:wg][d[:wg][:,:value], find_oftype(d[:wg],Not(Bool))]))
    return d[:wg] # must return the DataFrame
end

"`hw(r,s)`: (region,sector) pairings with ALL wage shares > 1"
function _share_hw!(d::Dict, set::Dict)
    !(:wg in collect(keys(d))) && _share_wg!(d, set)

    df = copy(d[:wg])
    d[:hw] = combine_over(df, :yr; fun = prod)
    set[:hw] = values.(eachrow(d[:hw][d[:hw][:,:value], find_oftype(d[:hw],String)]))
    return transform_over(df, :yr; fun = prod) # must return the DataFrame
end

function _share_avg_wg!(d::Dict)
    # Here, WiNDC uses .!wg, which DOES include labor = 1.
    !(:wg in collect(keys(d))) && _share_wg!(d, set)
    not_wg = edit_with(copy(d[:wg]), Replace(:value,Bool,Not))
    
    df = copy(d[:labor]) * not_wg
    d[:avg_wg] = edit_with(combine_over(df, :yr) / combine_over(not_wg, :yr), Replace(:value,NaN,0.0))
    return edit_with(transform_over(df, :yr) / transform_over(not_wg, :yr), Replace(:value,NaN,0.0))
end

function _share_sec_labor!(d::Dict)
    # Cannot use .!wg because this will include labor = 1.
    not_wg = copy(d[:labor])
    not_wg[!,:value] .= not_wg[:,:value] .< 1
    
    df = copy(d[:labor]) * not_wg
    d[:sec_labor] = combine_over(df, :r) / combine_over(not_wg, :r)
    return transform_over(df, :r) / transform_over(not_wg, :r)
end