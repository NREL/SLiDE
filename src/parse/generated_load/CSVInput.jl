#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct CSVInput <: File
        name::String
        descriptor::String
    end

Read .csv file

# Arguments
- `name::String`: input file name
- `descriptor::String`: file descriptor
"""
mutable struct CSVInput <: File
    "input file name"
    name::String
    "file descriptor"
    descriptor::String
end


function CSVInput(; name, descriptor, )
    CSVInput(name, descriptor, )
end

"""Get [`CSVInput`](@ref) `name`."""
get_name(value::CSVInput) = value.name
"""Get [`CSVInput`](@ref) `descriptor`."""
get_descriptor(value::CSVInput) = value.descriptor

"""Set [`CSVInput`](@ref) `name`."""
set_name!(value::CSVInput, val) = value.name = val
"""Set [`CSVInput`](@ref) `descriptor`."""
set_descriptor!(value::CSVInput, val) = value.descriptor = val
