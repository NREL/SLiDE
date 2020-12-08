#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct SetInput <: File
        name::String
        descriptor::Symbol
    end

Read .csv file with specific column names

# Arguments
- `name::String`: input file name
- `descriptor::Symbol`: file descriptor
"""
mutable struct SetInput <: File
    "input file name"
    name::String
    "file descriptor"
    descriptor::Symbol
end


function SetInput(; name, descriptor, )
    SetInput(name, descriptor, )
end

"""Get [`SetInput`](@ref) `name`."""
get_name(value::SetInput) = value.name
"""Get [`SetInput`](@ref) `descriptor`."""
get_descriptor(value::SetInput) = value.descriptor

"""Set [`SetInput`](@ref) `name`."""
set_name!(value::SetInput, val) = value.name = val
"""Set [`SetInput`](@ref) `descriptor`."""
set_descriptor!(value::SetInput, val) = value.descriptor = val
