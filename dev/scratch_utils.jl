using SLiDE
using CSV
using JuMP
using Complementarity
using DataFrames
using InteractiveUtils

# ******************************************************************************************
yr = [2007,2012,2017]
r = ["co","wi"]
i = ["agr","fof"]

inp12 = (yr, r, i)
# inp34 = (yr,)

# # Define dictionary missing some keys:
ks = permute(inp12)
d1 = Dict(k => 100.0 for k in ks[1:end-3])
d2 = Dict(k => 200.0 for k in ks[1:end-5])

df1 = edit_with(DataFrame(keys(d1)), [Rename.(Symbol.(1:3), [:yr,:r,:i]); Add(:value, 100.)]);
df2 = edit_with(DataFrame(keys(d2)), [Rename.(Symbol.(1:3), [:yr,:r,:i]); Add(:value, 200.)]);

# # ******************************************************************************************
d3 = Dict(k => 300. for k in yr)
d4 = Dict(k => 400. for k in yr[1:2])

df3 = edit_with(fill_zero((yr = yr,))[:,[:yr]], Add(:value, 300.));
df4 = edit_with(fill_zero((yr = yr[1:2],))[:,[:yr]], Add(:value, 400.));


fill_zero((yr,))
fill_zero((yr,); permute_keys = false)
fill_zero((yr, r,))
fill_zero(Tuple(ks); permute_keys = false)

fill_zero(d1,d2)
fill_zero(d1,d2; permute_keys = true)
fill_zero(d3,d4)
fill_zero(d3,d4; permute_keys = true)

fill_zero((yr = yr,))
fill_zero((yr = yr, r = r,))

fill_zero(df1,df2)
fill_zero(df1,df2; permute_keys = true)
fill_zero(df3,df4)
fill_zero(df3,df4; permute_keys = true)

