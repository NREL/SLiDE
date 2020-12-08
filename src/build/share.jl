"""
    share!(d::Dict, set::Dict; save_build = true, overwrite = false)

# Arguments
- `d::Dict` of DataFrames containing the model data.
- `set::Dict` of Arrays describing region, sector, final demand, etc.

# Keywords
- `save_build = true`
- `overwrite = false`
See [`SLiDE.build_data`](@ref) for keyword argument descriptions.

# Returns
- `d::Dict` of DataFrames containing the model data at the sharing step.
"""
function share(
    dataset::String,
    d::Dict,
    set::Dict;
    save_build::Bool = DEFAULT_SAVE_BUILD,
    overwrite::Bool = DEFAULT_OVERWRITE
    )
    CURR_STEP = "share"
    STEP_INP = CURR_STEP * "_i"

    # If there is already sharing data, read it and return.
    d_read = read_build(dataset, CURR_STEP; overwrite = overwrite)
    !(isempty(d_read)) && (return d_read, set)

    # Read sharing input data.
    d_read = read_build(dataset, STEP_INP; overwrite = overwrite)
    if isempty(d_read)
        y = read_from(joinpath("src","readfiles","build","shareinp.yml"))
        # Here, we're not using read yaml/run yaml because the location we're saving in
        # depends on the "save" path specified in this function input.
        [set[k] = set[:r] for k in [:orig,:dest]]
        d_read = Dict(k => edit_with(v) for (k,v) in y)
        d_read = Dict(k => sort(filter_with(df, set; extrapolate = true)) for (k, df) in d_read)
        write_build!(dataset, STEP_INP, d_read; save_build = save_build)
    end
    
    merge!(d, d_read)

    share_pce!(d)
    share_sgf!(d)
    share_utd!(d, set)
    share_region!(d, set)
    share_labor!(d, set)
    share_rpc!(d, set)
    
    write_build!(dataset, CURR_STEP, d; save_build = save_build)
    write_build!(dataset, SET_DIR, Dict(k => set[k] for k in [:notrd,:ng]))

    return (d, set)
end