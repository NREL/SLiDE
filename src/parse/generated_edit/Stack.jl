#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Stack <: Edit
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
mutable struct Stack <: Edit
    "final column names"
    col::Array{Symbol,1}
    "column name indicator specifying where to stack"
    on::Array{Symbol,1}
    "column name for storing indicator"
    var::Symbol
end


function Stack(; col, on, var, )
    Stack(col, on, var, )
end

"""Get [`Stack`](@ref) `col`."""
get_col(value::Stack) = value.col
"""Get [`Stack`](@ref) `on`."""
get_on(value::Stack) = value.on
"""Get [`Stack`](@ref) `var`."""
get_var(value::Stack) = value.var

"""Set [`Stack`](@ref) `col`."""
set_col!(value::Stack, val) = value.col = val
"""Set [`Stack`](@ref) `on`."""
set_on!(value::Stack, val) = value.on = val
"""Set [`Stack`](@ref) `var`."""
set_var!(value::Stack, val) = value.var = val
