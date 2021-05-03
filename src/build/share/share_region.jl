"""
    share_region(d::Dict, set::Dict; save_build = true, overwrite = false)
This function partitions BEA and Census Bureau data to use when disaggregating parameters
from the national- to regional-level.

# Arguments
- `dataset::Dataset` identifier
- `d::Dict` of model parameters
- `set::Dict` of Arrays describing parameter indices (years, regions, goods, sectors, etc.)

# Returns
- `d::Dict` of model parameters
- `set::Dict` of Arrays describing parameter indices (years, regions, goods, sectors, etc.)
"""
function share_region(dataset::Dataset, d::Dict, set::Dict)
    step = "share"
    d_read = read_build(set!(dataset; step=step))

    if dataset.step=="input"
        print_status(set!(dataset; step=step))
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