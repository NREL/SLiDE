"""
`pce(yr,r,g)`: Regional shares of final consumption
```math
\\alpha_{yr,r,g}^{pce} = \\dfrac{\\bar{pce}_{yr,r,g}}{\\sum_{r'} \\bar{pce}_{yr,r',g}}
```
"""
function share_pce!(d::Dict)
    println("  Calculating pce(yr,r,g), regional shares of final consumption")
    d[:pce] /= transform_over(d[:pce], :r)
    verify_over(d[:pce],:r) !== true && @error("PCE shares don't sum to 1.")
    return dropnan!(d[:pce])
end