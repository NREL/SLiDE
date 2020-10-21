"""
    share!(d::Dict, set::Dict; save = true, overwrite = false)

# Arguments
- `d::Dict` of DataFrames containing the model data.
- `set::Dict` of Arrays describing region, sector, final demand, etc.

# Keywords
- `save = true`
- `overwrite = false`
See [`SLiDE.build_data`](@ref) for keyword argument descriptions.

# Returns
- `d::Dict` of DataFrames containing the model data at the sharing step.
"""
function share!(d::Dict, set::Dict; save = true, overwrite = false)

    # If there is already sharing data, read it and return.
    d_read = read_build("share"; save = save, overwrite = overwrite);
    if !isempty(d_read)
        [d[k] = v for (k,v) in d_read]
        set[:notrd] = _share_notrd!(d, set)
        return d
    end

    # READ SHARING DATA.
    d_read = read_build("share_i"; save = save, overwrite = overwrite);
    if isempty(d_read)
        y = read_from(joinpath("src","readfiles","build","shareinp.yml"))
        # Here, we're not using read yaml/run yaml because the location we're saving in
        # depends on the "save" path specified in this function input.
        d_read = Dict(k => edit_with(v) for (k,v) in y)
        d_read = Dict(k => sort(filter_with(df, set; extrapolate = true)) for (k, df) in d_read)

        write_build("share_i", d_read; save = save)
    end
    [d[k] = v for (k,v) in d_read]

    # Do the sharing.
    share_pce!(d)
    share_sgf!(d)
    share_utd!(d, set)
    share_region!(d, set)
    share_labor!(d, set)
    share_rpc!(d, set)

    d_save = Dict(k => d[k] for k in [:gsp,:labor,:pce,:rpc,:region,:sgf,:utd])
    write_build("share", d_save; save = save)

    return d
end