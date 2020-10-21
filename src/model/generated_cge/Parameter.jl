#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Parameter <: CGE
        parameter::Symbol
        name::String
        index::Array{Symbol,1}
        units::String
    end

Information about CGE parameters used in the model.

# Arguments
- `parameter::Symbol`: parameter variable abbreviation
- `name::String`: parameter description
- `index::Array{Symbol,1}`: Sets on which the parameter depends
- `units::String`: parameter units
"""
mutable struct Parameter <: CGE
    "parameter variable abbreviation"
    parameter::Symbol
    "parameter description"
    name::String
    "Sets on which the parameter depends"
    index::Array{Symbol,1}
    "parameter units"
    units::String
end


function Parameter(; parameter, name, index, units, )
    Parameter(parameter, name, index, units, )
end

"""Get [`Parameter`](@ref) `parameter`."""
get_parameter(value::Parameter) = value.parameter
"""Get [`Parameter`](@ref) `name`."""
get_name(value::Parameter) = value.name
"""Get [`Parameter`](@ref) `index`."""
get_index(value::Parameter) = value.index
"""Get [`Parameter`](@ref) `units`."""
get_units(value::Parameter) = value.units

"""Set [`Parameter`](@ref) `parameter`."""
set_parameter!(value::Parameter, val) = value.parameter = val
"""Set [`Parameter`](@ref) `name`."""
set_name!(value::Parameter, val) = value.name = val
"""Set [`Parameter`](@ref) `index`."""
set_index!(value::Parameter, val) = value.index = val
"""Set [`Parameter`](@ref) `units`."""
set_units!(value::Parameter, val) = value.units = val
