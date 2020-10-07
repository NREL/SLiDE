using CSV
using DataFrames
using DelimitedFiles
using YAML
using Query
using Base

"""
    function disagg!(d_shr::Dict, d_cal::Dict)
"""
function disagg!(d::Dict, set::Dict; save = true, overwrite = false)
    
    d_read = read_build("disagg"; save = save, overwrite = overwrite);
    if !isempty(d_read)
        [d[k] = v for (k,v) in d_read]
        return d
    end
    
    # d = merge(d, Dict(
    #     :r => fill_with((r = set[:r],), 1.0),
    #     (:yr,:r,:g) => fill_with((yr = set[:yr], r = set[:r], g = set[:g]), 1.0)))
    # d = merge(d, copy(d_shr), copy(d_cal))

    d[:ys0] = _disagg_ys0!(d)
    d[:id0] = _disagg_id0!(d)
    d[:ty0] = _disagg_ty0(d, set)
    d[:va0] = _disagg_va0!(d, set)
    d[:ld0] = _disagg_ld0!(d)
    d[:kd0] = _disagg_kd0(d)

    d[:fd0] = _disagg_fdcat!(d)       # not state model
    d[:g0] = _disagg_g0!(d)
    d[:i0] = _disagg_i0!(d)
    d[:cd0] = _disagg_cd0!(d)
    d[:c0] = _disagg_c0!(d)

    d[:yh0_temp] = _disagg_yh0!(d)
    d[:fe0] = _disagg_fe0!(d)         # not state model
    d[:x0_temp] = _disagg_x0!(d, set)
    d[:s0_temp] = _disagg_s0!(d)
    d[:a0] = _disagg_a0!(d)           # BE CAREFUL. DON'T REPLACE ARMINGTON SUPPLY
    d[:ta0] = _disagg_ta0!(d)
    d[:tm0] = _disagg_tm0!(d)
    d[:thetaa] = _disagg_thetaa!(d)   # not in state model

    d[:m0] = _disagg_m0!(d)
    d[:md0] = _disagg_md0!(d)
    d[:rx0_temp] = _disagg_rx0!(d)

    d[:pt0_temp] = _disagg_pt0!(d)    # not in state model
    d[:diff] = _disagg_diff!(d)       # not in state model

    d[:rx0] = _disagg_rx0!(d)
    d[:s0] = _disagg_s0!(d)
    d[:x0] = _disagg_x0!(d, set)
    d[:yh0] = _disagg_yh0!(d)
    d[:bopdef0] = _disagg_bopdef0!(d)

    d[:pt0] = _disagg_pt0!(d)
    d[:dc0] = _disagg_dc0!(d)

    d[:dd0max] = _disagg_dd0max(d)
    d[:dd0] = _disagg_dd0!(d)
    d[:nd0] = _disagg_nd0!(d)
    d[:dm0] = _disagg_dm0!(d)
    d[:nm0] = _disagg_nm0!(d)
    d[:xd0] = _disagg_xd0!(d)
    d[:xn0] = _disagg_xn0!(d)

    d[:hhadj] = _disagg_hhadj!(d)

    d_save = Dict()
    d_save[:a0]  = ensurenames(d[:a0], [:yr, :r, :g, :value])
    d_save[:bopdef0] = ensurenames(d[:bopdef0], [:yr, :r, :value])
    d_save[:c0]  = ensurenames(d[:c0], [:yr, :r, :value])
    d_save[:cd0] = ensurenames(d[:cd0], [:yr, :r, :s, :value])
    d_save[:dd0] = ensurenames(d[:dd0], [:yr, :r, :g, :value])
    d_save[:dm0] = ensurenames(d[:dm0], [:yr, :r, :g, :m, :value])
    d_save[:g0]  = ensurenames(d[:g0], [:yr, :r, :s, :value])
    d_save[:hhadj] = ensurenames(d[:hhadj], [:yr, :r, :value])
    d_save[:i0]  = ensurenames(d[:i0], [:yr, :r, :s, :value])
    d_save[:id0] = ensurenames(d[:id0], [:yr, :r, :g, :s, :value])
    d_save[:kd0] = ensurenames(d[:kd0], [:yr, :r, :s, :value])
    d_save[:ld0] = ensurenames(d[:ld0], [:yr, :r, :s, :value])
    d_save[:m0]  = ensurenames(d[:m0], [:yr, :r, :g, :value])
    d_save[:md0] = ensurenames(d[:md0], [:yr, :r, :m, :g, :value])
    d_save[:nd0] = ensurenames(d[:nd0], [:yr, :r, :g, :value])
    d_save[:nm0] = ensurenames(d[:nm0], [:yr, :r, :g, :m, :value])
    d_save[:rx0] = ensurenames(d[:rx0], [:yr, :r, :g, :value])
    d_save[:s0]  = ensurenames(d[:s0], [:yr, :r, :g, :value])
    d_save[:ta0] = ensurenames(d[:ta0], [:yr, :r, :g, :value])
    d_save[:tm0] = ensurenames(d[:tm0], [:yr, :r, :g, :value])
    d_save[:ty0] = ensurenames(d[:ty0], [:yr, :r, :s, :value])
    d_save[:x0]  = ensurenames(d[:x0], [:yr, :r, :g, :value])
    d_save[:xd0] = ensurenames(d[:xd0], [:yr, :r, :g, :value])
    d_save[:xn0] = ensurenames(d[:xn0], [:yr, :r, :g, :value])
    d_save[:yh0] = ensurenames(d[:yh0], [:yr, :r, :s, :value])
    d_save[:ys0] = ensurenames(d[:ys0], [:yr, :r, :s, :g, :value])
    
    write_build("disagg", d_save; save = save)
    return d_save
end

"`ys0(yr,r,s,g)`: Regional sectoral output"
function _disagg_ys0!(d::Dict)
    println("  Disaggregating ys0(yr,r,s,g), regional sectoral output")
    :r in propertynames(d[:ys0]) && (return d[:ys0])

    d[:ys0] = d[:region] * d[:ys0]
    return d[:ys0]
end

"`id0(yr,r,g,s)`: Regional intermediate demand"
function _disagg_id0!(d::Dict)
    println("  Disaggregating id0(yr,r,g,s), regional intermediate demand")
    :r in propertynames(d[:id0]) && (return d[:id0])

    d[:id0] = d[:region] * d[:id0]
    return d[:id0]
end

"`ty0_rev`: Production tax payments"
function _disagg_ty0_rev(d::Dict, set::Dict)
    if :va in propertynames(d[:va0])
        d[:va0] = edit_with(unstack(copy(d[:va0]), :va, :value),
            Replace.(Symbol.(set[:va]), missing, 0.0))
    end
    d[:region] * d[:va0][:,[:yr,:s,:othtax]]
end

"`ty0(yr,r,s)`: Production tax rate"
function _disagg_ty0(d::Dict, set::Dict)
    println("  Disaggregating ty0(yr,r,s), production tax rate")
    # !!!! test that returns error if va0 has already been edited.
    
    ty0_rev = _disagg_ty0_rev(d, set)
    df = dropnan(ty0_rev / combine_over(d[:ys0], :g))
    return df
end

"`va0`: Regional value added"
function _disagg_va0!(d::Dict, set::Dict)
    println("  Disaggregating va0, regional share of value added.")
    # If va0 has already been edited, don't edit it again.
    :r in propertynames(d[:va0]) && (return d[:va0])

    if :va in propertynames(d[:va0])
        d[:va0] = edit_with(unstack(copy(d[:va0]), :va, :value), Replace.(Symbol.(set[:va]), missing, 0.0))
    end

    # !(:compen in propertynames(d[:va0])) && return d[:va0]

    df = d[:va0][:,[:yr,:s,:compen]] + d[:va0][:,[:yr,:s,:surplus]]
    d[:va0] = d[:region] * df
    return d[:va0]
end

"`ld0`: Labor demand"
function _disagg_ld0!(d::Dict)
    println("  Disaggregating ld0(yr,r,s), labor demand")
    d[:ld0] = d[:labor] * d[:va0]
    return d[:ld0]
end

"`kd0`: Capital demand"
_disagg_kd0(d::Dict) = d[:va0] - d[:ld0]

function _disagg_fdcat!(d::Dict)
    # !!!! check if this has been edited.
    x = Map(joinpath("crosswalk","fd.csv"), [:fd], [:fdcat], [:fd], [:fdcat], :inner)

    # df = copy(d[:fd0])
    if !(:fdcat in propertynames(d[:fd0]))
        d[:fd0] = edit_with(d[:fd0], x)
        d[:fd0] = combine_over(d[:fd0], :fd)
    end
    return d[:fd0]
end

"`g0(yr,r,s)`: National government demand"
function _disagg_g0!(d::Dict)
    println("  Disaggregating g0(yr,r,s), national government demand")
    cols = [:yr,:r,:g,:value]

    df_fd0 = ensurenames(d[:fd0], [:yr,:fdcat,:g,:value])
    df = filter_with(df_fd0, (fdcat = "G",))[:,[:yr,:g,:value]]
    d[:g0] = ensurenames(d[:sgf], cols) * df
    # d[:g0] = edit_with(df, Rename(:s,:g))
    return d[:g0]
end

"`i0(yr,g)`: National investment demand"
function _disagg_i0!(d::Dict)
    println("  Disaggregating i0(yr,r,s), national investment demand")
    cols = [:yr,:r,:g,:value]
    df_fd0 = ensurenames(d[:fd0], [:yr,:fdcat,:g,:value])
    df = filter_with(df_fd0, (fdcat = "I",))[:,[:yr,:g,:value]]
    d[:i0] = ensurenames(d[:region], cols) * df
    # d[:i0] = edit_with(df, Rename(:s,:g))
    return d[:i0]
end

"`cd0(yr,r,s)`: National final consumption"
function _disagg_cd0!(d::Dict)
    println("  Disaggregating cd0(yr,r,s), national final consumption")
    cols = [:yr,:r,:g,:value]
    df_fd0 = ensurenames(d[:fd0], [:yr,:fdcat,:g,:value])
    df = filter_with(df_fd0, (fdcat = "C",))[:,[:yr,:g,:value]]
    d[:cd0] = ensurenames(d[:pce], cols) * df
    # d[:cd0] = edit_with(df, Rename(:s,:g))
    return d[:cd0]
end

"`c0(yr,r)`: Total final household consumption"
function _disagg_c0!(d::Dict)
    println("  Disaggregating c0(yr,r), total final household consumption")
    !(:cd0 in keys(d)) && _disagg_cd0!(d)
    d[:c0] = combine_over(d[:cd0], :g)
    return d[:c0]
end

############################################################################################
"`yh0(yr,r,s)`: Household production"
function _disagg_yh0!(d::Dict)
    println("  Disaggregating yh0(yr,r,s), household production")
    if !(:diff in keys(d))
        df_region = ensurenames(d[:region], [:yr,:r,:g,:value])
        df_fs0 = ensurenames(d[:fs0], [:yr,:g,:value])
        d[:yh0] = df_region * df_fs0
        # d[:yh0] = edit_with(df, Rename(:s,:g))
    else
        d[:yh0] = dropmissing(d[:yh0] + d[:diff])
    end
    return d[:yh0]
end

"`fe0(yr,r)`: Total factor supply"
function _disagg_fe0!(d::Dict)
    println("  Disaggregating fe0, total factor supply")
    d[:fe0] = combine_over(d[:va0], :s)
    return d[:fe0]
end

"`x0(yr,r,g)`: Foreign exports"
function _disagg_x0!(d::Dict, set::Dict)
    println("  Disaggregating x0(yr,r,g), foreign exports")
    if !(:diff in keys(d))
        cols = [:yr,:r,:g,:value]

        set[:notrd] = :s in propertynames(d[:utd]) ? setdiff(set[:s], d[:utd][:,:s]) :
            setdiff(set[:g], d[:utd][:,:g])
        
        df_exports = edit_with(filter_with(copy(d[:utd]), (t = "exports",)),
            [Drop.([:t,:units],"all","=="); Rename(:s,:g)])
        df_region = filter_with(ensurenames(d[:region], cols), (g = set[:notrd],))

        df_trd = dropmissing(df_exports * d[:x0])
        df_notrd = df_region * d[:x0]

        d[:x0] = [df_trd; df_notrd]
    else
        d[:x0] = dropmissing(d[:x0] + d[:diff])
    end

    return d[:x0]
end

"`s0(yr,r,g)`: Total supply"
function _disagg_s0!(d::Dict)
    println("  Disaggregating s0(yr,r,g), total supply")
    if !(:diff in keys(d))
        d[:s0] = combine_over(d[:ys0], :s) + d[:yh0]
    else
        d[:s0] = dropmissing(d[:s0] + d[:diff])
    end
    return d[:s0]
end

"`a0(yr,r,g)`: Domestic absorption"
function _disagg_a0!(d::Dict)
    cols = [:yr,:r,:g,:value]
    println("  Disaggregating a0(yr,r,g), domestic absorption")

    d[:a0] = dropmissing(d[:cd0] + d[:g0] + d[:i0] + combine_over(d[:id0], :s))
    return ensurenames!(d[:a0], cols)
end

"`ta0(yr,r,g)`: Absorption taxes"
function _disagg_ta0!(d::Dict)
    println("  Disaggregating ta0(yr,r,g), absorption taxes")
    d[:ta0] = ensurenames(d[:ta0] * d[:r], [:yr,:r,:g,:value])
    return d[:ta0]
end

"`tm0(yr,r,g)`: Import taxes"
function _disagg_tm0!(d::Dict)
    println("  Disaggregating tm0(yr,r,g), import taxes")
    d[:tm0] = ensurenames(d[:tm0] * d[:r], [:yr,:r,:g,:value])
    return d[:tm0]
end

"`thetaa(yr,r,g)`: Share of regional absorption"
function _disagg_thetaa!(d::Dict)
    println("  Disaggregating thetaa(yr,r,g), share of regional absorption")
    d[:thetaa] = dropnan(d[:a0] / transform_over(d[:a0], :r))
    return d[:thetaa]
end

"`m0(yr,r,g)`: Foreign Imports"
function _disagg_m0!(d::Dict)
    println("  Disaggregating m0(yr,r,g), foreign imports")
    d[:m0] = d[:thetaa] * d[:m0]
    return d[:m0]
end

"`md0(yr,r,m,g)`: Margin demand"
function _disagg_md0!(d::Dict)
    println("  Disaggregating md0(yr,r,m,g), margin demand")
    d[:md0] = dropmissing(d[:thetaa] * d[:md0])
    return d[:md0]
end

"`rx0(yr,r,g)`: re-exports"
function _disagg_rx0!(d::Dict)
    println("  Disaggregating rx0(yr,r,g), re-exports")
    if !(:diff in keys(d))
        d[:rx0] = d[:x0] - d[:s0]
        d[:rx0][round.(d[:rx0][:,:value]; digits = 10) .< 0, :value] .= 0.0
    else
        d[:rx0] = d[:rx0] + d[:diff]
    end

    return dropmissing(d[:rx0])
end


# ******************************************************************************************
"`pta0`"
_disagg_pta0(d::Dict) = dropmissing(((d[:yr,:r,:g] - d[:ta0]) * d[:a0]) + d[:rx0])

"`ptm0`"
_disagg_ptm0(d::Dict) = dropmissing(((d[:yr,:r,:g] + d[:tm0]) * d[:m0]) + combine_over(d[:md0], :m))

"`dc0`"
function _disagg_dc0!(d::Dict)
    d[:dc0] = dropmissing((d[:s0] - d[:x0] + d[:rx0]))
    d[:dc0][!,:value] .= round.(d[:dc0][:,:value]; digits = 10)
    return d[:dc0]
end

"`pt0`"
function _disagg_pt0!(d::Dict)
    df_pta0 = _disagg_pta0(d)
    df_ptm0 = _disagg_ptm0(d)
    d[:pt0] = df_pta0 - df_ptm0
    d[:pt0][!,:value] .= round.(d[:pt0][:,:value]; digits = 10)
    return d[:pt0]
end

"`diff`:"
function _disagg_diff!(d::Dict)
    df = copy(d[:pt0])
    df[!,:value] .= - min.(0, df[:,:value])
    d[:diff] = edit_with(df, Drop(:value,0.0,"=="))
end

"`bopdef0(yr,r)`: Balance of payments (closure parameter)"
function _disagg_bopdef0!(d::Dict)
    println("  Disaggregating bopdef0(yr,r), balance of payments (closure parameter)")
    cols = [:yr,:r,:value]
    d[:bopdef0] = combine_over((d[:m0] - d[:x0]), :g)
    return ensurenames!(d[:bopdef0], cols)
end

"`gm`: Commodities employed in margin supply"
function _disagg_gm!(d::Dict, set::Dict)
    cols = [:g,:yr]
    ms0_sum = ensurenames(combine_over(d[:ms0], [:yr,:m]), cols)
    md0_sum = ensurenames(combine_over(d[:md0], [:yr,:m]), cols)

    ms0_sum[!,:value] .= ms0_sum[:,:value] .!= 0.0
    md0_sum[!,:value] .= md0_sum[:,:value] .!= 0.0

    gm = ms0_sum + md0_sum
    set[:gm] = gm[gm[:,:value] .> 0, :g]
    return set[:gm]
end

"`dd0max(yr,r,g)`: Maximum regional demand from local market"
function _disagg_dd0max(d::Dict)
    println("  Disaggregating dd0max(yr,r,g), maximum regional demand from local market")
    cols = [:yr,:r,:g,:value]
    df = SLiDE._join_to_operate(d[:pt0],d[:dc0]; colnames = [:pt0,:dc0])
    df[!,:value] = min.(df[:,:pt0], df[:,:dc0])
    d[:dd0max] = copy(df)[:,cols]
    return d[:dd0max]
end

"`nd0max(yr,r,g)`: Maximum regional demand from national market"
function _disagg_nd0max(d::Dict)
    println("  Disaggregating nd0max(yr,r,g), maximum regional demand from national market")
    cols = [:yr,:r,:g,:value]
    df = SLiDE._join_to_operate(d[:pt0],d[:dc0]; colnames = [:pt0,:dc0])
    df[!,:value] = min.(df[:,:pt0], df[:,:dc0])
    d[:nd0max] = copy(df)[:,cols]
    return d[:nd0max]
end

"`dd0min(yr,r,g)`: Minimum regional demand from local market"
_disagg_dd0min(d::Dict) = d[:pt0] - _disagg_dd0max(d)

"`nd0min(yr,r,g)`: Minimum regional demand from national market"
_disagg_nd0min(d::Dict) = d[:pt0] - _disagg_nd0max(d)

"`dd0_(yr,r,g)`: Regional demand from local market"
function _disagg_dd0!(d::Dict)
    println("  Disaggregating dd0_(yr,r,g), regional demand from local market")
    df_dd0max = _disagg_dd0max(d)
    d[:dd0] = df_dd0max * d[:rpc]
    return d[:dd0]
end

"`nd0_(yr,r,g)`: Regional demand from national market"
function _disagg_nd0!(d::Dict)
    println("  Disaggregating nd0_(yr,r,g), regional demand from national market")
    d[:nd0] = d[:pt0] - d[:dd0]
    d[:nd0][!,:value] .= round.(d[:nd0][:,:value]; digits = 10)
    return d[:nd0]
end

# ##########################################################################################

"`mrgshr(yr,r,m)`: Share of margin demand by region"
function _disagg_mrgshr(d::Dict)
    df = combine_over(d[:md0], :g)
    df = df / transform_over(df, :r)
    return df
end

"`totmrgsupply(yr,r,m,g)`: Designate total supply of margins"
function _disagg_totmrgshr!(d::Dict)
    cols = [:yr,:r,:m,:g,:value]
    d[:totmrgshr] = _disagg_mrgshr(d) * d[:ms0]
    return ensurenames!(d[:totmrgshr], cols)
end

"`shrtrd(yr,r,m,g)`: Share of margin total by margin type"
function _disagg_shrtrd!(d::Dict)
    cols = [:yr,:r,:m,:g,:value]
    df = (:totmrgshr in keys(d)) ? d[:totmrgshr] : _disagg_totmrgshr!(d)
    d[:shrtrd] = dropnan(df / transform_over(df, :m))
    return ensurenames!(d[:shrtrd], cols)
end

"`dm0(yr,r,g,m)`: Margin supply from the local market"
function _disagg_dm0!(d::Dict)
    println("  Disaggregating dm0(yr,r,g,m), margin supply from the local market")
    cols = [:yr,:r,:m,:g,:value]
    !(:totmrgshr in keys(d)) && _disagg_totmrgshr!(d)
    !(:shrtrd in keys(d)) && _disagg_shrtrd!(d)

    dm1 = dropmissing(d[:totmrgshr] * d[:rpc])
    dm2 = dropmissing((d[:shrtrd] * d[:dc0]) - d[:dd0])

    df = SLiDE._join_to_operate(dm1, dm2; colnames = [:dm1,:dm2])
    df[!,:value] .= min.(df[:,:dm1], df[:,:dm2])
    d[:dm0] = df[:,cols]
    return d[:dm0]
end

"`nm0(yr,r,g,m)`: Margin demand from the national market"
function _disagg_nm0!(d::Dict)
    println("  Disaggregating nm0(yr,r,g,m), margin demand from the national market")
    d[:nm0] = d[:totmrgshr] - d[:dm0]
    return d[:nm0]
end

"`xd0(yr,r,g)`: Regional supply to local market"
function _disagg_xd0!(d::Dict)
    println("  Disaggregating xd0(yr,r,g), regional supply to local market")
    d[:xd0] = combine_over(d[:dm0], :m) + d[:dd0]
    return d[:xd0]
end

"`xn0(yr,r,g)`: Regional supply to national market"
function _disagg_xn0!(d::Dict)
    println("  Disaggregating xn0(yr,r,g), regional supply to national market")
    d[:xn0] = d[:s0] + d[:rx0] - d[:xd0] - d[:x0]
    return d[:xn0]
end

"`hhadj`: Household adjustment"
function _disagg_hhadj!(d::Dict)
    println("  Disaggregating hhadj, household adjustment")
    dh = Dict(k => edit_with(copy(d[k]), Rename(:g,:s))
        for k in [:c0,:ld0,:kd0,:yh0,:bopdef0,:ta0,:a0,:tm0,:ty0,:g0,:i0,:m0])
    dh[:ys0] = copy(d[:ys0])

    d[:hhadj] = dh[:c0] -
        combine_over(dh[:ld0] + dh[:kd0] + dh[:yh0], :s) - dh[:bopdef0] -
        combine_over(dh[:ta0]*dh[:a0] + dh[:tm0]*dh[:m0] + dh[:ty0]*combine_over(dh[:ys0],:g), :s) +
        combine_over(dh[:g0] + dh[:i0], :s)
    
    return d[:hhadj]
end