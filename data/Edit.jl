using CSV
using DataFrames

df_sgf = CSV.read("core_maps/sgf.csv")
df_gams = CSV.read("core_maps/gams/map_sgf.csv")

rename!(df_gams, :from => :label)
rename!(df_sgf,  :sgf => :from)
df_ans = join(df_gams, df_sgf, on = :label)

df_sgf[!,:bool] .= [(x in df_gams[:,:label]) for x in df_sgf[:,:label]]

df_sgf_deleted = copy(df_sgf[df_sgf[:,:bool] .== 0, :])

# [occursin(x, y) for y in df_sgf[:,:label] for x in df_gams[:,:label]]