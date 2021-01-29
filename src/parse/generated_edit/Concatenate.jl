#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Concatenate <: Edit
        col::Array{Symbol,1}
        on::Array{Symbol,1}
        var::Symbol
    end

Concatenate side-by-side DataFrames into one normal-form DataFrame.

# Arguments
- `col::Array{Symbol,1}`: final column names
- `on::Array{Symbol,1}`: column name indicator specifying where to stack
- `var::Symbol`: column name for storing indicator
"""
mutable struct Concatenate <: Edit
    "final column names"
    col::Array{Symbol,1}
    "column name indicator specifying where to stack"
    on::Array{Symbol,1}
    "column name for storing indicator"
    var::Symbol
end


function Concatenate(; col, on, var, )
    Concatenate(col, on, var, )
end

"""Get [`Concatenate`](@ref) `col`."""
get_col(value::Concatenate) = value.col
"""Get [`Concatenate`](@ref) `on`."""
get_on(value::Concatenate) = value.on
"""Get [`Concatenate`](@ref) `var`."""
get_var(value::Concatenate) = value.var

"""Set [`Concatenate`](@ref) `col`."""
set_col!(value::Concatenate, val) = value.col = val
"""Set [`Concatenate`](@ref) `on`."""
set_on!(value::Concatenate, val) = value.on = val
"""Set [`Concatenate`](@ref) `var`."""
set_var!(value::Concatenate, val) = value.var = val
