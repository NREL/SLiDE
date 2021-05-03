"""
`rpc(r,g)`: Regional purchase coefficient

```math
\\rho_{r,g}^{cfs}
=
\\begin{cases}
\\dfrac{\\bar{d}_{r,g}}
       {\\bar{d}_{r,g} - \\bar{mn}_{r,g}}  & r\\neq uti, \\bar{d}_{r,g} \\neq \\bar{mn}_{r,g}
\\\\
0.0                                        & r\\neq uti, \\bar{d}_{r,g} = \\bar{mn}_{r,g}
\\\\
0.9                                        & r = uti
\\end{cases}
```
"""
function share_rpc!(d::Dict, set::Dict)
    print_status(:rpc, [:r,:g], "regional purchase coefficient")

    _set_ng!(set, d)
    _share_mrt0!(d)
    _share_d0!(d, set)
    _share_xn0!(d, set)
    _share_mn0!(d, set)

    df = dropnan(d[:d0] / (d[:d0] + d[:mn0]))

    df = edit_with(df, Drop(:g, "uti", "=="))
    df_uti = fill_with((r = set[:r], g = "uti"), 0.9)

    d[:rpc] = sort([df; df_uti])
    return d[:rpc]
end


"""
`ng`: Sectors not included in the CFS.
"""
_set_ng!(set::Dict, d::Dict) = set[:ng] = setdiff(set[:g], unique(d[:cfs][:,:g]))


"""
`d0(r,g)`: Local supply-demand (CFS), trade that remains within the same region.

```math
\\bar{d}_{r,ng\\ni g} = \\left\\{{cfs}\\left(orig,dest,g\\right)
\\;\\vert\\; orig=dest, \\, g \\right\\}
```
Calling [`SLiDE._avg_ng`](@ref) returns ``\\bar{d}_{r,ng\\in g}``.
"""
function _share_d0!(d::Dict, set::Dict)
    df = copy(d[:cfs])
    
    df = df[df[:,:orig] .== df[:,:dest],:]
    df = edit_with(df, [Rename(:orig, :r), Deselect([:dest], "==")])
    
    d[:d0] = _avg_ng(df, set)

    print_status(:d0, d, "local supply-demand")
    return d[:d0]
end


"""
`mrt0(orig,dest,g)`: Interstate trade (CFS)
```math
\\bar{mrt}_{orig,dest,ng\\ni g} = \\left\\{{cfs}\\left(orig,dest,g\\right)
\\;\\vert\\; orig\\neq dest, \\, g \\right\\}
```
"""
function _share_mrt0!(d::Dict)
    df = copy(d[:cfs])

    d[:mrt0] = df[df[:,:orig] .!= df[:,:dest],:]
    return d[:mrt0]
end


"""
`mn0(r,g)`: National demand (CFS)
```math
\\bar{mn}_{r,ng\\ni g} = \\sum_{orig} \\bar{mrt}_{orig,dest,ng\\ni g}
```
Calling [`SLiDE._avg_ng`](@ref) returns ``\\bar{mn}_{r,ng\\in g}``.
"""
function _share_mn0!(d::Dict, set::Dict)    
    df = edit_with(combine_over(d[:mrt0], :orig), Rename(:dest, :r))
    d[:mn0] = _avg_ng(df, set)

    print_status(:mn0, d, "national demand")
    return d[:mn0]
end


"""
`xn0(r,g)`: National exports (CFS)
```math
\\bar{xn}_{r,ng\\ni g} = \\sum_{dest} \\bar{mrt}_{orig,dest,ng\\ni g}
```
Calling [`SLiDE._avg_ng`](@ref) returns ``\\bar{xn}_{r,ng\\in g}``.
"""
function _share_xn0!(d::Dict, set::Dict)
    df = edit_with(combine_over(d[:mrt0], :dest), Rename(:orig, :r))
    d[:xn0] = _avg_ng(df, set)

    print_status(:xn0, d, "national exports")
    return d[:xn0]
end


"""
```math
\\bar{x}_{r,ng\\in g} = \\dfrac{\\sum_g \\bar{x}_{r,g}}
    {\\text{length}(ng)}
```
"""
function _avg_ng(df::DataFrame, set::Dict)
    df_ng = crossjoin(
        DataFrame(g=set[:ng]),
        combine_over(copy(df), :g; fun=Statistics.sum),
    )

    df_ng[!,:value] ./= length(setdiff(set[:g], set[:ng]))
    
    return vcat(df, df_ng)
end