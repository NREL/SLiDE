using CSV
using Dates
using DataFrames
using DelimitedFiles
using XLSX
using YAML

using SLiDE  # see src/SLiDE.jl

# DATA STREAM -- This will take awhile (~10 minutes?), but will only be necessa
@time include(joinpath(SLIDE_DIR, "dev", "datastream", "auto_generate_maps.jl"))     # ~60 seconds
@time include(joinpath(SLIDE_DIR, "dev", "datastream", "auto_standardize_data.jl"))  # 7.5 minutes

# Build Stream
@time include(joinpath(SLIDE_DIR, "dev", "buildstream", "partitionbea.jl"))          #  30 seconds