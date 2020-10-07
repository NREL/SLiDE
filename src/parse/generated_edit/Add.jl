#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Add <: Edit
        col::Symbol
        val::Any
    end

Add new column `col` filled with `val`

# Arguments
- `col::Symbol`: name of new column
- `val::Any`: value to add to new column
"""
mutable struct Add <: Edit
    "name of new column"
    col::Symbol
    "value to add to new column"
    val::Any
end


function Add(; col, val, )
    Add(col, val, )
end

"""Get [`Add`](@ref) `col`."""
get_col(value::Add) = value.col
"""Get [`Add`](@ref) `val`."""
get_val(value::Add) = value.val

"""Set [`Add`](@ref) `col`."""
set_col!(value::Add, val) = value.col = val
"""Set [`Add`](@ref) `val`."""
set_val!(value::Add, val) = value.val = val
