"""
`sgf(yr,r,g)`: State Government Finance data.
```math
\\alpha_{yr,r,g}^{sgf} = \\dfrac{\\bar{sgf}_{yr,r,g}}{\\sum_{r'} \\bar{sgf}_{yr,r',g}}
```
Note: D.C. is not included in the original data set.
Assume its SGF data is equal to Maryland's.
"""
function share_sgf!(d::Dict)
    println("  Calculating sgf(yr,r,g), regional shares of State Government Finance data")
    d[:sgf] = d[:sgf] / transform_over(d[:sgf], :r)
    verify_over(d[:sgf],:r) !== true && @error("SGF shares don't sum to 1.")
    return dropnan!(d[:sgf])
end