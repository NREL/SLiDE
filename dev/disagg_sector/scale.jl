using SLiDE
using DataFrames
import CSV

function filter_scale(df, x)
    # !!!! what if x has only agg? only disagg?
    # Then length of idx will only be one.
    # And find_scheme won't work because there won't be one.
    idx = _intersect(df, x)
    agg, dis = SLiDE._find_scheme(df[:,idx])

    # Check that we are scaling SHARES here:
    dftmp = combine_over(df, dis)
    if !all(dftmp[:,:value].==1.0)
        @error("Shares must sum to 1.")
    end

    dfdis = filter_with(df, Dict(dis=>x,))
    
    dfagg = fill_with(unique(select(dfdis, Not(dis))), 1.0)
    dfagg = dfagg - combine_over(dfdis, dis)
    dfagg[!,dis] .= dfagg[:,agg]
    
    df = vcat(dfdis,dfagg)

    # Update x to add any aggregate-level sectors that were not already included,
    # but for which a disaggregate-level code exists.
    x = string.(unique([x; df[:,agg]]))
    return (df, x)
end


"""
"""
function scale_for(df, set, col)
    if length(col) > 1
        from, to = SLiDE._find_scheme(df, set);
        dfmap = SLiDE._extend_over(unique(df[:,[from;to]]), set)

        x = Dict(k => Rename.([from;to], SLiDE._add_id.([from;to], k; replace=to)) for k in col)

        idxmap = get_to.(vcat(values(x)...))

        df = vcat([crossjoin(edit_with(df, x[col]), edit_with(dfmap, x[rev]))
            for (col, rev) in zip(sort!(col), sort(col; rev=true))]...)

        idx = setdiff(findindex(df), idxmap)
        agg, dis = SLiDE._find_scheme(df[:,idxmap])

        splitter = DataFrame(fill(unique(df[:,agg[1]]), length(col)), col)
        df_same, df_diff = split_with(df, splitter)

        # df_same[!,:value] .= df_same[:,:value] .* SLiDE._find_constant.(eachrow(df_same[:,dis]))
        ii_same = SLiDE._find_constant.(eachrow(df_same[:,dis]))
        df_same = df_same[ii_same,:]

        df = select(vcat(df_same, df_diff), [idx;agg;dis;:value])
    end
    return df
end


"""
Given a DataFrame and array, return a list of DataFrame columns that have values that
overlap with those in the array.
"""
_intersect(df, x) = [idx for idx in findindex(df) if !isempty(intersect(df[:,idx], x))]


scale_with(df, dfmap, from::Pair, to::Symbol) = scale_with(rename(df, from), dfmap, from[end], to)
scale_with(df, dfmap, from::Symbol, to::Symbol) = indexjoin(df, dfmap; id=[:value,:share], kind=:inner)

# ------------------------------------------------------------------------------------------
function split_scale(df::DataFrame, dfmap::DataFrame, on; share::Bool=false, key=missing)
    from, to = SLiDE._find_scheme(df, dfmap, on)

    if typeof(from)<:Pair
        dfmap = edit_with(dfmap, Rename(from[2],from[1]))
        from = from[1]
    end

    SLiDE._print_scale_status(from, to; key=key)

    df_out = antijoin(df, unique(dfmap[:,ensurearray(from)]), on=from)

    df_in = if share
        edit_with(df, Map(dfmap, [idx;from], [to;:value], [idx;on], [on;:share], :inner))
    else
        edit_with(df, Map(dfmap,[from;],[to;],[on;],[on;],:inner))
    end

    return df_in, df_out
end


"""
"""
function scale_share(df, dfmap, on; key=missing)
    df_in, df_out = split_scale(df, dfmap, on; share=true, key=key)
    df_in[!,:value] .= df_in[:,:value] .* df_in[:,:share]
    df = vcat(df_out, df_in; cols=:intersect)
    return df
end


"""
"""
function scale_map(df, dfmap, on; key=missing)
    df_in, df_out = split_scale(df, dfmap, on; share=false, key=key)
    df = vcat(df_out, df_in; cols=:intersect)
    return df
end

# include(SLIDE_DIR*"/dev/ee_module/module.jl")
# dtmp = Dict(k=>d[k] for k in [:shrgas,(:shrgas,:g),(:shrgas,:s),(:shrgas,:g,:s),(:shrgas,:s,:g)])

# ------------------------------------------------------------------------------------------
set = read_from(joinpath("src","build","readfiles","setlist.yml"))

f_read = joinpath(SLIDE_DIR,"dev","readfiles")
d = read_from(joinpath(f_read,"5_disagg_out.yml"); run_bash=true)

# FUNCTION THAT TAKES A PATH AS AN INPUT.
path = joinpath(SLIDE_DIR,"data","coremaps","scale","sector","eem_pmt.csv")
dfmap = read_file(path)[:,1:2]

set[:sector] = unique(dfmap[:,:disagg])

# FUNCTION THAT TAKES A DATAFRAME AS AN INPUT.

# If given a dataframe, figure out which is the disaggregate level.
agg, dis = SLiDE._find_scheme(dfmap)
x = dfmap[:,dis]

# FUNCTION THAT TAKES A LIST AS AN INPUT:
dfscale = read_file(joinpath(SLIDE_DIR,"data","coremaps","scale","sector","bluenote.csv"))[:,1:2]

# Now, given this array, see if there are any invalid codes.
xdiff = setdiff(x, vcat(values.(eachcol(dfscale))...))
if !isempty(xdiff)
    @error("Input array contains non-bluenote codes. To examine user-defined codes, input a DataFrame defining how existing bluenote codes should map to the user-defined codes.")
end

# Determine if there are ANY detail-level codes. If not, we can simply filter parameters.
# Otherwise, perform the disaggregation.
hasdetail = !isempty(intersect(x, dfscale[:,:detail]))

# If there ARE detail-level codes, perform sectoral sharing. And disaggregation.
set_det = SLiDE._set_sector!(copy(set), set[:detail])

det = merge(
    read_from(joinpath("src","build","readfiles","input","detail.yml")),
    Dict(:sector=>:detail),
)
SLiDE._partition_y0!(det, set_det)

df = copy(det[:y0]);
df = select(df, Not(:units));

# ----- SOME method of extend over/with/idk ----
dfmap = copy(dfscale)

scale_with(df, dfmap, from::Pair, to::Symbol) = scale_with(rename(df, from), dfmap, from[end], to)
scale_with(df, dfmap, from::Symbol, to::Symbol) = indexjoin(df, dfmap; id=[:value,:share], kind=:inner)

function scale_with(df, dfmap)
    # Ensure that from = disaggregate and to = aggregate
    agg, dis = SLiDE._find_scheme(dfmap)
    from, to = SLiDE._find_scheme(df, dfmap)

    df = scale_with(df, dfmap, from, to)

    df = df / combine_over(df, dis)

    idx = setdiff(findindex(df), [agg;dis])
    return sort(select(df, [idx;agg;dis;:value]))
end

function SLiDE._extend_over(df::DataFrame, set::AbstractArray)
    # Determine which column overlaps completely with the set.
    # We will scale from/to using this scheme.
    from, to = SLiDE._find_scheme(df, set)

    val = unique.(eachcol(dropmissing(df)[:,findindex(df)]))
    ii = .!isempty.([intersect(set, v) for v in val])
    xdiff = setdiff(set, vcat(val...))

    colmap = [from;to]
    dfmap = DataFrame(fill(xdiff, length(colmap)), colmap)

    if size(dfmap,2) !== size(df,2)
        idx = setdiff(findindex(df), colmap)
        dfadd = unique(df[:,idx])
        dfadd[!,findvalue(df)[1]] .= 1.0

        dfmap = crossjoin(dfmap, dfadd)
    end

    return vcat(df, dfmap)
end

function SLiDE._find_scheme(df, x::AbstractArray)
    # Determine which column overlaps completely with the set.
    # We will scale from/to using this scheme.
    col = setdiff(findindex(df), [:yr])
    
    ii = length.([intersect(x, c) for c in eachcol(df[:,col])]) .== SLiDE.nunique(df[:,col])
    
    if all(ii)
        ii = sortperm(SLiDE.nunique(df[:,col]))
        aggr = col[ii[1]]
        dis = col[ii[end]]
    else
        aggr = col[ii][1]
        dis = col[.!ii][1]
    end

    return aggr, dis
end

# CSV.write("data/state_model/build/share/sector.csv", df)

# x = x[1:3]
x = ["min","col_min","wpd"]

df = scale_with(df, dfmap)
dfmap, x = filter_scale(df, x)
# dfmap = map_year(dfmap, set[:yr])
# dfmap_save = copy(dfmap)

df = copy(d[:ys0])
on = SLiDE._find_sector(df)

# dfmap = scale_for(dfmap, x, on)
# df = scale_share(df, dfmap, on; key=missing)

# ------------------------------------------------------------------------------------------
# set = set[:sector]
# col = [:g,:s]
dfmap1 = SLiDE._extend_over(dfmap, x)
dfmap1 = SLiDE._compound_for(dfmap1, on; scheme=:summary=>:detail)





# df = copy(dfmap)
# idx = _intersect(df, x)
# # from, to = SLiDE._find_scheme(df[:,idx], x)

# key = :id0
# df = d[key]
# on = SLiDE._find_sector(df)
# scale_share(df, dfmap, on)

# col = 
# from, to = find_scheme