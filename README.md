# Scalable Linked Integrated Dynamic Equilibrium Model

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

## Structure

1. model -- this directory is home to the CGE model.
2. [data](https://github.com/NREL/SLiDE/tree/master/data) -- this directory houses all of the data operations to prepare WiNDC data into the model, following two major steps:
   1. *datastream* -- Process data from datasources into .csv files. This is heavily based on the [WiNDC Data Stream](https://github.com/uw-windc/windc_datastream), but using Julia-1.2 and YAML files.
      * [data/core_maps](https://github.com/NREL/SLiDE/tree/master/data/core_maps)] -- This directory contains .csv files that map values from the input files to standardized values for consistency (ex, units, regions, etc.). Many files are from the WiNDC Data Stream, but some have been edited for simplicity.
      * [data/readfiles](https://github.com/NREL/SLiDE/tree/master/data/readfiles) -- This directory contains one YAML file for every output file with information on how to convert it into the correct format using the functions in Parse.jl. It also contains:
         * [read_structure.yml](https://github.com/NREL/SLiDE/blob/master/data/readfiles/read_structure.yml) lists the type that each variable in the other read.yml files should take for consistency and simplified parsing later.
         * [read_all.yml](https://github.com/NREL/SLiDE/blob/master/data/readfiles/read_all.yml) lists all files to read and where to read them.
   2. *buildstream* -- This feature will import the files edited by the buildstream into the correct format for the CGE model.

## Usage Notes

1. Download [datasources.zip](https://windc.wisc.edu/datastream.html) and add this to [data](https://github.com/NREL/SLiDE/tree/master/data) to run [Parse.jl](https://github.com/NREL/SLiDE/blob/master/data/Parse.jl).
2. Parse.jl adds the .csv files it creates to data/outputs.

## Current Challenges

* Right now, Parse.jl only reads into .csv files. Is SQL support important/helpful?
* Thoughts on splitting Parse.jl into packages? I am thinking of waiting until I know more about what the datastream needs.
