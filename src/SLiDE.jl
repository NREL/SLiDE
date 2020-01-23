
"""
Module for constructing SLiDE objects.
"""
module SLiDE

#################################################################################
# EXPORTS
export Add
export Map
export Melt
export Rename
export Replace

export CSVInput
export XLSXInput

export CGEInput

export convert_type
export datatype

#################################################################################
# IMPORTS
import CSV
import DataFrames
import Dates
import JSON
import Logging
import Test
import YAML

import InteractiveUtils
const IU = InteractiveUtils

import InfrastructureSystems
const IS = InfrastructureSystems

#################################################################################
# INCLUDES
"""
*See [PowerSystems.jl](https://github.com/NREL/PowerSystems.jl/blob/master/src/PowerSystems.jl).*
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

# abstract type CGEModel <: EconomicSystemsType end
# abstract type CGEModel end

# UTILITIES
include(joinpath("utils", "utils.jl"))

# PARSING
include(joinpath("parse", "generated_edit", "includes.jl"))
include(joinpath("parse", "generated_load", "includes.jl"))

include(joinpath("parse", "load_data.jl"))
include(joinpath("parse", "edit_data.jl"))

# MODEL
# include(joinpath("..", "model", "generated", "includes.jl"))

end # module