#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Stack <: Edit
        on::Array{Symbol,1}
        var::Symbol
        val::Symbol
    end

Normalize the dataframe by 'melting' columns into rows, lengthening the dataframe by duplicating values in the column `on` into new rows and defining 2 new columns: 1. `var` with header names from the original dataframe. 2. `val` with column values from the original dataframe. This operation can only be performed once per dataframe.

# Arguments
- `on::Array{Symbol,1}`: name of column(s) NOT included in melt
- `var::Symbol`: name of column containing header NAMES from the original dataframe
- `val::Symbol`: name of column containing VALUES from the original dataframe
"""
mutable struct Stack <: Edit
    "name of column(s) NOT included in melt"
    on::Array{Symbol,1}
    "name of column containing header NAMES from the original dataframe"
    var::Symbol
    "name of column containing VALUES from the original dataframe"
    val::Symbol
end


function Stack(; on, var, val, )
    Stack(on, var, val, )
end

"""Get [`Stack`](@ref) `on`."""
get_on(value::Stack) = value.on
"""Get [`Stack`](@ref) `var`."""
get_var(value::Stack) = value.var
"""Get [`Stack`](@ref) `val`."""
get_val(value::Stack) = value.val

"""Set [`Stack`](@ref) `on`."""
set_on!(value::Stack, val) = value.on = val
"""Set [`Stack`](@ref) `var`."""
set_var!(value::Stack, val) = value.var = val
"""Set [`Stack`](@ref) `val`."""
set_val!(value::Stack, val) = value.val = val
