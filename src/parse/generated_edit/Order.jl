#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Order <: Edit
        col::Array{Symbol,1}
        type::Array{DataType,1}
    end

Rearranges columns in the order specified by `cols` and sets them to the specified type.

# Arguments
- `col::Array{Symbol,1}`: Ordered list of DataFrame columns
- `type::Array{DataType,1}`: Ordered column types.
"""
mutable struct Order <: Edit
    "Ordered list of DataFrame columns"
    col::Array{Symbol,1}
    "Ordered column types."
    type::Array{DataType,1}
end


function Order(; col, type, )
    Order(col, type, )
end

"""Get [`Order`](@ref) `col`."""
get_col(value::Order) = value.col
"""Get [`Order`](@ref) `type`."""
get_type(value::Order) = value.type

"""Set [`Order`](@ref) `col`."""
set_col!(value::Order, val) = value.col = val
"""Set [`Order`](@ref) `type`."""
set_type!(value::Order, val) = value.type = val
