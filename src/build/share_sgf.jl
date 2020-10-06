"""
    function share_sgf!(d::Dict)
`sgf`: State Government Finance data.

Note: D.C. is not included in the original data set, so assume its SGFs equal Maryland's.
"""
function share_sgf!(d::Dict)
    println("  Calculating regional shares of State Government Finance data")
    d[:sgf] = d[:sgf] / transform_over(d[:sgf], :r)
    verify_over(d[:sgf],:r) !== true && @error("SGF shares don't sum to 1.")
    return dropnan!(d[:sgf])
end