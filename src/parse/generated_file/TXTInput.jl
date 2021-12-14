#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct TXTInput <: File
        name::String
        descriptor::String
        col::Array{Symbol,1}
    end

Read .txt file

# Arguments
- `name::String`: input file name
- `descriptor::String`: file descriptor
- `col::Array{Symbol,1}`: column names
"""
mutable struct TXTInput <: File
    "input file name"
    name::String
    "file descriptor"
    descriptor::String
    "column names"
    col::Array{Symbol,1}
end


function TXTInput(; name, descriptor, col, )
    TXTInput(name, descriptor, col, )
end

"""Get [`TXTInput`](@ref) `name`."""
get_name(value::TXTInput) = value.name
"""Get [`TXTInput`](@ref) `descriptor`."""
get_descriptor(value::TXTInput) = value.descriptor
"""Get [`TXTInput`](@ref) `col`."""
get_col(value::TXTInput) = value.col

"""Set [`TXTInput`](@ref) `name`."""
set_name!(value::TXTInput, val) = value.name = val
"""Set [`TXTInput`](@ref) `descriptor`."""
set_descriptor!(value::TXTInput, val) = value.descriptor = val
"""Set [`TXTInput`](@ref) `col`."""
set_col!(value::TXTInput, val) = value.col = val
