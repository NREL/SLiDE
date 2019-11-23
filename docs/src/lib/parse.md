# Parse

**Motivation:**
We want to build an cross-sector CGE model using data gathered by the Wisconsin National Data Consortium. We want to convert the data from its original format in separate xlsx/csv files and sheets into consistently-labeled, normalized dataframes and store these in .csv output files.

**Approach:** All work is currently performed in the Parse.jl file. Each output .csv file has an associated .yml file in the readfiles directory. The .yml file includes the input file path(s) and dictionaries containing instructions on how to convert these input files into normalized dataframes.

**Thoughts:**

| Process                                          | Current approach                                                                                                              | Proposed change                                                                                                                                                                                          |
|--------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| yaml file data structure                         | Maintain dictionaries read from yaml files.                                                                                   | Store in generalized (mutable?) structs.                                                                                                                                                                 |
| Normalization dictionaries (ex, `d["renaming"]`) | Update each yaml dictionary to be a list of dictionaries.                                                                     | Store as more general iterable collection (within struct?)                                                                                                                                               |
| Ensure value type                                | Enforce types of data in normalization dictionaries after reading yaml files to match types in `readfiles/read_structure.yml` | *Would appreciate thoughts on this method.* Converting to necessary types upon (ex, `df[:, Symbol(col)]` vs. `df[:, col]`) usage feel like it overly complicates the code, but is probably more general. |
| Normalize DataFrame                              | `dataframe_*(df::DataFrame, y::Dict)` functions that make the change indicated by * required to normalize the DataFrame.      | Keep functions in module that can be called externally. *Thoughts on `Dict` argument?*                                                                                                                   |

```@autodocs
Modules = [Parse]
```