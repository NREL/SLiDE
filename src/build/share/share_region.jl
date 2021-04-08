"""
    share!(d::Dict, set::Dict; save_build = true, overwrite = false)

# Arguments
- `d::Dict` of DataFrames containing the model data.
- `set::Dict` of Arrays describing region, sector, final demand, etc.

# Keywords
- `save_build = true`
- `overwrite = false`
See [`SLiDE.build`](@ref) for keyword argument descriptions.

# Returns
- `d::Dict` of DataFrames containing the model data at the sharing step.
"""
function share_region(dataset::Dataset, d::Dict, set::Dict)
    step = "share"
    d_read = read_build(set!(dataset; step=step))

    if dataset.step=="input"
        [d_read[k] = filter_with(df, set; extrapolate=true) for (k,df) in d_read]
        merge!(d, d_read)
        
        # Add CFS regional sets for filtering.
        [set[k] = set[:r] for k in [:orig,:dest]]

        SLiDE.share_pce!(d)
        SLiDE.share_sgf!(d)
        SLiDE.share_utd!(d, set)
        SLiDE.share_region!(d, set)
        SLiDE.share_labor!(d, set)
        SLiDE.share_rpc!(d, set)

        SLiDE.write_build!(set!(dataset; step=step), copy(d))
        # SLiDE.write_build!(set!(dataset; step=SET_DIR), Dict(k => set[k] for k in [:notrd,:ng]))
        return d, set
    else
        return merge!(d, d_read), set
    end
end