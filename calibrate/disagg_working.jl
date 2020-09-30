using CSV
using DataFrames
using DelimitedFiles
using YAML
using Query

using SLiDE
using Base

function extrapolate_year_back(df::DataFrame, set::Dict)
    cols = setdiff(propertynames(df), [:yr])
    yr_min = minimum(df[:,:yr])
    yr_diff = setdiff(set[:yr], unique(df[:,:yr]))

    df_ext = crossjoin(DataFrame(yr = yr_diff), filter_with(df, (yr = yr_min,))[:,cols])
    return [df_ext; df]
end

function benchmark_disagg(k::Symbol, d_summ::Dict, d_bench::Dict, d_calc::Dict;
        tol = 1E-3, small = 1E-8)

    df_calc = copy(d_calc[k])
    df_bench = copy(d_bench[k])

    # Remove very small numbers. These might be zero or missing in the other DataFrame,
    # and we're not splitting hairs here.
    df_calc = df_calc[abs.(df_calc[:,:value] .> small), :]
    df_bench = df_bench[abs.(df_bench[:,:value] .> small), :]

    println("  Comparing keys and values for ", k)
    df_comp = compare_summary([df_calc, df_bench], [:calc,:bench]; tol = tol)

    # If the dataframes are in agreement, store this value as "true".
    # Otherwise, store the comparison dataframe rows that are not in agreement.
    d_summ[k] = size(df_comp,1) == 0 ? true : df_comp
    return d_summ
end

# ******************************************************************************************
include(joinpath(SLIDE_DIR,"calibrate","data_temp","check_share.jl"))
io = bio;
cal = bcal;
shr = bshr;

disagg = Dict()
disagg_check = Dict()

df1 = Dict()
df1[:r] = fill_with((r = set[:r],), 1.0)
df1[:yr,:r,:g] = fill_with((yr = set[:yr], r = set[:r], g = set[:g]), 1.0)

# ******************************************************************************************
# "`ys0(yr,r,s,g)`: Regional sectoral output"
disagg[:ys0] = shr[:region] * cal[:ys0]
disagg_check = benchmark_disagg(:ys0, disagg_check, bdisagg, disagg)

# "`id0`: Regional intermediate demand"
disagg[:id0] = shr[:region] * cal[:id0]
disagg_check = benchmark_disagg(:id0, disagg_check, bdisagg, disagg)

# "`ty0_rev`: Production tax payments"
disagg[:ty0_rev] = shr[:region] * cal[:va0][:,[:yr,:s,:othtax]]

# "`ty0`: Production tax rate"
disagg[:ty0] = disagg[:ty0_rev] / combine_over(disagg[:ys0], :g)
disagg_check = benchmark_disagg(:ty0, disagg_check, bdisagg, disagg)

# "`va0`: Regional value added"
cal[:va0][!,:tot] = cal[:va0][:,:compen] + cal[:va0][:,:surplus]
disagg[:va0] = shr[:region] * cal[:va0][:,[:yr,:s,:tot]]
disagg_check = benchmark_disagg(:va0, disagg_check, bdisagg, disagg)

# "`ld0`: Labor demand"
disagg[:ld0] = shr[:labor] * disagg[:va0]
disagg_check = benchmark_disagg(:ld0, disagg_check, bdisagg, disagg)

# `kd0`: Capital demand
disagg[:kd0] = disagg[:va0] - disagg[:ld0]
disagg_check = benchmark_disagg(:kd0, disagg_check, bdisagg, disagg)

# ******************************************************************************************
# Sum final demand data over categories.
x = Map(joinpath("crosswalk","fd.csv"), [:fd], [:fdcat], [:fd], [:fdcat], :inner)

if !(:fdcat in propertynames(cal[:fd0]))
    cal[:fd0] = edit_with(cal[:fd0], x)
    cal[:fd0] = combine(groupby(cal[:fd0], [:yr,:s,:fdcat]), :value => sum => :value)
end

# "`g0(yr,g)`: National government demand"
disagg[:g0_temp] = filter_with(cal[:fd0], (fdcat = "G",))[:,[:yr,:s,:value]]
disagg_check = benchmark_disagg(:g0_temp, disagg_check, bdisagg, disagg)

disagg[:g0] = shr[:sgf] * disagg[:g0_temp]
disagg[:g0] = edit_with(disagg[:g0], Rename(:s,:g))
disagg_check = benchmark_disagg(:g0, disagg_check, bdisagg, disagg)

# "`i0(yr,g)`: National investment demand"
disagg[:i0_temp] = filter_with(cal[:fd0], (fdcat = "I",))[:,[:yr,:s,:value]]
disagg_check = benchmark_disagg(:i0_temp, disagg_check, bdisagg, disagg)

disagg[:i0] = shr[:region] * disagg[:i0_temp]
disagg[:i0] = edit_with(disagg[:i0], Rename(:s,:g))
disagg_check = benchmark_disagg(:i0, disagg_check, bdisagg, disagg)

# "`cd0(yr,g)`: National final consumption"
disagg[:cd0_temp] = cal[:fd0][cal[:fd0][:,:fdcat] .== "C", [:yr,:s,:value]]
disagg_check = benchmark_disagg(:cd0_temp, disagg_check, bdisagg, disagg)

disagg[:cd0] = shr[:pce] * disagg[:cd0_temp]
disagg[:cd0] = edit_with(disagg[:cd0], Rename(:s,:g))
disagg_check = benchmark_disagg(:cd0, disagg_check, bdisagg, disagg)

# "`c0(yr,r)`: Total final household consumption"
disagg[:c0] = combine_over(disagg[:cd0], :g)
disagg_check = benchmark_disagg(:c0, disagg_check, bdisagg, disagg)

# "`yh0(yr,r,s)`: Household production"
disagg[:yh0_temp] = shr[:region] * cal[:fs0]
disagg[:yh0_temp] = edit_with(disagg[:yh0_temp], Rename(:s,:g))
disagg_check = benchmark_disagg(:yh0_temp, disagg_check, bdisagg, disagg)

# "`fe0(yr,r)`: Total factor supply"
disagg[:fe0] = combine(groupby(disagg[:va0], [:yr,:r]), :value => sum => :value)

# "`x0(yr,r,g)`: Foreign exports"
df_exports = edit_with(filter_with(copy(shr[:utd]), (t = "exports",)),
    [Drop(:t,"all","=="), Rename(:s,:g)])
df_exports = extrapolate_year_back(df_exports, set)

x0_trd = dropmissing(df_exports * cal[:x0])
x0_notrd = filter_with(edit_with(copy(shr[:region]), Rename(:s,:g)) * cal[:x0], (g = set[:notrd],))
disagg[:x0_temp] = [x0_trd; x0_notrd]
disagg_check = benchmark_disagg(:x0_temp, disagg_check, bdisagg, disagg)

# "`s0(yr,r,g)`: Total supply"
disagg[:s0_temp] = combine_over(disagg[:ys0], :s) + disagg[:yh0_temp]
disagg_check = benchmark_disagg(:s0_temp, disagg_check, bdisagg, disagg)

# "`a0(yr,r,g)`: Domestic absorption"
disagg[:a0] = dropmissing(disagg[:cd0] + disagg[:g0] + disagg[:i0] + combine_over(disagg[:id0], :s))
disagg_check = benchmark_disagg(:a0, disagg_check, bdisagg, disagg)

# "`ta0(yr,r,g)`: Absorption taxes"
disagg[:ta0] = io[:ta0] * df1[:r]
disagg_check = benchmark_disagg(:ta0, disagg_check, bdisagg, disagg)

# "`tm0(yr,r,g)`: Import taxes"
disagg[:tm0] = io[:tm0] * df1[:r]
disagg_check = benchmark_disagg(:tm0, disagg_check, bdisagg, disagg)

# "`thetaa(yr,r,g)`: Share of regional absorption"
disagg[:thetaa] = disagg[:a0] / transform_over(disagg[:a0], :r)

# "`m0(yr,r,g)`: Foreign Imports"
disagg[:m0] = disagg[:thetaa] * cal[:m0]
disagg_check = benchmark_disagg(:m0, disagg_check, bdisagg, disagg)

# "`md0(yr,r,m,g)`: Margin demand"
disagg[:md0] = dropmissing(disagg[:thetaa] * cal[:md0])
disagg_check = benchmark_disagg(:md0, disagg_check, bdisagg, disagg)

# "`rx0(yr,r,g)`: Re-exports"
disagg[:rx0_temp] = disagg[:x0_temp] - disagg[:s0_temp]
disagg[:rx0_temp][round.(disagg[:rx0_temp][:,:value]; digits = 10) .< 0, :value] .= 0.0
disagg_check = benchmark_disagg(:rx0_temp, disagg_check, bdisagg, disagg)

# ******************************************************************************************

disagg[:pta0] = dropmissing(((df1[:yr,:r,:g] - disagg[:ta0]) * disagg[:a0]) + disagg[:rx0_temp])
disagg[:ptm0] = dropmissing(((df1[:yr,:r,:g] + disagg[:tm0]) * disagg[:m0]) + combine_over(disagg[:md0], :m))
disagg[:dc0] = dropmissing((disagg[:s0_temp] - disagg[:x0_temp] + disagg[:rx0_temp]))
disagg[:pt0] = disagg[:pta0] - disagg[:ptm0]

disagg[:dc0] = sort(dropmissing((disagg[:s0_temp] - (disagg[:x0_temp] - disagg[:rx0_temp]))))

# disagg[:pta0][!,:value] = round.(temp[:pta0][:,:value]; digits = 10)
# disagg[:ptm0][!,:value] = round.(temp[:ptm0][:,:value]; digits = 10)
# ******************************************************************************************

# "`diff`: Negative numbers still exist due to sharing parameter"
disagg[:diff] = copy(disagg[:pt0])
disagg[:diff][!,:value] .= - min.(0, disagg[:diff][:,:value])
disagg_check = benchmark_disagg(:diff, disagg_check, bdisagg, disagg)

disagg[:diff] = edit_with(disagg[:diff], Drop(:value,0.0,"=="))

# "`rx0(yr,r,g)`: Re-exports"
disagg[:rx0] = disagg[:rx0_temp] + disagg[:diff]
disagg_check = benchmark_disagg(:rx0, disagg_check, bdisagg, disagg)

# "`x0(yr,r,g)`: Foreign exports"
disagg[:x0]  = disagg[:x0_temp]  + disagg[:diff]
disagg_check = benchmark_disagg(:x0,  disagg_check, bdisagg, disagg)

# "`s0(yr,r,g)`: Total supply"
disagg[:s0]  = disagg[:s0_temp]  + disagg[:diff]
disagg_check = benchmark_disagg(:s0,  disagg_check, bdisagg, disagg)

# "`yh0(yr,r,s)`: Household production"
disagg[:yh0] = disagg[:yh0_temp] + disagg[:diff]
disagg_check = benchmark_disagg(:yh0, disagg_check, bdisagg, disagg)

# "`bopdef0(yr,r)`: Balance of payments (closure parameter)"
disagg[:bopdef0] = combine_over((disagg[:m0] - disagg[:x0]), :g)
disagg_check = benchmark_disagg(:bopdef0, disagg_check, bdisagg, disagg)

# ******************************************************************************************

# "`gm`: Commodities employed in margin supply"
#! gm(g) = yes$(sum((yr,m), ms_0(yr,g,m)) or sum((yr,m), md_0(yr,m,g)));
cal[:ms0] = edit_with(cal[:ms0], Rename(:s,:g))
ms0_sum = combine_over(cal[:ms0], [:yr,:m])
md0_sum = combine_over(cal[:md0], [:yr,:m])

ms0_sum[!,:value] .= ms0_sum[:,:value] .!= 0.0
md0_sum[!,:value] .= md0_sum[:,:value] .!= 0.0

gm = ms0_sum + md0_sum
set[:gm] = gm[gm[:,:value] .> 0, :g]

# ******************************************************************************************
disagg[:pta0] = dropmissing(((df1[:yr,:r,:g] - disagg[:ta0]) * disagg[:a0]) + disagg[:rx0])
disagg[:ptm0] = dropmissing(((df1[:yr,:r,:g] + disagg[:tm0]) * disagg[:m0]) + combine_over(disagg[:md0], :m))
disagg[:dc0] = dropmissing((disagg[:s0] - disagg[:x0] + disagg[:rx0]))
disagg[:pt0] = disagg[:pta0] - disagg[:ptm0]

disagg[:dc0] = sort(dropmissing((disagg[:s0] - (disagg[:x0] - disagg[:rx0]))))
# ******************************************************************************************

# "`dd0max(yr,r,g)`: Maximum regional demand from local market"
#! dd0max(yr,r,g) = min(round((1-ta0_(yr,r,g))*a0_(yr,r,g) + rx0_(yr,r,g) -
#!                           ((1+tm0_(yr,r,g))*m0_(yr,r,g) + sum(m, md0_(yr,r,m,g))),10),
#!                      round(s0_(yr,r,g) - (x0_(yr,r,g) - rx0_(yr,r,g)),10));
disagg[:dd0max] = copy(df_empty)
disagg[:dd0max][!,:value] = min.(disagg[:pt0][:,:value], disagg[:dc0][:,:value])
disagg_check = benchmark_disagg(:dd0max, disagg_check, bdisagg, disagg)

# "`nd0max(yr,r,g)`: Maximum regional demand from national market"
# !!!! Should this be different from dd0max?
#! nd0max(yr,r,g) = min(round((1-ta0_(yr,r,g))*a0_(yr,r,g) + rx0_(yr,r,g) -
#!                           ((1+tm0_(yr,r,g))*m0_(yr,r,g) + sum(m, md0_(yr,r,m,g))),10),
#!                      round(s0_(yr,r,g) - (x0_(yr,r,g) - rx0_(yr,r,g)),10) );
disagg[:nd0max] = copy(disagg[:dd0max])

# "`dd0min(yr,r,g)`: Minimum regional demand from local market"
#! dd0min(yr,r,g) = (1-ta0_(yr,r,g))* a0_(yr,r,g) + rx0_(yr,r,g) - nd0max(yr,r,g) -
#!    m0_(yr,r,g)*(1+tm0_(yr,r,g)) - sum(m,md0_(yr,r,m,g));
disagg[:dd0min] = disagg[:pt0] - disagg[:dd0max]

# "`nd0min(yr,r,g)`: Minimum regional demand from national market"
#! nd0min(yr,r,g) = (1-ta0_(yr,r,g))* a0_(yr,r,g) + rx0_(yr,r,g) - dd0max(yr,r,g) -
#!    m0_(yr,r,g)*(1+tm0_(yr,r,g)) - sum(m,md0_(yr,r,m,g));
disagg[:nd0min] = disagg[:pt0] - disagg[:nd0max]

# ******************************************************************************************

# "`dd0_(yr,r,g)`: Regional demand from local market"
disagg[:dd0] = disagg[:dd0max] * shr[:rpc]
disagg_check = benchmark_disagg(:dd0, disagg_check, bdisagg, disagg)

# "`nd0_(yr,r,g)`: Regional demand from national marke"
disagg[:nd0] = disagg[:pt0] - disagg[:dd0]
disagg[:nd0][!,:value] .= round.(disagg[:nd0][:,:value]; digits = 10)
disagg_check = benchmark_disagg(:nd0, disagg_check, bdisagg, disagg)

# "`mrgshr(yr,r,m)`: Share of margin demand by region"
disagg[:mrgshr]  = combine_over(disagg[:md0], :g)
disagg[:mrgshr] /= transform_over(disagg[:mrgshr], :r)

# "`totmargsupply(yr,r,m,g)`: Designate total supply of margins"
disagg[:totmrgshr] = disagg[:mrgshr] * cal[:ms0]

# "`shrtrd(yr,r,m,g)`: Share of margin total by margin type"
disagg[:shrtrd] = disagg[:totmrgshr] / transform_over(disagg[:totmrgshr], :m)

# `dm0(yr,r,g,m)`: Margin supply from the local market"
dm1 = dropmissing(disagg[:totmrgshr] * shr[:rpc])
dm2 = dropmissing((disagg[:shrtrd] * disagg[:dc0]) - disagg[:dd0])
(dm1, dm2) = fill_zero(dm1, dm2; permute_keys = false)

disagg[:dm0] = copy(dm1)
disagg[:dm0][!,:value] .= min.(dm1[:,:value], dm2[:,:value])
disagg_check = benchmark_disagg(:dm0, disagg_check, bdisagg, disagg)

# `nm0(yr,r,g,m)`: Margin demand from the national market"
disagg[:nm0] = disagg[:totmrgshr] - disagg[:dm0]
disagg_check = benchmark_disagg(:nm0, disagg_check, bdisagg, disagg)

# `xd0(yr,r,g)`: Regional supply to local market"
disagg[:xd0] = combine_over(disagg[:dm0], :m) + disagg[:dd0]
disagg_check = benchmark_disagg(:dm0, disagg_check, bdisagg, disagg)

# `xn0(yr,r,g)`: Regional supply to national market"
disagg[:xn0] = disagg[:s0] + disagg[:rx0] - disagg[:xd0] - disagg[:x0]
disagg_check = benchmark_disagg(:xn0, disagg_check, bdisagg, disagg)