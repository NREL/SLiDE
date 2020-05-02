"""
EXAMPLE: Standardize data read from csv file into DataFrame and manipulated using the
`edit_with` function from the SLiDE module.

This example will most-likely eventually be incorporated into some build stream method.
Relevant functions can be found in the associated files:

- load_from() - src/parse/load_data.jl
- edit_with() - src/parse/edit_data.jl
- read_file() - src/parse/load_data.jl
"""

using CSV
using DataFrames
using YAML

using SLiDE  # see src/SLiDE.jl

DATA_DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "tests", "data"))

"""
APPROACH 1: Define edit structs in julia file and include it.
"""

include(joinpath(DATA_DIR, "test_datastream.jl"))

df1 = SLiDE.read_file(DATA_DIR, csvreading; shorten=true);

df1 = SLiDE.edit_with(df1, renaming);
df1 = SLiDE.edit_with(df1, melting);
df1 = SLiDE.edit_with(df1, adding);
df1 = SLiDE.edit_with(df1, mapping);
df1 = SLiDE.edit_with(df1, joining);
df1 = SLiDE.edit_with(df1, replacing);

df1 = SLiDE.edit_with(df1, describing, csvreading);
df1 = SLiDE.edit_with(df1, ordering);

"""
APPROACH 2: Define edit structs in a YAML file and load it.
Here are some tricky examples used for development.
"""

y = SLiDE.read_file(joinpath(DATA_DIR, "test_datastream.yml"));
y["Path"] = DATA_DIR
df2 = SLiDE.edit_with(y; shorten=true)

y = SLiDE.read_file(joinpath(DATA_DIR, "test_datastream_97.yml"));
y["Path"] = DATA_DIR
df_sgf_97 = SLiDE.edit_with(y)

y = SLiDE.read_file(joinpath(DATA_DIR, "test_datastream_98.yml"));
y["Path"] = DATA_DIR
df_sgf_98 = SLiDE.edit_with(y)