#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Combine <: Edit
        operation::String
        output::Array{Symbol,1}
    end



# Arguments
- `operation::String`: operation to perform (+, -, *, /)
- `output::Array{Symbol,1}`
"""
mutable struct Combine <: Edit
    "operation to perform (+, -, *, /)"
    operation::String
    output::Array{Symbol,1}
end


function Combine(; operation, output, )
    Combine(operation, output, )
end

"""Get [`Combine`](@ref) `operation`."""
get_operation(value::Combine) = value.operation
"""Get [`Combine`](@ref) `output`."""
get_output(value::Combine) = value.output

"""Set [`Combine`](@ref) `operation`."""
set_operation!(value::Combine, val) = value.operation = val
"""Set [`Combine`](@ref) `output`."""
set_output!(value::Combine, val) = value.output = val
