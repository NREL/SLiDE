<<<<<<< HEAD
using CSV
using DataFrames
using DelimitedFiles
using YAML
using Query

=======
>>>>>>> origin/dev
"""
    share_utd!(d::Dict, set::Dict)
`utd`: Share of total trade by region.
"""
function share_utd!(d::Dict, set::Dict)
    println("  Calculating share of total trade by region")
    d[:utd] = fill_zero(d[:utd])
    df = d[:utd] / transform_over(d[:utd], :r)

    df_yr = transform_over(d[:utd], :yr) / transform_over(d[:utd], [:yr,:r])
    df[isnan.(df[:,:value]), :value] .= df_yr[isnan.(df[:,:value]),:value]

    # Check import and export shares.
    verify_over(filter_with(df, (t = "imports",)), :r) !== true && @error("Import shares don't sum to 1.")
    verify_over(filter_with(df, (t = "exports",)), :r) !== true && @error("Export shares don't sum to 1.")
    
    d[:utd] = dropnan(dropzero(df))
    set[:notrd] = setdiff(set[:s], d[:utd][:,:s])
end