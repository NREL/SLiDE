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
function share(
    dataset::String,
    d::Dict,
    set::Dict;
    save_build::Bool=DEFAULT_SAVE_BUILD,
    overwrite::Bool=DEFAULT_OVERWRITE,
)
    CURR_STEP = "share"

    # If there is already sharing data, read it and return.
    d_read = read_build(dataset, CURR_STEP; overwrite=overwrite)
    !(isempty(d_read)) && (return d_read, set)

    # Add CFS regional sets for filtering.
    [set[k] = set[:r] for k in [:orig,:dest]]
    
    # Read sharing input data.
    d_read = read_from(joinpath("src", "build", "readfiles", "input", "share.yml"))
    d_read = Dict(k => sort(dropmissing(edit_with(
        filter_with(df, set; extrapolate=true),
        Deselect([:units], "==")
    ))) for (k, df) in d_read)

    merge!(d, d_read)
    
    share_pce!(d)
    share_sgf!(d)
    share_utd!(d, set)
    share_region!(d, set)
    share_labor!(d, set)
    share_rpc!(d, set)
    
    write_build!(dataset, CURR_STEP, d; save_build=save_build)
    write_build!(dataset, SET_DIR, Dict(k => set[k] for k in [:notrd,:ng]))

    return (d, set)
end