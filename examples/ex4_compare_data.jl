using DataFrames
using SLiDE

"""
    src/parse/check_data.jl [see file for function documentation]
These functions that can be used to compare DataFrames with the same column names.
Unfortunately, this currently only works for DataFrames.
1. compare_summary() - row-by row comparison of keys and values.
2. compare_keys() - are non-value columns consistent?
3. compare_values() - are values consistent within a given tolerance?
"""

# Make three different DataFrames to compare.
N = 3
dfa = DataFrame(yr = sort(repeat(2020-(N-1):2020, outer=[2])),
                r = repeat(["co","wi"], outer=[N]),
                value = Float64.(1:N*2))
dfb = copy(dfa)
dfc = copy(dfa)

# Change keys.
dfb[2,:r] = "md"
dfc[3,:r] = "Co"
dfc = edit_with(copy(dfa), Drop(:r, "co", "=="))

# Change values.
dfb[end-1,:value] *= 2.     # Values will not be equal regardless of tolerance.
dfc[end,:value] *= 1.001    # Values could be considered equal depending on tolerance.

# Apply functions.
df_lst = copy.([dfa,dfb,dfc])
inds = [:a,:b,:c];

# Print the three input DataFrames and results of the three comparison functions.
[(println("\ndf", ind, " = "); display(df)) for (df, ind) in zip(df_lst, inds)]

# SUMMARY: Print a summary comparison of the two DataFrames
df6_summary = compare_summary(df_lst, inds)
df2_summary = compare_summary(df_lst, inds; tol = 1E-2)

# EQUAL KEYS? Print a DataFrame summarizing difference between descriptive,
# "key" DataFrame columns.
df_keys = compare_keys(df_lst, inds)

# EQUAL VALUES? Print the rows of the summary DataFrame where values are unequal.
df6_values = compare_values(df_lst, inds)
df2_values = compare_values(df_lst, inds; tol = 1E-2)
println("")