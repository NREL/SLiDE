#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct OrderedGroup <: Edit
        on::Array{Symbol,1}
        var::Symbol
        val::Array{Any,1}
    end

maybe, if on and var are the same, we can just fill in groups? i'm thinking SCTG group.

# Arguments
- `on::Array{Symbol,1}`: name of columns containing information specific to a particular level
- `var::Symbol`: name of column containing information of what we will unstack on
- `val::Array{Any,1}`: ordered list of values to unstack on. If empty, unstack in order of appearance.
"""
mutable struct OrderedGroup <: Edit
    "name of columns containing information specific to a particular level"
    on::Array{Symbol,1}
    "name of column containing information of what we will unstack on"
    var::Symbol
    "ordered list of values to unstack on. If empty, unstack in order of appearance."
    val::Array{Any,1}
end


function OrderedGroup(; on, var, val, )
    OrderedGroup(on, var, val, )
end

"""Get [`OrderedGroup`](@ref) `on`."""
get_on(value::OrderedGroup) = value.on
"""Get [`OrderedGroup`](@ref) `var`."""
get_var(value::OrderedGroup) = value.var
"""Get [`OrderedGroup`](@ref) `val`."""
get_val(value::OrderedGroup) = value.val

"""Set [`OrderedGroup`](@ref) `on`."""
set_on!(value::OrderedGroup, val) = value.on = val
"""Set [`OrderedGroup`](@ref) `var`."""
set_var!(value::OrderedGroup, val) = value.var = val
"""Set [`OrderedGroup`](@ref) `val`."""
set_val!(value::OrderedGroup, val) = value.val = val
