"""
"""
function share_sector!(
    d::Dict;
    path::String=joinpath(SLIDE_DIR,"data","coremaps","scale","sector","bluenote.csv"),
)
    (from,to) = (:detail,:summary)

    df = copy(d[:y0])
    dfmap = read_file(path)
    
    df = edit_with(df, [
        Rename(:g, from);
        Map(dfmap,[from],[to],[from],[to],:left);
        Order([:yr,to,from,:value], [Int,String,String,Float64]);
    ])

    d[:sector] = df / combine_over(df,:detail)

    return d[:sector]
end


"""
"""
function aggregate_share!(
    d::Dict;
    scheme=:disagg=>:aggr,
    path = joinpath(SLIDE_DIR,"data","coremaps","scale","sector","eem.csv"),
)
    dfmap = read_file(path)

    d[:sector] = vcat(
        _share_summary(d, dfmap; scheme=scheme),
        _share_detail!(d, dfmap; scheme=scheme)
    )

    delete!(d, :sector_detail)
    return d[:sector]
end


"""
"""
function _share_detail!(d::Dict, dfmap::DataFrame; scheme=:disagg=>:aggr)
    k = :sector_detail
    
    if !haskey(d,k)
        (from,to) = (scheme[1], scheme[2])

        d[k] = edit_with(copy(d[:sector]), [
            Rename(:detail,from),
            Map(dfmap,[from],[to],[from],[to],:inner),
            Order([:yr,to,from,:summary,:value], [Int;fill(String,3);Float64]),
        ])
    end
    return d[k]
end


"""
"""
function _share_summary(d::Dict, dfmap::DataFrame; scheme=:disagg=>:aggr)
    (from,to) = (scheme[1],scheme[2])

    df_det = _share_detail!(d, dfmap; scheme=scheme)
    df = d[:sector]
    
    df_sum = fill_with(df[:,[:yr,:summary]], 1.0)
    df_sum = df_sum - combine_over(df_det, [from,to])

    df_sum = edit_with(df_sum, [
        Map(dfmap,[from],[from,to],[:summary],[from,to],:inner),
        Order([:yr,to,from,:summary,:value], [Int;fill(String,3);Float64]),
    ])

    return df_sum
end