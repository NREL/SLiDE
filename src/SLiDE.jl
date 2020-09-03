"""
Module for constructing SLiDE objects.
"""
module SLiDE

#################################################################################
# IMPORTS
import CSV
import DataFrames
import Dates
import DelimitedFiles
import JSON
import Logging
import Printf
import Query
# import Revise
import Statistics
import Test
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

# include(joinpath("utils", "generate_structs.jl"))

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

export CSVInput
export GAMSInput
export XLSXInput

export FileInput

export CGEInput
export DataStream
export Check
export Edit
export File

export convert_type
export datatype
export isarray
export istype
export ensurearray
export permute
export find_oftype

export edit_with
export fill_zero
export read_file
export load_from
export gams_to_dataframe

export sum_over

export write_yaml
export run_yaml

export compare_summary
export compare_keys
export compare_values

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
# abstract type DataStream <: EconomicSystemsType end
abstract type DataStream end
abstract type Edit <: DataStream end
abstract type File <: DataStream end
abstract type Check <: DataStream end

# abstract type CGEModel <: EconomicSystemsType end
# abstract type CGEModel end

# PARSING
include(joinpath("parse", "generated_check", "includes.jl"))
include(joinpath("parse", "generated_edit", "includes.jl"))
include(joinpath("parse", "generated_load", "includes.jl"))

# UTILITIES
include(joinpath("utils", "utils.jl"))
include(joinpath("utils", "calc.jl"))

include(joinpath("parse", "load_data.jl"))
include(joinpath("parse", "edit_data.jl"))
include(joinpath("parse", "check_data.jl"))

function __init__()
    # See: http://pages.cs.wisc.edu/~ferris/path/LICENSE
    # https://docs.julialang.org/en/v1/base/base/#Base.ENV
    # https://docs.julialang.org/en/v1/manual/modules/index.html -> init
    Base.ENV["PATH_LICENSE_STRING"] =
        "2617827524&Courtesy&&&USR&64785&11_12_2017&1000&PATH&GEN&31_12_2020&0_0_0&5000&0_0"
end

end # module