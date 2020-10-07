using CSV
using DataFrames
using DelimitedFiles
using YAML
using Query

using Base

function share!(d::Dict, set::Dict; save = true, overwrite = false)

    # If there is already sharing data, read it and return.
    d_read = read_build("share"; save = save, overwrite = overwrite);
    if !isempty(d_read)
        [d[k] = v for (k,v) in d_read]
        set[:notrd] = setdiff(set[:s], d[:utd][:,:s])
        return d
    end

    # READ SHARING DATA.
    d_read = read_build("share_i"; save = save, overwrite = overwrite);
    if isempty(d_read)
        y = read_from(joinpath("src","readfiles","build","shareinp.yml"))
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