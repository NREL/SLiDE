using CSV
using Dates
using DataFrames
using DelimitedFiles
using XLSX
using YAML

using SLiDE  # see src/SLiDE.jl

# DATA STREAM -- This will take awhile (~10 minutes, maximum), but will only be necessary
# the first time the SLiDE package is installed and when data is updated.
@time include(joinpath(SLIDE_DIR, "dev", "datastream", "auto_generate_maps.jl"))     # ~60 seconds
@time include(joinpath(SLIDE_DIR, "dev", "datastream", "auto_standardize_data.jl"))  # ~7.5 minutes

# BUILD STREAM -- Prepare data for the calibration scheme.
# This is where user customizations can be applied (future work).
(d, set) = build_data()