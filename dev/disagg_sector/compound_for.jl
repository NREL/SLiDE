function _compound_with(x::Weighting, df::DataFrame, df_ones::DataFrame, xedit::Dict)
    # Compound with ones.
    df_ones = vcat([edit_with(df, xedit[fwd]) * edit_with(df_ones, xedit[rev])
        for (fwd,rev) in zip(x.on, reverse(x.on))]...)
    
    df = edit_with(df, xedit[x.on[1]]) * edit_with(df, xedit[x.on[2]])

    return df, df_ones
end

function _compound_with(x::Mapping, df::DataFrame, df_ones::DataFrame, xedit::Dict)
    df_ones = vcat([crossjoin(edit_with(df, xedit[fwd]), edit_with(df_ones, xedit[rev]))
        for (fwd,rev) in zip(x.on, reverse(x.on))]...)

    df = crossjoin(edit_with(df, xedit[x.on[1]]), edit_with(df, xedit[x.on[2]]))

    return edit_with(df, Add(:dummy,1.0)), df_ones
end











# x = copy(index)
# col = [:s,:g]
# # lst = [unique(x.data[:,x.from]);"agr"]



# x = convert_type(Mapping, x)

# df_in = copy(x.data)

# df = x.data
# df_ones = map_identity(x, lst)
# df_all = vcat(df, df_ones)

# xedit = Dict(k => Rename.([x.from;x.to], append.([x.from;x.to],k)) for k in col)
# x.from = append.(x.from, col)
# x.to = append.(x.to, col)
# x.on = col

# df, df_ones = _compound_with(x, df, df_ones, xedit)

# agg, dis = map_direction(df[:, [x.from;x.to]])
# splitter = DataFrame(fill(unique(df[:,agg[1]]), length(agg)), agg)

# df_same, df_diff = split_with(df, splitter)

# df_same = transform_over(df_same, dis[1])
# ii_same = SLiDE._find_constant.(eachrow(df_same[:,dis]))
# df_same = df_same[ii_same,:]

# df = vcat(df_same, df_diff)

# x.data = vcat(df,df_ones; cols=:intersect)







# # function _

# # df = df[:,1:end-1]
# # df_ones = df_ones[:,1:end-1]

# # function _compound_with(x::Mapping, df::DataFrame, df_ones::DataFrame, xedit::Dict)
# #     df_ones = vcat([crossjoin(edit_with(df, xedit[fwd]), edit_with(df_ones, xedit[rev]))
# #         for (fwd,rev) in zip(x.on, reverse(x.on))]...)

# #     df = crossjoin(edit_with(df, xedit[x.on[1]]), edit_with(df, xedit[x.on[2]]))

# #     return df, df_ones
# # end