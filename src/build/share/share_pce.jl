"""
`pce(yr,r,g)`: Regional shares of final consumption
```math
\\alpha_{yr,r,g}^{pce} = \\dfrac{\\bar{pce}_{yr,r,g}}{\\sum_{r'} \\bar{pce}_{yr,r',g}}
```
"""
function share_pce!(d::Dict)
    d[:pce] /= transform_over(d[:pce], :r)
    
    verify_over(d[:pce], :r) !== true && @error("PCE shares don't sum to 1.")
    
    print_status(:pce, [:yr,:r,:g], "regional shares of final consumption")
    return dropnan!(d[:pce])
end