#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Match <: Edit
        on::Regex
        input::Symbol
        output::Array{Symbol,1}
    end

Extract values from the specified column into a column or columns based on the specified regular expression.

# Arguments
- `on::Regex`: string indicating where to split
- `input::Symbol`: column to split
- `output::Array{Symbol,1}`: column names to label text surrounding the split
"""
mutable struct Match <: Edit
    "string indicating where to split"
    on::Regex
    "column to split"
    input::Symbol
    "column names to label text surrounding the split"
    output::Array{Symbol,1}
end


function Match(; on, input, output, )
    Match(on, input, output, )
end

"""Get [`Match`](@ref) `on`."""
get_on(value::Match) = value.on
"""Get [`Match`](@ref) `input`."""
get_input(value::Match) = value.input
"""Get [`Match`](@ref) `output`."""
get_output(value::Match) = value.output

"""Set [`Match`](@ref) `on`."""
set_on!(value::Match, val) = value.on = val
"""Set [`Match`](@ref) `input`."""
set_input!(value::Match, val) = value.input = val
"""Set [`Match`](@ref) `output`."""
set_output!(value::Match, val) = value.output = val
