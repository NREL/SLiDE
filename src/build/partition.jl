using CSV
using DataFrames
using DelimitedFiles
using YAML
using Query

using SLiDE

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
    _partition_io!(d::Dict, set::Dict)
"""
function _partition_io!(d::Dict, set::Dict)
    println("  Partitioning id0 and ys0, supply/demand data.")
    d[:id0] = filter_with(d[:use], set)
    d[:ys0] = filter_with(d[:supply], set)

    (d[:id0], d[:ys0]) = fill_zero(d[:id0], d[:ys0])

    # Treat negative inputs as outputs.
    d[:ys0][!,:value] = d[:ys0][:,:value] - min.(0, d[:id0][:,:value])
    d[:id0][!,:value] = max.(0, d[:id0][:,:value])

    d[:id0] = dropzero(d[:id0])
    d[:ys0] = dropzero(d[:ys0])
end

"""
    _partition_a0!(d::Dict, set::Dict)
`a0`: Armington supply
"""
function _partition_a0!(d::Dict, set::Dict)
    println("  Partitioning a0, Armington supply")
    d[:a0] = combine_over(d[:fd0], :fd) + combine_over(d[:id0], :j)
    d[:a0] = _remove_imrg(d[:a0], :i => set[:imrg])
end

"""
    _partition_bopdef0!(d::Dict, set::Dict)
`bopdef0`: Balance of payments deficit
"""
function _partition_bopdef0!(d::Dict, set::Dict)
    println("  Partitioning bopdef0, balance of payments deficit")
    d[:bopdef] = fill_zero((yr = set[:yr], ))
end

"""
    _partition_cif0!(d::Dict, set::Dict)
`cif0`: CIF/FOB Adjustments on Imports
"""
function _partition_cif0!(d::Dict, set::Dict)
    println("  Partitioning CIF/FOB adjustments on imports")
    d[:cif0] = filter_with(d[:supply], (i = set[:i], j = "ciffob"))[:,[:yr,:i,:value]]
end

"""
    _partition_duty0!(d::Dict, set::Dict)
`duty0`: Import duties
"""
function _partition_duty0!(d::Dict, set::Dict)
    println("  Partitioning duty0, import duties")
    d[:duty0] = filter_with(d[:supply], (i = set[:i], j = "duties"))[:,[:yr,:i,:value]]
    d[:duty0] = _remove_imrg(d[:duty0], :i => set[:imrg])
end

"""
    _partition_fd0!(d::Dict, set::Dict)
`fd0`: Final demand
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
"""
function _partition_fs0!(d::Dict)
    println("  Partitioning fs0, household supply")
    d[:fs0] = filter_with(d[:fd0], (fd = "pce",))[:,[:yr,:i,:value]]
    d[:fs0][!,:value] .= - min.(d[:fs0][:,:value], 0)
end

# """
#     _partition_lshr0!(d::Dict)
# `lshr0`: Labor share of value added
# """
# function _partition_lshr0!(d::Dict, set::Dict)
#     va0 = edit_with(unstack(copy(d[:va0]), :va, :value),
#         [Rename(:j,:s); Replace.(Symbol.(set[:va]), missing, 0.0); Drop(:units,"all","==")])
    
#     d[:lshr0]  = va0[:,[:yr,:s,:compen]]
#     d[:lshr0] /= (va0[:,[:yr,:s,:compen]] + va0[:,[:yr,:s,:surplus]])

#     # !!!!! _partition_lshr0 needs to come after calibration.
#     # Order is: io, calibrate, share, disagg.
#     d[:lshr0][va0[:,:surplus] .< 0,:value] .== 1.0
#     dropmissing!(d[:lshr0])
# end

"""
    _partition_m0!(d::Dict, set::Dict)
`m0`: Imports
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
    _partition_md0!(d::Dict)
`md0`: Margin demand
"""
function _partition_md0!(d::Dict, set::Dict)
    println("  Partitioning md0, margin demand")
    d[:md0] = [edit_with(d[:mrg0], Add(:m, "trd")); edit_with(d[:trn0], Add(:m, "trn"))]
    d[:md0] = sort(d[:md0][:,[:yr,:i,:m,:value]])
    d[:md0] = _remove_imrg(d[:md0], :i => set[:imrg])

    d[:md0][!,:value] .= max.(d[:md0][:,:value], 0)
end

"""
    _partition_ms0!(d::Dict)
`ms0`: Margin supply
"""
function _partition_ms0!(d::Dict)
    println("  Partitioning ms0, margin supply")
    d[:ms0] = [edit_with(d[:mrg0], Add(:m, "trd")); edit_with(d[:trn0], Add(:m, "trn"))]
    d[:ms0] = sort(d[:ms0][:,[:yr,:i,:m,:value]])

    d[:ms0][!,:value] .= max.(-d[:ms0][:,:value], 0)
end

"""
    _partition_mrg0!(d::Dict, set::Dict)
`mrg0`: Trade margins
"""
function _partition_mrg0!(d::Dict, set::Dict)
    println("  Partitioning mrg0, trade margins")
    d[:mrg0] = filter_with(d[:supply], (i = set[:i], j = "margins"))[:,[:yr,:i,:value]]
end

"""
    _partition_s0!(d::Dict)
`s0`: Aggregate supply
"""
function _partition_s0!(d::Dict)
    println("  Partitioning s0, aggregate supply")
    d[:s0] = combine_over(d[:ys0], :i)
end

"""
    _partition_sbd0!(d::Dict, set::Dict)
`sbd0`: Subsidies on products
"""
function _partition_sbd0!(d::Dict, set::Dict)
    println("  Partitioning sbd0, subsidies on products")
    d[:sbd0] = filter_with(d[:supply], (i = set[:i], j = "subsidies"))[:,[:yr,:i,:value]]
    d[:sbd0] = _remove_imrg(d[:sbd0], :i => set[:imrg])
    d[:sbd0][!,:value] *= -1
end

"""
    _partition_ta0!(d::Dict)
`ta0`: Import tariff
"""
function _partition_ta0!(d::Dict)
    println("  Partitioning ta0, import tariffs")
    d[:ta0] = dropnan((d[:tax0] - d[:sbd0]) / d[:a0])
    # d[:ta0] = edit_with(d[:ta0], Drop(:units,"all","=="))
end

"""
    _partition_tax0!(d::Dict, set::Dict)
`tax0`: Taxes on products
"""
function _partition_tax0!(d::Dict, set::Dict)
    println("  Partitioning tax0, taxes on products")
    d[:tax0] = filter_with(d[:supply], (i = set[:i], j = "tax"))[:,[:yr,:i,:value]]
    d[:tax0] = _remove_imrg(d[:tax0], :i => set[:imrg])
end

"""
    _partition_tm0!(d::Dict)
`tm0`: Tax net subsidy rate on intermediate demand
"""
function _partition_tm0!(d::Dict)
    println("  Partitioning tm0, tax net subsidy rate on intermediate demand")
    d[:tm0] = dropnan(d[:duty0] / d[:m0])
    # d[:tm0] = edit_with(d[:tm0], Drop(:units,"all","=="))
end

"""
    _partition_trn0!(d::Dict, set::Dict)
`trn0`: Transportation costs
"""
function _partition_trn0!(d::Dict, set::Dict)
    println("  Partitioning trn0, transportation costs")
    d[:trn0]  = filter_with(d[:supply], (i = set[:i], j = "trncost"))[:,[:yr,:i,:value]]

    # Adjust transport margins for transport sectors according to CIF/FOB adjustments.
    # Insurance imports are specified as net of adjustments.
    d[:trn0] += edit_with(d[:cif0], Drop(:i,"ins","=="))
end

"""
    _partition_ts0!(d::Dict, set::Dict)
`ts0`: Taxes and subsidies
"""
function _partition_ts0!(d::Dict, set::Dict)
    println("  Partitioning ts0, taxes and subsidies")
    d[:ts0] = filter_with(d[:use], (i = set[:ts], j = set[:j]))
    d[:ts0][d[:ts0][:,:i] .== "subsidies", :value] *= -1  # treat negative inputs as outputs    return d
end

"""
    _partition_va0!(d::Dict, set::Dict)
`va0`: Value added
"""
function _partition_va0!(d::Dict, set::Dict)
    println("  Partitioning va0, value added")
    d[:va0] = filter_with(d[:use], (i = set[:va], j = set[:j]))
    d[:va0] = edit_with(d[:va0], Rename(:i, :va))
end

"""
    _partition_x0!(d::Dict, set::Dict)
`x0`: Exports of goods and services
"""
function _partition_x0!(d::Dict, set::Dict)
    println("  Partitioning x0, exports of goods and services")
    d[:x0] = filter_with(d[:use], (i = set[:i], j = "exports"))[:,[:yr,:i,:value]]
    d[:x0] = _remove_imrg(d[:x0], :i => set[:imrg])
end

"""
    _partition_y0!(d::Dict, set::Dict)
`y0`: Gross output
"""
function _partition_y0!(d::Dict, set::Dict)
    println("  Partitioning y0, gross output")
    d[:y0] = combine_over(d[:ys0], :j) + d[:fs0] - combine_over(d[:ms0], :m)
    d[:y0] = _remove_imrg(d[:y0], :i => set[:imrg])
end

"""
    partition!(d::Dict, set::Dict)
"""
function partition!(d::Dict, set::Dict)

    [d[k] = edit_with(filter_with(d[k], (yr = set[:yr],)), [Drop(:units,"all","==")])
        for k in [:supply, :use]]

    _partition_io!(d, set)
    _partition_fd0!(d, set)
    _partition_ts0!(d, set)
    _partition_va0!(d, set)
    _partition_x0!(d, set)

    _partition_cif0!(d, set)
    _partition_duty0!(d, set)
    _partition_mrg0!(d, set)
    _partition_sbd0!(d, set)
    _partition_tax0!(d, set)

    _partition_m0!(d, set)   # cif0
    _partition_trn0!(d, set) # cif0

    _partition_fs0!(d)       # fd0
    _partition_s0!(d)        # ys0
    _partition_md0!(d, set)  # mrg0, trn0
    _partition_ms0!(d)       # mrg0, trn0

    _partition_y0!(d, set)   # ms0, fs0, ys0
    _partition_a0!(d, set)   # fd0, id0

    _partition_ta0!(d)       # a0, sbd0, tax0
    _partition_tm0!(d)       # duty0, m0

    # _partition_lshr0!(d, set) # va0
    return (d, set)
end