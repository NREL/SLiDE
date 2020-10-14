"""
    partition!(d::Dict, set::Dict; kwargs...)

# Arguments
- `d::Dict` of DataFrames containing the model data.
- `set::Dict` of Arrays describing region, sector, final demand, etc.

# Keywords
- `save = true`
- `overwrite = false`
See [`SLiDE.build_data`](@ref) for keyword argument descriptions.

# Returns
- `d::Dict` of DataFrames containing the model data at the
"""
function partition!(d::Dict, set::Dict; save = true, overwrite = false)

    d_read = read_build("partition"; save = save, overwrite = overwrite);
    if !isempty(d_read)
        [d[k] = v for (k,v) in d_read]
        return d
    end

    [d[k] = edit_with(filter_with(d[k], (yr = set[:yr],)), [Drop(:units,"all","==")])
        for k in [:supply, :use]]

    _partition_io!(d, set)
    _partition_fd0!(d, set)
    _partition_ts0!(d, set)
    _partition_va0!(d, set)
    _partition_x0!(d, set)

    _partition_cif0!(d, set)
    _partition_m0!(d, set)   # cif0
    _partition_trn0!(d, set) # cif0

    _partition_mrg0!(d, set)
    _partition_md0!(d, set)  # mrg0, trn0
    _partition_ms0!(d)       # mrg0, trn0
    
    _partition_fs0!(d)       # fd0
    _partition_s0!(d)        # ys0
    
    _partition_y0!(d, set)   # ms0, fs0, ys0
    _partition_a0!(d, set)   # fd0, id0
    
    # _partition_sbd0!(d, set)
    # _partition_tax0!(d, set)
    _partition_ta0!(d, set)       # a0, sbd0, tax0
    
    # _partition_duty0!(d, set)
    _partition_tm0!(d, set)       # duty0, m0

    d_save = delete!(delete!(copy(d), :supply), :use)
    write_build("partition", d_save; save = save)

    return d
end

"""
    _remove_imrg(df::DataFrame, x::Pair{Symbol,Array{String,1}})
Removes commodity taxes and subsidies on the goods which are produced solely
for supplying retail sales margin.
"""
function _remove_imrg(df::DataFrame, x::Pair{Symbol,Array{String,1}})
    df[findall(in(x.second), df[:,x.first]), :value] .= 0.0
    return df
end

"""
`ys0(yr,s,g)`, sectoral supply (with byproducts), and
`id0(yr,g,s)`, intermediate input demand

Filter from supply/use data:

```math
\\begin{aligned}
\\tilde{id}_{yr,s,} = \\left\\{{use}\\left(yr,i,j\\right)
\\;\\vert\\; yr,\\, g \\in i,\\, s \\in j \\right\\}
\\\\
\\tilde{ys}_{yr,s,g} = \\left\\{{supply}\\left(yr,j,i\\right)
\\;\\vert\\; yr,\\, s \\in j,\\, g \\in i \\right\\}
\\end{aligned}
```

Treat negative inputs as outputs:

```math
\\begin{aligned}
\\tilde{ys}_{yr,s,g} &= \\tilde{ys}_{yr,s,g} - \\min\\left\\{0, \\tilde{id}_{yr,g,s} \\right\\} \\\\
\\tilde{id}_{yr,g,s} &= \\max\\left\\{ 0, \\tilde{id}_{yr,s,g} \\right\\}
\\end{aligned}
```
"""
function _partition_io!(d::Dict, set::Dict)
    println("  Partitioning id0 and ys0, supply/demand data.")
    # (!!!!) filtering here assumes sector/good are the same.
    d[:id0] = filter_with(d[:use], set)
    d[:ys0] = filter_with(d[:supply], set)

    (d[:id0], d[:ys0]) = fill_zero(d[:id0], d[:ys0])

    # Treat negative inputs as outputs.
    d[:ys0][!,:value] = d[:ys0][:,:value] - min.(0, d[:id0][:,:value])
    d[:id0][!,:value] = max.(0, d[:id0][:,:value])

    d[:id0] = dropzero(d[:id0])
    d[:ys0] = sort(dropzero(d[:ys0][:,[:yr,:j,:i,:value]]))
end

"""
`a(yr,g)`, Armington supply

```math
\\tilde{a}_{yr,g} = \\sum_{fd}\\tilde{fd}_{yr,g,fd} + \\sum_{s}\\tilde{id}_{yr,g,s}
```
"""
function _partition_a0!(d::Dict, set::Dict)
    println("  Partitioning a0, Armington supply")
    d[:a0] = combine_over(d[:fd0], :fd) + combine_over(d[:id0], :j)
    d[:a0] = _remove_imrg(d[:a0], :i => set[:imrg])
end

"""
`bopdef(yr)`, balance of payments

```math
\\tilde{bop}_{yr} = 0
\\;\\forall\\; yr
```
"""
function _partition_bop!(d::Dict, set::Dict)
    println("  Partitioning bopdef0, balance of payments deficit")
    d[:bopdef] = fill_zero((yr = set[:yr], ))
end

"""
`cif(yr,g)`, CIF/FOB Adjustments on Imports

```math
\\tilde{cif}_{yr,g} = \\left\\{{supply}\\left(yr,i,j\\right)
\\;\\vert\\; yr,\\, g \\in i,\\, j = ciffob \\right\\}
```
"""
function _partition_cif0!(d::Dict, set::Dict)
    println("  Partitioning CIF/FOB adjustments on imports")
    d[:cif0] = filter_with(d[:supply], (i = set[:i], j = "ciffob"))[:,[:yr,:i,:value]]
end

"""
`duty(yr,g)`, import duties

```math
\\tilde{duty}_{yr,g} = \\left\\{{supply}\\left(yr,i,j\\right)
\\;\\vert\\; yr,\\, g \\in i,\\, j = duties \\right\\}
```
"""
function _partition_duty0!(d::Dict, set::Dict)
    println("  Partitioning duty0, import duties")
    d[:duty0] = filter_with(d[:supply], (i = set[:i], j = "duties"))[:,[:yr,:i,:value]]
    d[:duty0] = _remove_imrg(d[:duty0], :i => set[:imrg])
    return d[:duty0]
end

"""
`fd(yr,g,fd)`, final demand

```math
\\tilde{fd}_{yr,g,fd} = \\left\\{{use}\\left(yr,i,j\\right)
\\;\\vert\\; yr,\\, g \\in i,\\, fd \\in j \\right\\}
```
"""
function _partition_fd0!(d::Dict, set::Dict)
    println("  Partitioning fd0, final demand")
    d[:fd0] = filter_with(d[:use], (i = set[:i],  j = set[:fd]))
    d[:fd0] = edit_with(d[:fd0], Rename(:j, :fd))
end

"""
    _partition_fs0!(d::Dict)
`fs0`: Household supply.
Move household supply of recycled goods into the domestic output market,
from which some may be exported.

```math
\\tilde{fs}_{yr,g} = \\left\\{\\tilde{fd}_{yr,g,fd}
\\;\\vert\\; yr,\\, g \\in i,\\, fd = pce \\right\\}
```
"""
function _partition_fs0!(d::Dict)
    println("  Partitioning fs0, household supply")
    d[:fs0] = filter_with(d[:fd0], (fd = "pce",))[:,[:yr,:i,:value]]
    d[:fs0][!,:value] .= - min.(d[:fs0][:,:value], 0)
end

"""
`m(yr,g)`, imports

```math
\\tilde{m}_{yr,g} = \\left\\{{supply}\\left(yr,i,j\\right)
\\;\\vert\\; yr,\\, g \\in i,\\, j = imports \\right\\}
```

Adjust transport margins according to CIF/FOB adjustments:

```math
\\tilde{m}_{yr,g} = \\tilde{m}_{yr,g} + \\tilde{cif}_{yr,g}
\\;\\forall\\; g = ins
```
"""
function _partition_m0!(d::Dict, set::Dict)
    println("  Partitioning m0, imports")
    d[:m0]  = filter_with(d[:supply], (i = set[:i], j = "imports"))[:,[:yr,:i,:value]]

    # Adjust transport margins for transport sectors according to CIF/FOB adjustments.
    # Insurance imports are specified as net of adjustments.
    d[:m0] += filter_with(d[:cif0], (i = "ins",))
    d[:m0] = _remove_imrg(d[:m0], :i => set[:imrg])
end

"""
`md(yr,m,g)`, margin demand

```math
\\begin{aligned}
\\tilde{md}_{yr,m,g} &= 
\\begin{cases}
\\tilde{mrg}_{yr,g}  & m = trd   \\\\
\\tilde{trn}_{yr,g}  & m = trn
\\end{cases}
\\\\
\\tilde{md}_{yr,m,g} &= \\max\\left\\{0, \\tilde{md}_{yr,m,g} \\right\\}
\\end{aligned}
```
"""
function _partition_md0!(d::Dict, set::Dict)
    println("  Partitioning md0, margin demand")
    d[:md0] = [edit_with(d[:mrg0], Add(:m, "trd")); edit_with(d[:trn0], Add(:m, "trn"))]
    d[:md0] = sort(d[:md0][:,[:yr,:m,:i,:value]])
    d[:md0] = _remove_imrg(d[:md0], :i => set[:imrg])

    d[:md0][!,:value] .= max.(d[:md0][:,:value], 0)
end

"""
`ms(yr,g,m)`, margin supply

```math
\\begin{aligned}
\\tilde{ms}_{yr,g,m} &= 
\\begin{cases}
\\tilde{mrg}_{yr,g}  & m = trd   \\\\
\\tilde{trn}_{yr,g}  & m = trn
\\end{cases}
\\\\
\\tilde{ms}_{yr,g,m} &= \\max\\left\\{0, -\\tilde{ms}_{yr,g,m} \\right\\}
\\end{aligned}
```
"""
function _partition_ms0!(d::Dict)
    println("  Partitioning ms0, margin supply")
    d[:ms0] = [edit_with(d[:mrg0], Add(:m, "trd")); edit_with(d[:trn0], Add(:m, "trn"))]
    d[:ms0] = sort(d[:ms0][:,[:yr,:i,:m,:value]])

    d[:ms0][!,:value] .= max.(-d[:ms0][:,:value], 0)
end

"""
`mrg(yr,g)`, trade margins

```math
\\tilde{mrg}_{yr,g} = \\left\\{{supply}\\left(yr,i,j\\right)
\\;\\vert\\; yr,\\, g \\in i,\\, j = margins \\right\\}
```
"""
function _partition_mrg0!(d::Dict, set::Dict)
    println("  Partitioning mrg0, trade margins")
    d[:mrg0] = filter_with(d[:supply], (i = set[:i], j = "margins"))[:,[:yr,:i,:value]]
end

"""
`s(yr,s)`, aggregate supply

```math
\\tilde{s}_{yr,s} = \\sum_{g}\\tilde{ys}_{yr,s,g}
```
"""
function _partition_s0!(d::Dict)
    println("  Partitioning s0, aggregate supply")
    # (!!!!) I think here we're summing over g, so we should get s(yr,s).
    # But in the disaggregation step we sum over s? I'm not sure we even need s0 here,
    # but it seems inconsistent.
    d[:s0] = combine_over(d[:ys0], :i)
end

"""
`sbd(yr,g)`, subsidies on products

```math
\\tilde{sbd}_{yr,g} = \\left\\{{supply}\\left(yr,i,j\\right)
\\;\\vert\\; yr,\\, g \\in i,\\, j = subsidies \\right\\}
```

Treat negative inputs as outputs:

```math
\\tilde{sbd}_{yr,g} = - \\tilde{sbd}_{yr,g}
```
"""
function _partition_sbd0!(d::Dict, set::Dict)
    println("  Partitioning sbd0, subsidies on products")
    d[:sbd0] = filter_with(d[:supply], (i = set[:i], j = "subsidies"))[:,[:yr,:i,:value]]
    d[:sbd0] = _remove_imrg(d[:sbd0], :i => set[:imrg])
    d[:sbd0][!,:value] *= -1
    return d[:sbd0]
end

"""
`ta(yr,g)`, import tariff

```math
\\tilde{ta}_{yr,g} = \\frac{\\tilde{tax}_{yr,g} - \\tilde{sbd}_{yr,g}}{\\tilde{a}_{yr,g}}
```
"""
function _partition_ta0!(d::Dict, set::Dict)
    println("  Partitioning ta0, import tariffs")
    df_tax = _partition_tax0!(d, set)
    df_sbd = _partition_sbd0!(d, set)

    d[:ta0] = dropnan((df_tax - df_sbd) / d[:a0])
    # d[:ta0] = edit_with(d[:ta0], Drop(:units,"all","=="))
end

"""
`tax(yr,g)`, taxes on products

```math
\\tilde{tax}_{yr,g} = \\left\\{{supply}\\left(yr,i,j\\right)
\\;\\vert\\; yr,\\, g \\in i,\\, j = tax \\right\\}
```
"""
function _partition_tax0!(d::Dict, set::Dict)
    println("  Partitioning tax0, taxes on products")
    d[:tax0] = filter_with(d[:supply], (i = set[:i], j = "tax"))[:,[:yr,:i,:value]]
    d[:tax0] = _remove_imrg(d[:tax0], :i => set[:imrg])
    return d[:tax0]
end

"""
`tm(yr,g)`, tax net subsidy rate on intermediate demand

```math
\\tilde{tm}_{yr,g} = \\frac{\\tilde{duty}_{yr,g}}{\\tilde{m}_{yr,g}}
```
"""
function _partition_tm0!(d::Dict, set::Dict)
    println("  Partitioning tm0, tax net subsidy rate on intermediate demand")
    df_duty = _partition_duty0!(d, set);

    d[:tm0] = dropnan(df_duty / d[:m0])
    # d[:tm0] = edit_with(d[:tm0], Drop(:units,"all","=="))
end

"""
`trn(yr,g)`, transportation costs

```math
\\tilde{trn}_{yr,g} = \\left\\{{supply}\\left(yr,i,j\\right)
\\;\\vert\\; yr,\\, g \\in i,\\, j = trncost \\right\\}
```

```math
\\tilde{trn}_{yr,g} = \\tilde{m}_{yr,g} + \\tilde{cif}_{yr,g}
\\;\\forall\\; g \\neq ins
```

"""
function _partition_trn0!(d::Dict, set::Dict)
    println("  Partitioning trn0, transportation costs")
    d[:trn0]  = filter_with(d[:supply], (i = set[:i], j = "trncost"))[:,[:yr,:i,:value]]

    # Adjust transport margins for transport sectors according to CIF/FOB adjustments.
    # Insurance imports are specified as net of adjustments.
    d[:trn0] += edit_with(d[:cif0], Drop(:i,"ins","=="))
    return d[:trn0]
end

"""
`ts(yr,ts,s)`, taxes and subsidies

```math
\\tilde{ts}_{yr,ts,s} = \\left\\{{use}\\left(yr,i,j\\right)
\\;\\vert\\; yr,\\, ts \\in i,\\, s \\in j \\right\\}
```
Treat negative inputs as outputs:

```math
\\tilde{ts}_{yr,ts,s} = - \\tilde{ts}_{yr,ts,s}
\\;\\forall\\; ts = subsidies
```
"""
function _partition_ts0!(d::Dict, set::Dict)
    println("  Partitioning ts0, taxes and subsidies")
    d[:ts0] = filter_with(d[:use], (i = set[:ts], j = set[:j]))
    d[:ts0][d[:ts0][:,:i] .== "subsidies", :value] *= -1  # treat negative inputs as outputs
    return d[:ts0]
end

"""
`va(yr,va,s)`, value added

```math
\\tilde{va}_{yr,va,s} = \\left\\{{use}\\left(yr,i,j\\right)
\\;\\vert\\; yr,\\, va \\in i,\\, s \\in j \\right\\}
```
"""
function _partition_va0!(d::Dict, set::Dict)
    println("  Partitioning va0, value added")
    d[:va0] = filter_with(d[:use], (i = set[:va], j = set[:j]))
    d[:va0] = edit_with(d[:va0], Rename(:i, :va))
end

"""
`x(yr,g)`, exports of goods and services

```math
\\tilde{x}_{yr,g} = \\left\\{{use}\\left(yr,i,j\\right)
\\;\\vert\\; yr,\\, g \\in i,\\, exports \\in j \\right\\}
```
"""
function _partition_x0!(d::Dict, set::Dict)
    println("  Partitioning x0, exports of goods and services")
    d[:x0] = filter_with(d[:use], (i = set[:i], j = "exports"))[:,[:yr,:i,:value]]
    d[:x0] = _remove_imrg(d[:x0], :i => set[:imrg])
end

"""
`y(yr,g)`, gross output

```math
\\tilde{y}_{yr,g} = \\sum_{s}\\tilde{ys}_{yr,s,g} - \\sum_{m}\\tilde{ms}_{yr,g,m}
```
"""
function _partition_y0!(d::Dict, set::Dict)
    println("  Partitioning y0, gross output")
    d[:y0] = combine_over(d[:ys0], :j) + d[:fs0] - combine_over(d[:ms0], :m)
    d[:y0] = _remove_imrg(d[:y0], :i => set[:imrg])
end