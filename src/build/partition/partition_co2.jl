"""
    partition_co2!(dataset::Dataset, d::Dict, set::Dict, maps::Dict)
This function partitions and calculates CO2 emissions data.

# Arguments
- `dataset::Dataset` identifier
- `d::Dict` of model parameters
- `set::Dict` of Arrays describing parameter indices (years, regions, goods, sectors, etc.)
- `maps::Dict` of default mapping schematics and constants

# Returns
- `d::Dict` of model parameters
- `set::Dict` of Arrays describing parameter indices (years, regions, goods, sectors, etc.)
"""
function partition_co2!(dataset::Dataset, d::Dict, set::Dict, maps::Dict)
    step = "co2"
    d_read = SLiDE.read_build(SLiDE.set!(dataset; step=step))

    if dataset.step=="input"
        print_status(set!(dataset; step=step))

        partition_co2!(d, set, maps)
        write_build!(SLiDE.set!(dataset; step=step), copy(d))
    else
        merge!(d, d_read)
    end

    return d
end


function partition_co2!(d::Dict, set::Dict, maps::Dict)
    _partition_co2emiss!(d, maps)
    _share_co2emiss!(d, set, maps)
    _partition_secco2!(d, set, maps)
    _partition_resco2!(d)
    return d
end


"""
```math
\\bar{co_2}_{yr,r,src,sec} \\text{ [million metric tons of CO2]} = \\dfrac{1}{10^3}
    \\cdot \\tilde{eq}_{yr,r,src\\neq ele, sec} \\text{ [trillion btu]}
    \\cdot f_{src} \\text{ [kg CO2/million btu]}
```
"""
function _partition_co2emiss!(d::Dict, maps::Dict)
    if !haskey(d, :co2emiss)
        df_btu = filter_with(d[:eq0], (units=BTU,))

        df = operate_over(df_btu, maps[:co2perbtu];
            id=[:btu,:co2_per_btu]=>:co2,
            units=maps[:operate],
        )
        df[!,:value] .= df[:,:factor] .* df[:,:co2_per_btu] .* df[:,:btu]

        d[:co2emiss] = operation_output(df)
    end

    return d[:co2emiss]
end


"""
Define:
```math
\\begin{aligned}
\\tilde{v}_{yr,r,g=e,s} &= \\left\\{
    \\tilde{id}_{yr,r,g,s} \\;\\vert\\; g=e
\\right\\}
\\\\
map_{s\\rightarrow sec} &= \\left\\{
    demand(s,src) \\;\\vert\\; [ind,com,trn]\\in sec
\\right\\}
\\end{aligned}
```

Then, use [`SLiDE.share_with`](@ref) to define ``\\delta^{co2}_{yr,r,g,s\\rightarrow sec}``:

```math
\\tilde{\\delta}^{co2}_{yr,r,g,s\\rightarrow sec} = \\dfrac
    {v_{yr,r,g=e,s} \\circ map_{s\\rightarrow sec}}
    {\\sum_{sec} v_{yr,r,g=e,s} \\circ map_{s\\rightarrow sec}}
```
"""
function _share_co2emiss!(d::Dict, set::Dict, maps::Dict)
    if !haskey(d, :shrco2)
        x = ["ind","com","trn"]
        df = filter_with(copy(d[:id0]), (g=set[:e],))
        dfmap = filter_with(maps[:demand], (sec=x,))

        d[:shrco2] = SLiDE.share_with(df, Mapping(dfmap))
    end
    return d[:shrco2]
end


"""
For ``sec = (ind,com,trn)``, use the sharing parameter ``\\delta^{co2}_{yr,r,g,s\\rightarrow sec}``
calculated by [`SLiDE._share_co2emiss!`](@ref).

```math
\\tilde{co2}_{yr,r,g,s} = \\sum_{sec} \\left(
    \\tilde{co2}_{yr,r,src\\rightarrow g, sec} \\cdot
    \\delta^{co2}_{yr,r,g,s\\rightarrow sec}
\\right)
```

Use un-shared values for ``sec = (ele,ref)`` (which maps to ``s = (ele,oil)``):

```math
\\tilde{co2}_{yr,r,g,s\\neq res}
= \\tilde{co2}_{yr,r,src\\rightarrow g, sec} \\circ map_{sec\\rightarrow s}
```
"""
function _partition_secco2!(d::Dict, set::Dict, maps::Dict)
    df_co2emiss = edit_with(SLiDE._partition_co2emiss!(d, maps), Rename(:src,:g))

    # (1) Use share for sec = (ind,com,trn)
    df_shrsec = SLiDE._share_co2emiss!(d, set, maps)

    df = SLiDE.operate_over(df_shrsec, df_co2emiss;
        id=[:factor,:co2]=>:value,
        fillmissing=0.0,
    )
    df[!,:value] .= df[:,:factor] .* df[:,:co2]
    df[!,:units] .= df[:,:units_co2]

    df = combine_over(df, :sec; digits=false)

    # (2) Use un-shared values for s=(ele,oil).
    idx = vcat(
        DataFrame(g=set[:e], sec="ele"),
        DataFrame(g="cru", sec="ref"),
    )
    x = [Map(maps[:demand],[:sec],[:s],[:sec],[:s],:inner), Deselect([:sec],"==")]
    df_ele_oil = edit_with(filter_with(df_co2emiss, idx), x)

    # (3) Combine.
    d[:secco2] = dropzero(vcat(df_ele_oil, df; cols=:intersect))
    d[:secco2] = filter_with(d[:secco2], Not(SLiDE._no_co2emiss!(d)))

    SLiDE.print_status(:secco2, d)
    return d[:secco2]
end


"""
```math
\\tilde{co2}_{yr,r,g} = \\left\\{
    co2_{yr,r,src\\rightarrow g,sec} \\;\\vert\\; sec=res
\\right\\}
```
"""
function _partition_resco2!(d::Dict)
    d[:resco2] = edit_with(filter_with(d[:co2emiss], (sec="res",); drop=true), Rename(:src,:g))
    print_status(:resco2, d)
    return d[:resco2]
end


function _no_co2emiss!(d::Dict)
    idx = findindex(d[:id0])
    df = filter_with(d[:secco2], Not(d[:id0][:,idx]))
    d[:nomatch] = select(df, idx)
end