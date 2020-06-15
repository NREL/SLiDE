using CSV
using DataFrames
using YAML

using SLiDE  # see src/SLiDE.jl

"""
# 3: Edit data
Standardize data read from csv file into DataFrame and manipulated using the
`edit_with` function from the SLiDE module.

This example will most-likely eventually be incorporated into some build stream method.
Relevant functions can be found in the associated files:
- load_from() - src/parse/load_data.jl
- edit_with() - src/parse/edit_data.jl
- read_file() - src/parse/load_data.jl
"""

DATA_DIR = joinpath("tests", "data")

y = read_file(joinpath(DATA_DIR, "test_datastream.yml"))
df = read_file(joinpath(DATA_DIR, "test_datastream.csv"))

# TERNARY OPERATORS are a type of CONDITIONAL EVALUATION and can be used to write
# single-line if-then-else statements:
#   <if> ? <then> : <else>
# && is a type of SHORT-CIRCUIT EVALUATION that can be used to write
# single-line if-then statements:
#   <if> && (<else>)
# See:
# https://discourse.julialang.org/t/style-question-ternary-operator-or-short-circuit-operator-or-if-end/34224/2
# https://docs.julialang.org/en/v1/manual/control-flow/#man-conditional-evaluation-1
# https://docs.julialang.org/en/v1/manual/control-flow/#Short-Circuit-Evaluation-1
"Drop"     in keys(y) && (df = edit_with(df, y["Drop"]))
"Rename"   in keys(y) && (df = edit_with(df, y["Rename"]))
"Group"    in keys(y) && (df = edit_with(df, y["Group"]))
"Match"    in keys(y) && (df = edit_with(df, y["Match"]))
"Melt"     in keys(y) && (df = edit_with(df, y["Melt"]))
"Add"      in keys(y) && (df = edit_with(df, y["Add"]))
"Map"      in keys(y) && (df = edit_with(df, y["Map"]))
"Replace"  in keys(y) && (df = edit_with(df, y["Replace"]))
"Drop"     in keys(y) && (df = edit_with(df, y["Drop"]))
"Operate"  in keys(y) && (df = edit_with(df, y["Operate"]))
"Describe" in keys(y) && (df = edit_with(df, y["Describe"], y["CSVInput"]))
"Order"    in keys(y) && (df = edit_with(df, y["Order"]))

show(df)