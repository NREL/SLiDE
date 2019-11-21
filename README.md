# Scalable Linked Integrated Dynamic Equilibrium Model

## Structure

1. model -- this directory is home to the CGE model.
2. [data](https://github.com/NREL/SLiDE/tree/master/data) -- this directory houses all of the data operations to prepare WiNDC data into the model, following two major steps:
   1. *datastream* -- Process data from datasources into .csv files. This is heavily based on the [WiNDC Data Stream](https://github.com/uw-windc/windc_datastream), but using Julia-1.2 and YAML files.
      1. [data/core_maps](https://github.com/NREL/SLiDE/tree/master/data/core_maps)] -- This directory contains .csv files that map values from the input files to standardized values for consistency (ex, units, regions, etc.). Many files are from the WiNDC Data Stream, but some have been edited for simplicity.
      2. [data/readfiles](https://github.com/NREL/SLiDE/tree/master/data/readfiles) -- This directory contains one YAML file for every output file with information on how to convert it into the correct format using the functions in parse.jl. It also contains:
         1. [read_structure.yml](https://github.com/NREL/SLiDE/blob/master/data/readfiles/read_structure.yml) lists the type that each variable in the other read.yml files should take for consistency and simplified parsing later.
         2. [read_all.yml](https://github.com/NREL/SLiDE/blob/master/data/readfiles/read_all.yml) lists all files to read and where to read them.
   2. *buildstream* -- This feature will import the files edited by the buildstream into the correct format for the CGE model.

## Usage Notes

1. Download [datasources.zip](https://windc.wisc.edu/datastream.html) and add this to [data](https://github.com/NREL/SLiDE/tree/master/data) to run [parse.jl](https://github.com/NREL/SLiDE/blob/master/data/parse.jl).
2. parse.jl adds the .csv files it creates to data/outputs.

## Current Challenges

* Right now, parse.jl only reads into .csv files. Is SQL support important/helpful?
* Thoughts on splitting parse.jl into packages? I am thinking of waiting until I know more about what the datastream needs.