#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct DataInput <: File
        name::String
        descriptor::String
        col::Array{Symbol,1}
    end

Read .csv file with specific column names

# Arguments
- `name::String`: input file name
- `descriptor::String`: file descriptor
- `col::Array{Symbol,1}`: data column names
"""
mutable struct DataInput <: File
    "input file name"
    name::String
    "file descriptor"
    descriptor::String
    "data column names"
    col::Array{Symbol,1}
end


function DataInput(; name, descriptor, col, )
    DataInput(name, descriptor, col, )
end

"""Get [`DataInput`](@ref) `name`."""
get_name(value::DataInput) = value.name
"""Get [`DataInput`](@ref) `descriptor`."""
get_descriptor(value::DataInput) = value.descriptor
"""Get [`DataInput`](@ref) `col`."""
get_col(value::DataInput) = value.col

"""Set [`DataInput`](@ref) `name`."""
set_name!(value::DataInput, val) = value.name = val
"""Set [`DataInput`](@ref) `descriptor`."""
set_descriptor!(value::DataInput, val) = value.descriptor = val
"""Set [`DataInput`](@ref) `col`."""
set_col!(value::DataInput, val) = value.col = val
