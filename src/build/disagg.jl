using CSV
using DataFrames
using DelimitedFiles
using YAML
using Query

using SLiDE
using Base

# ******************************************************************************************
include(joinpath(SLIDE_DIR,"calibrate","data_temp","check_share.jl"))
# io = bio;
cal = bcal;
# shr = bshr;
delete!(shr,:va0)

d = Dict()

d_set = Dict(:r => fill_with((r = set[:r],), 1.0),
    (:yr,:r,:g) => fill_with((yr = set[:yr], r = set[:r], g = set[:g]), 1.0))
d = merge(d_set, cal, shr, Dict(:ta0 => io[:ta0], :tm0 => io[:tm0]))

# disagg = Dict()
# disagg_check = Dict()

# df1 = Dict()
# df1[:r] = fill_with((r = set[:r],), 1.0)
# df1[:yr,:r,:g] = fill_with((yr = set[:yr], r = set[:r], g = set[:g]), 1.0)

# ******************************************************************************************
"`ys0(yr,r,s,g)`: Regional sectoral output"
function _disagg_ys0!(d::Dict)
    d[:ys0] = d[:region] * d[:ys0]
    return d[:ys0]
end

"`id0`: Regional intermediate demand"
function _disagg_id0!(d::Dict)
    d[:id0] = d[:region] * d[:id0]
    return d[:id0]
end

"`ty0_rev`: Production tax payments"
_disagg_ty0_rev(d::Dict) = d[:region] * d[:va0][:,[:yr,:s,:othtax]]

"`ty0`: Production tax rate"
function _disagg_ty0(d::Dict)
    # !!!! test that returns error if va0 has already been edited.
    ty0_rev = _disagg_ty0_rev(d)
    df = dropnan(ty0_rev / combine_over(d[:ys0], :g))
    return df
end

"`va0`: Regional value added"
function _disagg_va0!(d::Dict)
    !(:compen in propertynames(d[:va0])) && return d[:va0]
    df = d[:va0][:,[:yr,:s,:compen]] + d[:va0][:,[:yr,:s,:surplus]]
    d[:va0] = d[:region] * df
    return d[:va0]
end

"`ld0`: Labor demand"
function _disagg_ld0!(d::Dict)
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

"`g0(yr,g)`: National government demand"
function _disagg_g0!(d::Dict)
    cols = [:yr,:r,:g,:value]

    df_fd0 = ensurenames(d[:fd0], [:yr,:fdcat,:g,:value])
    df = filter_with(df_fd0, (fdcat = "G",))[:,[:yr,:g,:value]]
    d[:g0] = ensurenames(d[:sgf], cols) * df
    # d[:g0] = edit_with(df, Rename(:s,:g))
    return d[:g0]
end

"`i0(yr,g)`: National investment demand"
function _disagg_i0!(d::Dict)
    cols = [:yr,:r,:g,:value]
    df_fd0 = ensurenames(d[:fd0], [:yr,:fdcat,:g,:value])
    df = filter_with(df_fd0, (fdcat = "I",))[:,[:yr,:g,:value]]
    d[:i0] = ensurenames(d[:region], cols) * df
    # d[:i0] = edit_with(df, Rename(:s,:g))
    return d[:i0]
end

"`cd0(yr,g)`: National final consumption"
function _disagg_cd0!(d::Dict)
    cols = [:yr,:r,:g,:value]
    df_fd0 = ensurenames(d[:fd0], [:yr,:fdcat,:g,:value])
    df = filter_with(df_fd0, (fdcat = "C",))[:,[:yr,:g,:value]]
    d[:cd0] = ensurenames(d[:pce], cols) * df
    # d[:cd0] = edit_with(df, Rename(:s,:g))
    return d[:cd0]
end

"`c0(yr,r)`: Total final household consumption"
function _disagg_c0!(d::Dict)
    !(:cd0 in keys(d)) && _disagg_cd0!(d)
    d[:c0] = combine_over(d[:cd0], :g)
    return d[:c0]
end

############################################################################################
"`yh0(yr,r,s)`: Household production"
function _disagg_yh0!(d::Dict)
    if !(:diff in keys(d))
        df = d[:region] * d[:fs0]
        d[:yh0] = edit_with(df, Rename(:s,:g))
    else
        d[:yh0] = dropmissing(d[:yh0] + d[:diff])
    end
    return d[:yh0]
end

"`fe0(yr,r)`: Total factor supply"
function _disagg_fe0!(d::Dict)
    d[:fe0] = combine_over(d[:va0], :s)
    return d[:fe0]
end

"`x0(yr,r,g)`: Foreign exports"
function _disagg_x0!(d::Dict)
    if !(:diff in keys(d))
        cols = [:yr,:r,:g,:value]
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
    if !(:diff in keys(d))
        d[:s0] = combine_over(d[:ys0], :s) + d[:yh0]
    else
        d[:s0] = dropmissing(d[:s0] + d[:diff])
    end
    return d[:s0]
end

"`a0(yr,r,g)`: Domestic absorption"
function _disagg_a0!(d::Dict)
    d[:a0] = dropmissing(d[:cd0] + d[:g0] + d[:i0] + combine_over(d[:id0], :s))
    return d[:a0]
end

"`ta0(yr,r,g)`: Absorption taxes"
function _disagg_ta0!(d::Dict)
    d[:ta0] = ensurenames(d[:ta0] * d[:r], [:yr,:r,:g,:value])
    return d[:ta0]
end

"`tm0(yr,r,g)`: Import taxes"
function _disagg_tm0!(d::Dict)
    d[:tm0] = ensurenames(d[:tm0] * d[:r], [:yr,:r,:g,:value])
    return d[:tm0]
end

"`thetaa(yr,r,g)`: Share of regional absorption"
function _disagg_thetaa!(d::Dict)
    d[:thetaa] = dropnan(d[:a0] / transform_over(d[:a0], :r))
    return d[:thetaa]
end

"`m0(yr,r,g)`: Foreign Imports"
function _disagg_m0!(d::Dict)
    d[:m0] = d[:thetaa] * d[:m0]
    return d[:m0]
end

"`md0(yr,r,m,g)`: Margin demand"
function _disagg_md0!(d::Dict)
    d[:md0] = dropmissing(d[:thetaa] * d[:md0])
    return d[:md0]
end

function _disagg_rx0!(d::Dict)
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
    return d[:dc0]
end

"`pt0`"
function _disagg_pt0!(d::Dict)
    df_pta0 = _disagg_pta0(d)
    df_ptm0 = _disagg_ptm0(d)
    d[:pt0] = df_pta0 - df_ptm0
    return d[:pt0]
end

"`diff`:"
function _disagg_diff!(d::Dict)
    df = copy(d[:pt0])
    df[!,:value] .= - min.(0, df[:,:value])
    d[:diff] = edit_with(df, Drop(:value,0.0,"=="))
end

"`bopdef0(yr,r)`: Balance of payments (closure parameter)"
_disagg_bopdef0(d::Dict) = combine_over((d[:m0] - d[:x0]), :g)

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

# "`dd0max(yr,r,g)`: Maximum regional demand from local market"
# function _disagg_dd0max(d::Dict)
#     # df_pt0 = _disagg_pt0(d)
#     # df_dc0 = _disagg_dc0(d)
#     df = copy(d[:yr,:r,:g])
#     df[!,:value] = min.(d[:pt0][:,:value], d[:dc0][:,:value])
#     d[:dd0max] = df
#     return d[:dd0max]
# end

# "`nd0max(yr,r,g)`: Maximum regional demand from national market"
# function _disagg_nd0max!(d::Dict)
#     d[:nd0max] = copy(d[:dd0max])
#     return d[:nd0max]
# end

"`dd0max(yr,r,g)`: Maximum regional demand from local market"
function _disagg_dd0max(d::Dict)
    df = copy(d[:yr,:r,:g])
    df[!,:value] = min.(d[:pt0][:,:value], d[:dc0][:,:value])
    return df
end

"`nd0max(yr,r,g)`: Maximum regional demand from national market"
function _disagg_nd0max(d::Dict)
    df = copy(d[:yr,:r,:g])
    df[!,:value] = min.(d[:pt0][:,:value], d[:dc0][:,:value])
    return df
end

"`dd0min(yr,r,g)`: Minimum regional demand from local market"
_disagg_dd0min(d::Dict) = d[:pt0] - _disagg_dd0max(d)

"`nd0min(yr,r,g)`: Minimum regional demand from national market"
_disagg_nd0min(d::Dict) = d[:pt0] - _disagg_nd0max(d)

"`dd0_(yr,r,g)`: Regional demand from local market"
function _disagg_dd0!(d::Dict)
    df_dd0max = _disagg_dd0max(d)
    d[:dd0] = df_dd0max * d[:rpc]
    return d[:dd0]
end

"`nd0_(yr,r,g)`: Regional demand from national market"
function _disagg_nd0!(d::Dict)
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

"`totmargsupply(yr,r,m,g)`: Designate total supply of margins"
_disagg_totmrgshr(d::Dict) = _disagg_mrgshr(d) * d[:ms0]

"`shrtrd(yr,r,m,g)`: Share of margin total by margin type"
function _disagg_shrtrd(d::Dict)
    df = _disagg_totmrgshr(d)
    df = dropnan(df / transform_over(df, :m))
    return df
end





disagg = Dict()
disagg[:ys0] = _disagg_ys0!(d)
disagg[:id0] = _disagg_id0!(d)
disagg[:ty0] = _disagg_ty0(d)
disagg[:va0] = _disagg_va0!(d)
disagg[:ld0] = _disagg_ld0!(d)
disagg[:kd0] = _disagg_kd0(d)
disagg[:fd0] = _disagg_fdcat!(d)    # not state model
disagg[:g0] = _disagg_g0!(d)
disagg[:i0] = _disagg_i0!(d)
disagg[:cd0] = _disagg_cd0!(d)
disagg[:c0] = _disagg_c0!(d)

disagg[:yh0_temp] = _disagg_yh0!(d)
disagg[:fe0] = _disagg_fe0!(d)      # not state model
disagg[:x0_temp] = _disagg_x0!(d)
disagg[:s0_temp] = _disagg_s0!(d)
disagg[:a0] = _disagg_a0!(d)        # BE CAREFUL. DON'T REPLACE ARMINGTON SUPPLY
disagg[:ta0] = _disagg_ta0!(d)
disagg[:tm0] = _disagg_tm0!(d)
disagg[:thetaa] = _disagg_thetaa!(d)    # not in state model

disagg[:m0] = _disagg_m0!(d)            # 
disagg[:md0] = _disagg_md0!(d)
disagg[:rx0_temp] = _disagg_rx0!(d)

disagg[:pt0] = _disagg_pt0!(d)          # not in state model
disagg[:diff] = _disagg_diff!(d)        # not in state model

disagg[:rx0] = _disagg_rx0!(d)
disagg[:s0] = _disagg_s0!(d)
disagg[:x0] = _disagg_x0!(d)
disagg[:yh0] = _disagg_yh0!(d)

disagg[:pt0] = _disagg_pt0!(d)
disagg[:dc0] = _disagg_dc0!(d)

disagg[:dd0max] = _disagg_dd0max(d)
disagg[:dd0] = _disagg_dd0!(d)
disagg[:nd0] = _disagg_nd0!(d)


# disagg_check = Dict()
# [benchmark!(disagg_comp, k, bdisagg, disagg) for k in keys(disagg)];