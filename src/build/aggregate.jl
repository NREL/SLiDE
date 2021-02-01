function aggregate_sector!(
    d::Dict;
    scheme=:disagg=>:aggr,
    path = joinpath(SLIDE_DIR,"data","coremaps","scale","sector","eem_pmt.csv"),
)
    (from,to) = (scheme[1], scheme[2])
    dfmap = read_file(path)[:,[from,to]]

    taxes = [:ta0,:tm0,:ty0, :a0,:m0,:ys0]

    _aggregate_tax_with!(d, dfmap, :ta0, :a0)
    _aggregate_tax_with!(d, dfmap, :tm0, :m0)
    _aggregate_tax_with!(d, dfmap, :ty0, :ys0)

    _aggregate_sector_map!(d, dfmap, setdiff(keys(d), [taxes;:sector]); scheme=scheme)

    return d
end


"""
"""
function _aggregate_sector_map(
    df::DataFrame,
    dfmap::DataFrame;
    scheme=:summary=>:disagg,
    key=missing,
)
    df = _disagg_sector_map(df, dfmap; scheme=scheme, key=key)
    df = combine_over(df, :dummy; digits=false)
    return df
end


"""
"""
function _aggregate_sector_map!(d::Dict, dfmap, parameters; scheme=:disagg=>:aggr)
    [d[k] = _aggregate_sector_map(d[k], dfmap; scheme=scheme, key=k)
        for k in parameters]
    return d
end


"""
"""
function _aggregate_tax_with!(d::Dict, dfmap, kt, k; scheme=:disagg=>:aggr)
    sector = setdiff(propertynames(d[k]), propertynames(d[kt]))

    d[kt] = d[kt] * combine_over(d[k], sector)
    _aggregate_sector_map!(d, dfmap, [kt,k]; scheme=scheme)
    d[kt] = d[kt] / combine_over(d[k], sector)

    return dropzero!(dropnan!(d[kt])), d[k]
end


# function _aggregate_ta0_a0!(d::Dict, dfmap; scheme=:disagg=>:aggr)
#     d[:ta0] = d[:ta0] * d[:a0]
#     _aggregate_sector_map!(d, dfmap, [:ta0,k]; scheme=scheme)
#     d[:ta0] = d[:ta0] / d[:a0]

#     return dropzero!(dropnan!(d[:ta0])), d[:a0]
# end

# function _aggregate_tm0_m0!(d::Dict, dfmap; scheme=:disagg=>:aggr)
#     d[:tm0] = d[:tm0] * d[:m0]
#     _aggregate_sector_map!(d, dfmap, [:tm0,k]; scheme=scheme)
#     d[:tm0] = d[:tm0] / d[:m0]

#     return dropzero!(dropnan!(d[:tm0])), d[:m0]
# end

# function _aggregate_ty0_ys0!(d::Dict, dfmap; scheme=:disagg=>:aggr)
#     d[:ty0] = d[:ty0] * combine_over(d[:ys0], :g)
#     _aggregate_sector_map!(d, dfmap, [:ty0,k]; scheme=scheme)
#     d[:ty0] = d[:ty0] / combine_over(d[:ys0], :g)

#     return dropzero!(dropnan!(d[:ty0])), d[:ys0]
# end