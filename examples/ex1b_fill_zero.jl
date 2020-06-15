using DataFrames
using SLiDE

"""
# 1B: Fill zero
See: src/parse/edit_data.jl

Enable calculations across dictionaries and DataFrames by filling in missing values to make
dictionary keys or descriptive ("key") DataFrame columns consistent.
"""

NYR = 3  # change if desired

yr = ensurearray(2020-(NYR-1):2020)
r = ["co","wi"]
i = ["agr","fof"]

kall = permute((yr, r, i))
k1 = permute((yr, r, i))[1:end-2]
k2 = permute((yr[1:end-1], r, i))[1:end-NYR]
k3 = (yr,)
k4 = (yr[1:end-1],)

# Create corresponding DataFrames. Rename columns from defaults and add values.
x = Rename.([:x1; Symbol.(1:3)], [:yr, :yr,:r,:i])
df1 = edit_with(DataFrame(k1), [x; Add(:value, 100.)])
df2 = edit_with(DataFrame(k2), [x; Add(:value, 200.)])
df3 = edit_with(DataFrame(k3), [x; Add(:value, 300.)])
df4 = edit_with(DataFrame(k4), [x; Add(:value, 400.)])

# Create dictionaries from these keys.
d1 = convert_type(Dict, df1)
d2 = convert_type(Dict, df2)
d3 = convert_type(Dict, df3)
d4 = convert_type(Dict, df4)

# EXAMPLE 1: Create new dictionary from tuple input.
d_1a = fill_zero((yr,))
d_1b = fill_zero((yr,); permute_keys = false)
d_1c = fill_zero((yr, r))
d_1d = fill_zero(Tuple(kall); permute_keys = false)

# EXAMPLE 2: Fill missing dictionary keys with zero values.
d2_2a = fill_zero(d2)
d2_2b = fill_zero(d2; permute_keys = false)
d1_2c, d2_2c = fill_zero(d1, d2)
d1_2d, d2_2d = fill_zero(d1, d2; permute_keys = false)

# EXAMPLE 3: Create new DataFrame from named tuple.
df_3a = fill_zero((yr = yr,))
df_3b = fill_zero((yr = yr, r = r,))

# EXAMPLE 4: Fill missing DataFrame keys with zero values.
df2_4a = fill_zero(df2)
df2_4b = fill_zero(df2; permute_keys = false)
df1_4c, df2_4c = fill_zero(df1,df2)
df1_4d, df2_4d = fill_zero(df1,df2; permute_keys = false)
df3_4e, df4_4e = fill_zero(df3, df4)
df3_4f, df4_4f = fill_zero(df3, df4; permute_keys = false)

# EXAMPLE 5: Fill ONE missing dictionary key with a tuple.
d2_5a = fill_zero(k1, d2)
d2_5b = fill_zero(k1, d2; permute_keys = false)
d2_5c = fill_zero((yr,r,i), d2)

# EXAMPLE 6: Fill ONE missing DataFrame key with a tuple.
df2_6a = fill_zero((yr=yr, r=r, i=i), df2)