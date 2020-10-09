"""
    share_pce!(d::Dict)
`pce`: Regional shares of final consumption
"""
function share_pce!(d::Dict)
    println("  Calculating regional shares of final consumption")
    d[:pce] /= transform_over(d[:pce], :r)
    verify_over(d[:pce],:r) !== true && @error("PCE shares don't sum to 1.")
    return d[:pce]
end