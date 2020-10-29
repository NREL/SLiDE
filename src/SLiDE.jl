isdefined(Base, :__precompile__) && __precompile__()

"""
Module for constructing SLiDE objects.
"""
module SLiDE

#################################################################################
# IMPORTS
import CSV
# import InvertedIndices
import DataFrames;          using DataFrames
import Dates
import DelimitedFiles;      using DelimitedFiles
import Ipopt;               using Ipopt
import JSON;                using JSON
import JuMP;                using JuMP
import Logging;             using Logging
# import PowerSimulations;
# import Printf
# import Query;               using Query
# import Revise
import Statistics;          using Statistics
# import Test;
import XLSX
import YAML

import InteractiveUtils
const IU = InteractiveUtils

import InfrastructureSystems
const IS = InfrastructureSystems

#################################################################################

# First, generate structs to ensure all exports are possible.
const SLIDE_DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), ".."))
export SLIDE_DIR

# EXPORTS
export Add
export Describe
export Drop
export Group
export Map
export Melt
export Operate
export Order
export Match
export Rename
export Replace
export Stack

export SetInput
export CSVInput
export GAMSInput
export XLSXInput
export DataInput

export FileInput

export Parameter

export EconomicSystemsType
export CGE
export DataStream
export Check
export Edit
export File

# UTILITIES
export convert_type
export datatype
export dropnan!
export dropnan
export dropzero!
export dropzero
export dropvalue!
export dropvalue
export ensurearray
export ensuretuple
export find_oftype
# export isarray
# export istype
export permute
export findindex
export findvalue
export indexjoin

# EDIT
export edit_with
export fill_zero
export fill_with
export extrapolate_region
export extrapolate_year
export filter_with
export gams_to_dataframe

# CALCULATE
export combine_over
export transform_over

# READ
export read_file
export read_from
export load_from
export write_yaml
export run_yaml

# CHECK
export compare_summary
export compare_keys
export compare_values
export verify_over
export benchmark_against

# BUILD
export build_data
export partition
export calibrate
export share
# export share_labor!
# export share_pce!
# export share_region!
# export share_rpc!
# export share_sgf!
# export share_utd!
export disagg

#################################################################################
# INCLUDES
"""
* See [PowerSystems.jl](https://github.com/NREL/PowerSystems.jl/blob/master/src/PowerSystems.jl).*
Supertype for all SLiDE types.
All subtypes must include a InfrastructureSystemsInternal member.
Subtypes should call InfrastructureSystemsInternal() by default, but also must
provide a constructor that allows existing values to be deserialized.
"""
# abstract type EconomicSystemsType <: IS.InfrastructureSystemsType end
abstract type EconomicSystemsType end

abstract type DataStream <: EconomicSystemsType end
abstract type Edit <: DataStream end
abstract type File <: DataStream end
abstract type Check <: DataStream end

abstract type CGE <: EconomicSystemsType end

# CONSTANTS
include("definitions.jl")

# TYPES
include(joinpath("parse", "generated_check", "includes.jl"))
include(joinpath("parse", "generated_edit", "includes.jl"))
include(joinpath("parse", "generated_file", "includes.jl"))

include(joinpath("model", "generated_cge", "includes.jl"))

# UTILITIES
include(joinpath("utils", "utils.jl"))
include(joinpath("utils", "calc.jl"))
include(joinpath("utils", "indexjoin.jl"))

include(joinpath("parse", "load_data.jl"))
include(joinpath("parse", "edit_data.jl"))
include(joinpath("parse", "check_data.jl"))

include(joinpath("build","build.jl"))
include(joinpath("build","partition.jl"))
include(joinpath("build","calibrate.jl"))
include(joinpath("build","share.jl"))
include(joinpath("build","share_cfs.jl"))
include(joinpath("build","share_gsp.jl"))
include(joinpath("build","share_pce.jl"))
include(joinpath("build","share_sgf.jl"))
include(joinpath("build","share_utd.jl"))
include(joinpath("build","disagg.jl"))

function __init__()
    # See: http://pages.cs.wisc.edu/~ferris/path/LICENSE
    # https://docs.julialang.org/en/v1/base/base/#Base.ENV
    # https://docs.julialang.org/en/v1/manual/modules/index.html -> init
    Base.ENV["PATH_LICENSE_STRING"] =
        "2617827524&Courtesy&&&USR&64785&11_12_2017&1000&PATH&GEN&31_12_2020&0_0_0&5000&0_0"
end

end # module