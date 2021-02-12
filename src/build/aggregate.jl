"""
    aggregate_sector!(dataset::String, d::Dict, set::Dict; kwargs...)
This function performs the sectoral aggregation for all of the model parameters.
- Taxes (``ta``, ``tm``, ``ty``) are aggregated using [`SLiDE._aggregate_tax_with!`](@ref).
- All other parameters are disaggregated using [`SLiDE._aggregate_sector_map`](@ref).

# Arguments
- `dataset::String`: dataset identifier
- `d::Dict` of DataFrames containing the model parameters.
- `set::Dict` of Arrays describing region, sector, final demand, etc.

# Keywords
- `scheme::Pair = :disagg=>:aggr`: columns in `dfmap` to aggregate from ``\\rightarrow`` to
- `path::String`: path to the [defaul sectoral aggregation mapping file](https://github.com/NREL/SLiDEData/blob/master/coremaps/scale/sector/eem.csv).

# Returns
- `d::Dict` of DataFrames containing disaggregated model parameters.
- `set::Dict` of Arrays describing region, sector, final demand, etc.
"""
function aggregate_sector!(
    dataset::String,
    d::Dict,
    set::Dict;
    scheme=:disagg=>:aggr,
    path::String=joinpath(SLIDE_DIR,"data","coremaps","scale","sector","eem.csv"),
)
    (from,to) = (scheme[1], scheme[2])
    dfmap = read_file(path)[:,[from,to]]

    _set_sector!(set, unique(dfmap[:,to]))

    taxes = [:ta0,:tm0,:ty0, :a0,:m0,:ys0]

    _aggregate_tax_with!(d, dfmap, :ta0, :a0)
    _aggregate_tax_with!(d, dfmap, :tm0, :m0)
    _aggregate_tax_with!(d, dfmap, :ty0, :ys0)

    _aggregate_sector_map!(d, dfmap, setdiff(keys(d), [taxes;:sector]); scheme=scheme)

    return d, set
end


"""
    _aggregate_tax_with!(d::Dict, dfmap, kt, k; kwargs...)
This function is applied to the following tax rates, which are scaled by a the corresponding
parameters. It returns the aggregated tax rate as well as the aggregated scaling parameter.

- `ta(yr,r,g)`, absorption taxes, scaled by domestic absorption, `a(yr,r,g)`:

```math
\\begin{aligned}
\\bar{a}_{yr,r,g} &= \\bar{a}_{yr,r,gg} \\circ map_{gg\\rightarrow g}
\\\\
\\bar{ta}_{yr,r,g} &= \\dfrac
    {\\left(\\bar{ta}_{yr,r,gg} \\cdot \\bar{a}_{yr,r,gg} \\right) \\circ map_{gg\\rightarrow g}}
    {                                  \\bar{a}_{yr,r,g}}
\\end{aligned}
```

- `tm(yr,r,g)`, import taxes, scaled by foreign imports, `m(yr,r,g)`:

```math
\\begin{aligned}
\\bar{m}_{yr,r,g} &= \\bar{m}_{yr,r,gg} \\circ map_{gg\\rightarrow g}
\\\\
\\bar{tm}_{yr,r,g} &= \\dfrac
    {\\left(\\bar{tm}_{yr,r,gg} \\cdot \\bar{m}_{yr,r,gg} \\right) \\circ map_{gg\\rightarrow g}}
    {                                  \\bar{m}_{yr,r,g}}
\\end{aligned}
```

- `ty(yr,r,s)`, production taxes, scaled by total regional sectoral output, `ys(yr,r,s,g)`:

```math
\\begin{aligned}
\\bar{ys}_{yr,r,s,g} &= \\bar{ys}_{yr,r,ss,gg} \\circ map_{ss\\rightarrow s, gg\\rightarrow g}
\\\\
\\bar{ty}_{yr,r,s} &= \\dfrac
    {\\left(\\bar{ty}_{yr,r,ss} \\cdot \\sum_{gg} \\bar{ys}_{yr,r,ss,gg} \\right) \\circ map_{ss\\rightarrow s}}
    {                                  \\sum_{g}  \\bar{ys}_{yr,r,s ,g}}
\\end{aligned}
```

where ``gg``, ``ss`` represent **dis**aggregate-level goods and sectors
and ``g``, ``s`` represent aggregate-level goods and sectors.

# Arguments
- `d::Dict` of model parameters
- `dfmap::DataFrame`: mapping ``map_{gg\\rightarrow g}``
- `kt::Symbol`: tax parameter key
- `k::Symbol`: scaling parameter key

# Keywords
- `scheme::Pair = :disagg=>:aggr`: columns in `dfmap` to aggregate from ``\\rightarrow`` to

# Returns
- `d[kt]::DataFrame`: mapped tax parameter
- `d[k]::DataFrame`: mapped scaling parameter
"""
function _aggregate_tax_with!(d::Dict, dfmap, kt, k; scheme=:disagg=>:aggr)
    sector = setdiff(propertynames(d[k]), propertynames(d[kt]))

    d[kt] = d[kt] * combine_over(d[k], sector)
    _aggregate_sector_map!(d, dfmap, [kt,k]; scheme=scheme)
    d[kt] = d[kt] / combine_over(d[k], sector)

    return dropzero!(dropnan!(d[kt])), d[k]
end


"""
    _aggregate_sector_map(df::DataFrame, dfmap::DataFrame; kwargs...)
This function aggregates a parameter in `df` according to the input map `dfmap`.
For a parameter ``\\bar{z}``,

```math
\\bar{z}_{yr,r,g} = \\sum_{gg} \\left(\\bar{z}_{yr,r,gg} \\circ map_{gg\\rightarrow g} \\right)
```

where ``gg``, ``ss`` represent **dis**aggregate-level goods and sectors
and ``g``, ``s`` represent aggregate-level goods and sectors.

# Keywords
- `scheme::Pair = :disagg=>:aggr`: columns in `dfmap` to aggregate from ``\\rightarrow`` to
- `key`: If a value is given, print a message indicating that `key` is being mapped.
"""
function _aggregate_sector_map(
    df::DataFrame,
    dfmap::DataFrame;
    scheme=:disagg=>:aggr,
    key=missing,
)
    df = _disagg_sector_map(df, dfmap; scheme=scheme, key=key)
    df = combine_over(df, :dummy; digits=false)
    return df
end


"""
    _aggregate_sector_map!(d::Dict, dfmap::DataFrame, parameters; kwargs...)
This function aggregates the list of input parameters (keys) in `d` using `dfmap`.
Each parameter is aggregated using [`SLiDE._aggregate_sector_map`](@ref).

# Keywords
- `scheme::Pair = :disagg=>:aggr`: columns in `dfmap` to aggregate from ``\\rightarrow`` to
"""
function _aggregate_sector_map!(d::Dict, dfmap, parameters; scheme=:disagg=>:aggr)
    [d[k] = _aggregate_sector_map(d[k], dfmap; scheme=scheme, key=k)
        for k in parameters]
    return d
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