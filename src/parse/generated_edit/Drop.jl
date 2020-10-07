#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Drop <: Edit
        col::Symbol
        val::Any
        operation::String
    end

Remove information from the dataframe - either an entire column or rows containing specified values.

# Arguments
- `col::Symbol`: name of column containing data to remove
- `val::Any`: value to drop
- `operation::String`: how to determine what to drop
"""
mutable struct Drop <: Edit
    "name of column containing data to remove"
    col::Symbol
    "value to drop"
    val::Any
    "how to determine what to drop"
    operation::String
end


function Drop(; col, val, operation, )
    Drop(col, val, operation, )
end

"""Get [`Drop`](@ref) `col`."""
get_col(value::Drop) = value.col
"""Get [`Drop`](@ref) `val`."""
get_val(value::Drop) = value.val
"""Get [`Drop`](@ref) `operation`."""
get_operation(value::Drop) = value.operation

"""Set [`Drop`](@ref) `col`."""
set_col!(value::Drop, val) = value.col = val
"""Set [`Drop`](@ref) `val`."""
set_val!(value::Drop, val) = value.val = val
"""Set [`Drop`](@ref) `operation`."""
set_operation!(value::Drop, val) = value.operation = val
