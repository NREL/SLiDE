#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Map <: Edit
        file::Any
        from::Array{Symbol,1}
        to::Array{Symbol,1}
        input::Array{Symbol,1}
        output::Array{Symbol,1}
        kind::Symbol
    end

Define an `output` column containing values based on those in an `input` column. The mapping columns `from` -> `to` are contained in a .csv `file` in the coremaps directory. The columns `input` and `from` should contain the same values, as should `output` and `to`.

# Arguments
- `file::Any`: mapping .csv file name in the coremaps directory
- `from::Array{Symbol,1}`: name of the mapping column containing input values
- `to::Array{Symbol,1}`: name of the mapping column containing output values
- `input::Array{Symbol,1}`: name of the input column to map
- `output::Array{Symbol,1}`: name of the output column created
- `kind::Symbol`: type of join to perform.
"""
mutable struct Map <: Edit
    "mapping .csv file name in the coremaps directory"
    file::Any
    "name of the mapping column containing input values"
    from::Array{Symbol,1}
    "name of the mapping column containing output values"
    to::Array{Symbol,1}
    "name of the input column to map"
    input::Array{Symbol,1}
    "name of the output column created"
    output::Array{Symbol,1}
    "type of join to perform."
    kind::Symbol
end


function Map(; file, from, to, input, output, kind, )
    Map(file, from, to, input, output, kind, )
end

"""Get [`Map`](@ref) `file`."""
get_file(value::Map) = value.file
"""Get [`Map`](@ref) `from`."""
get_from(value::Map) = value.from
"""Get [`Map`](@ref) `to`."""
get_to(value::Map) = value.to
"""Get [`Map`](@ref) `input`."""
get_input(value::Map) = value.input
"""Get [`Map`](@ref) `output`."""
get_output(value::Map) = value.output
"""Get [`Map`](@ref) `kind`."""
get_kind(value::Map) = value.kind

"""Set [`Map`](@ref) `file`."""
set_file!(value::Map, val) = value.file = val
"""Set [`Map`](@ref) `from`."""
set_from!(value::Map, val) = value.from = val
"""Set [`Map`](@ref) `to`."""
set_to!(value::Map, val) = value.to = val
"""Set [`Map`](@ref) `input`."""
set_input!(value::Map, val) = value.input = val
"""Set [`Map`](@ref) `output`."""
set_output!(value::Map, val) = value.output = val
"""Set [`Map`](@ref) `kind`."""
set_kind!(value::Map, val) = value.kind = val
