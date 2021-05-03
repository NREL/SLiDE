"""
`utd(yr,r,g,t)`: Share of total trade by region.

```math
\\alpha_{yr,r,g,t}^{utd}
=
\\begin{cases}
\\dfrac{           \\bar{utd}_{yr,r ,g,t}}
       {\\sum_{r'} \\bar{utd}_{yr,r',g,t}}        & notrd\\ni g
\\\\
\\dfrac{\\sum_{yr'}    \\bar{utd}_{yr',r ,g,t}}
       {\\sum_{yr',r'} \\bar{utd}_{yr',r',g,t}}   & notrd\\in g
\\end{cases}
```
"""
function share_utd!(d::Dict, set::Dict)
    d[:utd] = fill_zero(d[:utd])
    df = d[:utd] / transform_over(d[:utd], :r)
    
    df_yr = transform_over(d[:utd], :yr) / transform_over(d[:utd], [:yr,:r])
    df[isnan.(df[:,:value]), :value] .= df_yr[isnan.(df[:,:value]),:value]
    
    # Check import and export shares.
    verify_over(filter_with(df, (t = "imports",)), :r) !== true && @error("Import shares don't sum to 1.")
    verify_over(filter_with(df, (t = "exports",)), :r) !== true && @error("Export shares don't sum to 1.")
    
    d[:utd] = dropnan(dropzero(df))
    _set_notrd!(set, d)
    
    print_status(:utd, d, "share of total trade by region")
    return d[:utd]
end


" `notrd`: Goods/sectors not included in imports/exports."
function _set_notrd!(set::Dict, d::Dict)
    if !haskey(d, :notrd)
        !haskey(d, :utd) && @error("shr[:utd] required to find set[:notrd]")
        set[:notrd] = setdiff(set[:g], d[:utd][:,:g])
    end
    return set[:notrd]
end