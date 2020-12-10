#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Operate <: Edit
        operation::String
        from::Array{Symbol,1}
        to::Array{Symbol,1}
        input::Array{Symbol,1}
        output::Symbol
    end

Perform an arithmetic operation across multiple DataFrame columns.

# Arguments
- `operation::String`: operation to perform (+, -, *, /)
- `from::Array{Symbol,1}`: name of original comment column (ex. units)
- `to::Array{Symbol,1}`: name of new comment column (ex. units)
- `input::Array{Symbol,1}`: names of columns on which to operate
- `output::Symbol`: name of result column
"""
mutable struct Operate <: Edit
    "operation to perform (+, -, *, /)"
    operation::String
    "name of original comment column (ex. units)"
    from::Array{Symbol,1}
    "name of new comment column (ex. units)"
    to::Array{Symbol,1}
    "names of columns on which to operate"
    input::Array{Symbol,1}
    "name of result column"
    output::Symbol
end


function Operate(; operation, from, to, input, output, )
    Operate(operation, from, to, input, output, )
end

"""Get [`Operate`](@ref) `operation`."""
get_operation(value::Operate) = value.operation
"""Get [`Operate`](@ref) `from`."""
get_from(value::Operate) = value.from
"""Get [`Operate`](@ref) `to`."""
get_to(value::Operate) = value.to
"""Get [`Operate`](@ref) `input`."""
get_input(value::Operate) = value.input
"""Get [`Operate`](@ref) `output`."""
get_output(value::Operate) = value.output

"""Set [`Operate`](@ref) `operation`."""
set_operation!(value::Operate, val) = value.operation = val
"""Set [`Operate`](@ref) `from`."""
set_from!(value::Operate, val) = value.from = val
"""Set [`Operate`](@ref) `to`."""
set_to!(value::Operate, val) = value.to = val
"""Set [`Operate`](@ref) `input`."""
set_input!(value::Operate, val) = value.input = val
"""Set [`Operate`](@ref) `output`."""
set_output!(value::Operate, val) = value.output = val
