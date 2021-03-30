"""
    partition(d::Dict, set::Dict; kwargs...)

# Arguments
- `d::Dict` of DataFrames containing the model data.
- `set::Dict` of Arrays describing region, sector, final demand, etc.

# Keywords
- `save_build = true`
- `overwrite = false`
See [`SLiDE.build`](@ref) for keyword argument descriptions.

# Returns
- `d::Dict` of DataFrames containing the model data at the
"""
function partition(
    dataset::String,
    d::Dict,
    set::Dict;
    version::String=DEFAULT_VERSION,
    save_build::Bool=DEFAULT_SAVE_BUILD,
    overwrite::Bool=DEFAULT_OVERWRITE,
    map_fdcat::Bool=false,
)
    # !!!! different for "detailed" sector as not to overwrite.
    CURR_STEP = "partition"
    
    # If there is already partition data, read it and return.
    d_read = read_build(dataset, CURR_STEP; overwrite = overwrite)
    !(isempty(d_read)) && (return d_read)
    
    x = Deselect([:units],"==")
    [d[k] = edit_with(filter_with(d[k], (yr=set[:yr],)), x) for k in [:supply,:use]]

    map_fdcat && _filter_use!(d,set)

    _partition_io!(d, set)
    _partition_fd!(d, set)

    # _partition_fd0!(d, set)
    _partition_ts0!(d, set)
    _partition_va0!(d, set)
    _partition_x0!(d, set)
    
    _partition_cif0!(d, set)
    _partition_m0!(d, set)   # cif0
    _partition_trn0!(d, set) # cif0
    
    _partition_mrg0!(d, set)
    _partition_md0!(d, set)  # mrg0, trn0
    _partition_ms0!(d, set)  # mrg0, trn0
    
    # _partition_fs0!(d)       # fd0
    _partition_s0!(d, set)     # ys0
    
    _partition_y0!(d, set)   # ms0, fs0, ys0
    _partition_a0!(d, set)   # fd0, id0
    
    _partition_ta0!(d, set)  # a0, sbd0, tax0
    _partition_tm0!(d, set)  # duty0, m0
    
    write_build!(dataset, CURR_STEP, d; save_build=save_build)
    
    haskey(d,:sector) && delete!(d,:sector)
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
This function combines fd values into fdcat values upfront. Doing so changes the results of
the calibration routine slightly, but isn't too bad. This is the only mapping
still performed in the build stream. If the difference in output is alright, we can
move this mapping to the data stream.
"""
function _filter_use!(d::Dict, set::Dict)
    df = copy(d[:use])
    s0 = append(:s,:fd)
    
    x = [
        Rename(:s,s0),
        Map("crosswalk/fd.csv",[:fd],[:fdcat],[s0],[:s],:left),
        Replace(:s,missing,"$s0 value"),
        Combine("",propertynames(df)),
        Order(propertynames(df), eltype.(eachcol(df))),
    ]

    set[:fd] = unique(read_file(x[2])[:,:fdcat])
    d[:use] = edit_with(df,x)
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

    # In sectordisagg, the good/sector column names are switched...
    if d[:sector]==:detail
        x = Rename.([:g,:s,:g_temp],[:g_temp,:g,:s])
        d[:ys0] = edit_with(d[:ys0], x)
    end
    
    (d[:id0], d[:ys0]) = fill_zero(d[:id0], d[:ys0])

    # Treat negative inputs as outputs.
    d[:ys0][!,:value] = d[:ys0][:,:value] - min.(0, d[:id0][:,:value])
    d[:id0][!,:value] = max.(0, d[:id0][:,:value])

    [dropzero!(d[k]) for k in [:ys0,:id0]]
    return d
end


function _partition_ys0!(d::Dict, set::Dict)
    !haskey(d, :ys0) && _partition_io!(d, set)
    return d[:ys0]
end


function _partition_id0!(d::Dict, set::Dict)
    !haskey(d, :id0) && _partition_io!(d, set)
    return d[:id0]
end


"""
`a(yr,g)`, Armington supply

```math
\\tilde{a}_{yr,g} = \\sum_{fd}\\tilde{fd}_{yr,g,fd} + \\sum_{s}\\tilde{id}_{yr,g,s}
```
"""
function _partition_a0!(d::Dict, set::Dict)
    if !haskey(d,:a0)
        _partition_fs0!(d, set)
        _partition_id0!(d, set)

        println("  Partitioning a0, Armington supply")
        d[:a0] = combine_over(d[:fd0], :fd) + combine_over(d[:id0], :s)
        d[:a0] = _remove_imrg(d[:a0], :g => set[:imrg])
    end
    return d[:a0]
end


"""
`bopdef(yr)`, balance of payments

```math
\\tilde{bop}_{yr} = 0
\\;\\forall\\; yr
```
"""
function _partition_bop!(d::Dict, set::Dict)
    if !haskey(d,:bopdef)
        println("  Partitioning bopdef0, balance of payments deficit")
        d[:bopdef] = fill_zero((yr=set[:yr], ))
    end
    return d[:bopdef]
end


"""
`cif(yr,g)`, CIF/FOB Adjustments on Imports

```math
\\tilde{cif}_{yr,g} = \\left\\{{supply}\\left(yr,i,j\\right)
\\;\\vert\\; yr,\\, g \\in i,\\, j = ciffob \\right\\}
```
"""
function _partition_cif0!(d::Dict, set::Dict)
    if !haskey(d, :cif0)
        println("  Partitioning CIF/FOB adjustments on imports")
        d[:cif0] = filter_with(d[:supply], (g=set[:g], s="ciffob"); drop=true)
    end
    return d[:cif0]
end


"""
`duty(yr,g)`, import duties

```math
\\tilde{duty}_{yr,g} = \\left\\{{supply}\\left(yr,i,j\\right)
\\;\\vert\\; yr,\\, g \\in i,\\, j = duties \\right\\}
```
"""
function _partition_duty0!(d::Dict, set::Dict)
    if !haskey(d, :duty0)
        println("  Partitioning duty0, import duties")
        d[:duty0] = filter_with(d[:supply], (g=set[:g], s="duties"); drop=true)
        d[:duty0] = _remove_imrg(d[:duty0], :g => set[:imrg])
    end
    return d[:duty0]
end


"""
`fd(yr,g,fd)`, final demand, and
`fs(yr,g)`, household supply

```math
\\begin{aligned}
\\tilde{fd}_{yr,g,fd} &= \\left\\{{use}\\left(yr,i,j\\right) \\;\\vert\\; yr,\\, g \\in i,\\, fd \\in j \\right\\}
\\\\
\\tilde{fs}_{yr,g} &= \\left\\{\\tilde{fd}_{yr,g,fd} \\;\\vert\\; yr,\\, g \\in i,\\, fd = pce \\right\\}
\\end{aligned}
```

```math
\\begin{aligned}
\\tilde{fs}_{yr,g} &= - \\min\\left\\{0, \\tilde{fs}_{yr,g} \\right\\}
\\\\
\\tilde{fd}_{yr,g,fd} &= \\max\\left\\{0, \\tilde{fd}_{yr,g,fd} \\right\\}
\\end{aligned}
```
"""
function _partition_fd!(d::Dict, set::Dict)
    x = Rename(:s, :fd)
    d[:fd0] = filter_with(edit_with(d[:use],x), set)
    d[:fs0] = filter_with(d[:fd0], (fd=["pce","C"],); drop = true)
    
    d[:fs0][!,:value] .= - min.(0, d[:fs0][:,:value])

    # For the sectoral disaggregation, 
    if d[:sector]==:detail
        d[:fd0][.&(d[:fd0][:,:fd].=="pce", d[:fd0][:,:value].<0),:value] .= 0.0
        d[:fd0][.&(d[:fd0][:,:fd].=="C", d[:fd0][:,:value].<0),:value] .= 0.0
    end

    [dropzero!(d[k]) for k in [:fd0,:fs0]]
    return d
end


"""
`fd(yr,g,fd)`, final demand

```math
\\tilde{fd}_{yr,g,fd} = \\left\\{{use}\\left(yr,i,j\\right)
\\;\\vert\\; yr,\\, g \\in i,\\, fd \\in j \\right\\}
\\\\
\\tilde{fd}_{yr,g,fd} = \\max\\left\\{0, \\tilde{fd}_{yr,g,fd} \\right\\} \\;\\vert\\; yr,\\, g,\\, fd = pce \\right\\}
```
"""
function _partition_fd0!(d::Dict, set::Dict)
    !haskey(d,:fd0) && _partition_fd!(d, set)
    # println("  Partitioning fd0, final demand")
    # d[:fd0] = filter_with(d[:use], (g=set[:g], s=set[:fd]))
    # d[:fd0] = edit_with(d[:fd0], Rename(:s, :fd))
    return d[:fd0]
end


"""
`fs(yr,g)`, household supply

```math
\\tilde{fs}_{yr,g} = \\left\\{\\tilde{fd}_{yr,g,fd}
\\;\\vert\\; yr,\\, g \\in i,\\, fd = pce \\right\\}
\\\\
\\tilde{fs}_{yr,g} = - \\min\\left\\{0, \\tilde{fs}_{yr,g} \\right\\}
```
"""
function _partition_fs0!(d::Dict, set::Dict)
    !haskey(d, :fs0) && _partition_fd!(d, set)
    # println("  Partitioning fs0, household supply")
    # d[:fs0] = filter_with(d[:fd0], (fd=["pce","C"],); drop=true)
    # d[:fs0][!,:value] .= - min.(d[:fs0][:,:value], 0)
    # return dropzero!(d[:fs0])
    return d[:fs0]
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
    if !haskey(d, :m0)
        _partition_cif0!(d, set)

        println("  Partitioning m0, imports")
        d[:m0] = filter_with(d[:supply], (g=set[:g], s="imports"); drop=true)

        # Adjust transport margins for transport sectors according to CIF/FOB adjustments.
        # Insurance imports are specified as net of adjustments.
        if d[:sector]==:summary
            d[:m0] += filter_with(d[:cif0], (g="ins",))
            d[:m0] = _remove_imrg(d[:m0], :g => set[:imrg])
        end
    end
    return d[:m0]
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
    if !haskey(d, :md0)
        _partition_mrg0!(d, set)
        _partition_trn0!(d, set)

        println("  Partitioning md0, margin demand")
        d[:md0] = [edit_with(d[:mrg0], Add(:m, "trd")); edit_with(d[:trn0], Add(:m, "trn"))]
        d[:md0] = sort(d[:md0][:,[:yr,:m,:g,:value]])
        d[:md0] = _remove_imrg(d[:md0], :g => set[:imrg])

        d[:md0][!,:value] .= max.(d[:md0][:,:value], 0)
    end
    return d[:md0]
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
function _partition_ms0!(d::Dict, set::Dict)
    if !haskey(d, :ms0)
        _partition_mrg0!(d, set)
        _partition_trn0!(d, set)

        println("  Partitioning ms0, margin supply")
        d[:ms0] = [edit_with(d[:mrg0], Add(:m, "trd")); edit_with(d[:trn0], Add(:m, "trn"))]
        d[:ms0] = sort(d[:ms0][:,[:yr,:g,:m,:value]])

        d[:ms0][!,:value] .= max.(-d[:ms0][:,:value], 0)
    end

    return d[:ms0]
end


"""
`mrg(yr,g)`, trade margins

```math
\\tilde{mrg}_{yr,g} = \\left\\{{supply}\\left(yr,i,j\\right)
\\;\\vert\\; yr,\\, g \\in i,\\, j = margins \\right\\}
```
"""
function _partition_mrg0!(d::Dict, set::Dict)
    if !haskey(d, :mrg0)
        println("  Partitioning mrg0, trade margins")
        d[:mrg0] = filter_with(d[:supply], (g=set[:g], s="margins"); drop=true)
    end

    return d[:mrg0]
end


"""
`s(yr,s)`, aggregate supply

```math
\\tilde{s}_{yr,s} = \\sum_{g}\\tilde{ys}_{yr,s,g}
```
"""
function _partition_s0!(d::Dict, set::Dict)
    if !haskey(d,:s0)
        _partition_ys0!(d, set)

        println("  Partitioning s0, aggregate supply")
        d[:s0] = edit_with(combine_over(d[:ys0], :g), Rename(:s,:g))
    end

    return d[:s0]
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
    if !haskey(d,:sbd0)
        println("  Partitioning sbd0, subsidies on products")
        d[:sbd0] = filter_with(d[:supply], (g=set[:g], s="subsidies"); drop=true)
        d[:sbd0] = _remove_imrg(d[:sbd0], :g => set[:imrg])
        d[:sbd0][!,:value] *= -1
    end
    return d[:sbd0]
end


"""
`ta(yr,g)`, import tariff

```math
\\tilde{ta}_{yr,g} = \\frac{\\tilde{tax}_{yr,g} - \\tilde{sbd}_{yr,g}}{\\tilde{a}_{yr,g}}
```
"""
function _partition_ta0!(d::Dict, set::Dict)
    if !haskey(d, :ta0)
        println("  Partitioning ta0(yr,g), import tariffs")
        !haskey(d, :tax0) && _partition_tax0!(d, set)
        !haskey(d, :sbd0) && _partition_sbd0!(d, set)

        d[:ta0] = dropnan((d[:tax0] - d[:sbd0]) / d[:a0])
        # d[:ta0] = edit_with(d[:ta0], Replace(:units, "billions of us dollars (USD)", "USD/USD"))
    end
    return d[:ta0]
end


"""
`tax(yr,g)`, taxes on products

```math
\\tilde{tax}_{yr,g} = \\left\\{{supply}\\left(yr,i,j\\right)
\\;\\vert\\; yr,\\, g \\in i,\\, j = tax \\right\\}
```
"""
function _partition_tax0!(d::Dict, set::Dict)
    if !haskey(d, :tax0)
        println("  Partitioning tax0, taxes on products")
        d[:tax0] = filter_with(d[:supply], (g=set[:g], s="tax"); drop=true)
        d[:tax0] = _remove_imrg(d[:tax0], :g => set[:imrg])
    end
    return d[:tax0]
end


"""
`tm(yr,g)`, tax net subsidy rate on intermediate demand

```math
\\tilde{tm}_{yr,g} = \\frac{\\tilde{duty}_{yr,g}}{\\tilde{m}_{yr,g}}
```
"""
function _partition_tm0!(d::Dict, set::Dict)
    if !haskey(d, :tm0)
        println("  Partitioning tm0, tax net subsidy rate on intermediate demand")
        !haskey(d, :duty0) && _partition_duty0!(d, set)
        !haskey(d, :m0) && _partition_m0!(d, set)

        d[:tm0] = dropnan(d[:duty0] / d[:m0])
        # d[:tm0] = edit_with(d[:tm0], Replace(:units, "billions of us dollars (USD)", "USD/USD"))
    end
    return d[:tm0]
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
    if !haskey(d, :trn0)
        _partition_cif0!(d, set)

        println("  Partitioning trn0, transportation costs")
        d[:trn0]  = filter_with(d[:supply], (g=set[:g], s="trncost"); drop=true)
        
        # Adjust transport margins for transport sectors according to CIF/FOB adjustments.
        # Insurance imports are specified as net of adjustments.
        d[:trn0] += edit_with(d[:cif0], Drop(:g,"ins","=="))
    end
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
    if !haskey(d, :ts0)
        println("  Partitioning ts0, taxes and subsidies")
        d[:ts0] = filter_with(d[:use], (g=set[:ts], s=set[:s]))
        d[:ts0] = edit_with(d[:ts0], Rename(:g, :ts))
        d[:ts0][d[:ts0][:,:ts] .== "subsidies", :value] *= -1  # treat negative inputs as outputs
    end
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
    if !haskey(d, :va0)
        println("  Partitioning va0, value added")
        d[:va0] = filter_with(d[:use], (g=set[:va], s=set[:s]))
        d[:va0] = edit_with(d[:va0], Rename(:g, :va))
    end
    return d[:va0]
end


"""
`x(yr,g)`, exports of goods and services

```math
\\tilde{x}_{yr,g} = \\left\\{{use}\\left(yr,i,j\\right)
\\;\\vert\\; yr,\\, g \\in i,\\, exports \\in j \\right\\}
```
"""
function _partition_x0!(d::Dict, set::Dict)
    if !haskey(d, :x0)
        println("  Partitioning x0, exports of goods and services")
        d[:x0] = filter_with(d[:use], (g=set[:g], s="exports"); drop=true)
        d[:x0] = _remove_imrg(d[:x0], :g => set[:imrg])
    end
    return d[:x0]
end


"""
`y(yr,g)`, gross output
"Move household supply of recycled goods into the domestic output market
from which some may be exported. Net out margin supply from output."

```math
\\tilde{y}_{yr,g} = \\sum_{s}\\tilde{ys}_{yr,s,g} + \\tilde{fd}_{yr,g} - \\sum_{m}\\tilde{ms}_{yr,g,m}
```
"""
function _partition_y0!(d::Dict, set::Dict)
    if !haskey(d, :y0)
        _partition_ys0!(d, set)
        _partition_fs0!(d, set)
        _partition_ms0!(d, set)
        
        println("  Partitioning y0, gross output")
        d[:y0] = if d[:sector]==:summary
            combine_over(d[:ys0], :s) + d[:fs0] - combine_over(d[:ms0], :m)
        elseif d[:sector]==:detail
            combine_over(d[:ys0], :s) + d[:fs0]
        end

        d[:y0] = _remove_imrg(d[:y0], :g => set[:imrg])
    end
    return d[:y0]
end