#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Deselect <: Edit
        col::Array{Symbol,1}
        operation::String
    end



# Arguments
- `col::Array{Symbol,1}`: name of column containing data to remove
- `operation::String`: how to determine what to drop
"""
mutable struct Deselect <: Edit
    "name of column containing data to remove"
    col::Array{Symbol,1}
    "how to determine what to drop"
    operation::String
end


function Deselect(; col, operation, )
    Deselect(col, operation, )
end

"""Get [`Deselect`](@ref) `col`."""
get_col(value::Deselect) = value.col
"""Get [`Deselect`](@ref) `operation`."""
get_operation(value::Deselect) = value.operation

"""Set [`Deselect`](@ref) `col`."""
set_col!(value::Deselect, val) = value.col = val
"""Set [`Deselect`](@ref) `operation`."""
set_operation!(value::Deselect, val) = value.operation = val
