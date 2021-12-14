#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct GAMSInput <: File
        name::String
        descriptor::String
        col::Array{Symbol,1}
    end

Read .map or .set file

# Arguments
- `name::String`: input file name
- `descriptor::String`: set descriptor; this will be used to identify the GAMS set to be read.
- `col::Array{Symbol,1}`: column names
"""
mutable struct GAMSInput <: File
    "input file name"
    name::String
    "set descriptor; this will be used to identify the GAMS set to be read."
    descriptor::String
    "column names"
    col::Array{Symbol,1}
end


function GAMSInput(; name, descriptor, col, )
    GAMSInput(name, descriptor, col, )
end

"""Get [`GAMSInput`](@ref) `name`."""
get_name(value::GAMSInput) = value.name
"""Get [`GAMSInput`](@ref) `descriptor`."""
get_descriptor(value::GAMSInput) = value.descriptor
"""Get [`GAMSInput`](@ref) `col`."""
get_col(value::GAMSInput) = value.col

"""Set [`GAMSInput`](@ref) `name`."""
set_name!(value::GAMSInput, val) = value.name = val
"""Set [`GAMSInput`](@ref) `descriptor`."""
set_descriptor!(value::GAMSInput, val) = value.descriptor = val
"""Set [`GAMSInput`](@ref) `col`."""
set_col!(value::GAMSInput, val) = value.col = val
