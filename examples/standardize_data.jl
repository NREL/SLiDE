"""
EXAMPLE: Standardize data read from csv file into DataFrame and manipulated using the
`edit_with` function from the SLiDE module.

This example will most-likely eventually be incorporated into some build stream method.
Relevant functions can be found in the associated files:
    * load_from() - src/parse/load_structs.jl
    * edit_with() - src/parse/standardize_data.jl
"""

using CSV
using DataFrames
using YAML

using SLiDE  # see src/SLiDE.jl

# Save location of test input files (or `data`).
# Note that this is stored within the `test` dir and is separate from the `data` dir.
DATA_DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "tests", "data"))

# Read in raw test data and isolate a subsection for clarity.
df_raw = CSV.read(joinpath(DATA_DIR, "test_datastream.csv"))
df_raw = df_raw[:,1:2]



"""
APPROACH 1: Define edit structs in julia file and include it.

PRO: Including the julia file is the easiest way to get the data.
CON: The input julia file is not as clean as the YAML file, and
     I suspect this will become complicated when we begin importing multiple files.
"""

df1 = copy(df_raw)
include(joinpath(DATA_DIR, "test_datastream.jl"))

# Edit DataFrame.
df1 = SLiDE.edit_with(df1, renaming)
df1 = SLiDE.edit_with(df1, melting)
df1 = SLiDE.edit_with(df1, mapping)
df1 = SLiDE.edit_with(df1, replacing)
df1 = SLiDE.edit_with(df1, adding)



"""
APPROACH 2: Define edit structs in a YAML file and load it.
The final three lines of code *could* be consolidated, but this is easier to read for now.

PRO: The YAML file is user friendly.
     Updating the DataFrame iteratively is clean.
CON: The dictionary requires some manipulation to import it into the correct structure.
"""

df2 = copy(df_raw)
y = YAML.load(open(joinpath(DATA_DIR, "test_datastream.yml")))

# Define a list of edits to make since these must be done in this specific order.
# Find where these intersect with the keys in the input dictionary.
EDITS = ["Rename", "Melt", "Map", "Replace", "Add", "Other"];
KEYS = intersect(EDITS, [k for k in keys(y)]);

# First, convert the dictionary values into DataFrames.
[y[k] = convert_type(DataFrame, y[k]) for k in KEYS]

# Next, load each key entry into lists of Edit structures.
# This can generally be passed into the SLiDE.edit_with() function.
[y[k] = SLiDE.load_from(datatype(k), y[k]) for k in KEYS];

# Finally, update the DataFrame iteratively.
# I'm not sure why `global` is necessary here, but it is.
[global df2 = SLiDE.edit_with(df2, y[k]) for k in KEYS];