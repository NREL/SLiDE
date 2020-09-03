#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Melt <: Edit
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
mutable struct Melt <: Edit
    "name of column(s) NOT included in melt"
    on::Array{Symbol,1}
    "name of column containing header NAMES from the original dataframe"
    var::Symbol
    "name of column containing VALUES from the original dataframe"
    val::Symbol
end


function Melt(; on, var, val, )
    Melt(on, var, val, )
end

"""Get [`Melt`](@ref) `on`."""
get_on(value::Melt) = value.on
"""Get [`Melt`](@ref) `var`."""
get_var(value::Melt) = value.var
"""Get [`Melt`](@ref) `val`."""
get_val(value::Melt) = value.val

"""Set [`Melt`](@ref) `on`."""
set_on!(value::Melt, val) = value.on = val
"""Set [`Melt`](@ref) `var`."""
set_var!(value::Melt, val) = value.var = val
"""Set [`Melt`](@ref) `val`."""
set_val!(value::Melt, val) = value.val = val
