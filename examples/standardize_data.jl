"""
EXAMPLE: Standardize data read from csv file into DataFrame and manipulated using the
`edit_with` function from the SLiDE module.

This example will most-likely eventually be incorporated into some build stream method.
Relevant functions can be found in the associated files:
    * load_from() - src/parse/load_structs.jl
    * edit_with() - src/parse/standardize_data.jl
    * read_file() - src/parse/read_file.jl
"""
# !!!! Is it better practice to name the files the same as the functions they contain?

using CSV
using DataFrames
using YAML

using SLiDE  # see src/SLiDE.jl

# Save location of test input files (or `data`).
# Note that this is stored within the `test` dir and is separate from the `data` dir.
DATA_DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "tests", "data"))


"""
APPROACH 1: Define edit structs in julia file and include it.

PRO: Including the julia file is the easiest way to get the data.
CON: The input julia file is not as clean as the YAML file, and
     I suspect this will become complicated when we begin importing multiple files.
"""

include(joinpath(DATA_DIR, "test_datastream.jl"))

df1 = SLiDE.read_file(DATA_DIR, csvreading);
df1 = df1[:,1:2]

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

# First, read YAML file containing DataFrame and editing information.
# Then, read dataframe to edit.
y = SLiDE.read_file(joinpath(DATA_DIR, "test_datastream.yml"));
df2 = SLiDE.read_file(DATA_DIR, y["CSVInput"]);

# Define a list of edits to make since these must be done in this specific order.
# Find where these intersect with the keys in the input dictionary.
EDITS = ["Rename", "Melt", "Map", "Replace", "Add"];
KEYS = intersect(EDITS, [k for k in keys(y)]);

# Finally, update the DataFrame iteratively.
# !!!! I'm not sure why `global` is necessary here, but it is.
[global df2 = SLiDE.edit_with(df2, y[k]) for k in KEYS];