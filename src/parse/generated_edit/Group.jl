#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Group <: Edit
        file::String
        from::Symbol
        to::Array{Symbol,1}
        input::Symbol
        output::Array{Symbol,1}
    end

Use to edit files containing data in successive dataframes with an identifying header cell or row.

# Arguments
- `file::String`: mapping .csv file name in the coremaps directory. The mapping file should correlate with the header information identifying each data group. It will be used to separate the header rows from data.
- `from::Symbol`: name of the mapping column containing input values
- `to::Array{Symbol,1}`: name of the mapping column containing output values
- `input::Symbol`: name of the input column containing
- `output::Array{Symbol,1}`: name of the output column created
"""
mutable struct Group <: Edit
    "mapping .csv file name in the coremaps directory. The mapping file should correlate with the header information identifying each data group. It will be used to separate the header rows from data."
    file::String
    "name of the mapping column containing input values"
    from::Symbol
    "name of the mapping column containing output values"
    to::Array{Symbol,1}
    "name of the input column containing"
    input::Symbol
    "name of the output column created"
    output::Array{Symbol,1}
end


function Group(; file, from, to, input, output, )
    Group(file, from, to, input, output, )
end

"""Get [`Group`](@ref) `file`."""
get_file(value::Group) = value.file
"""Get [`Group`](@ref) `from`."""
get_from(value::Group) = value.from
"""Get [`Group`](@ref) `to`."""
get_to(value::Group) = value.to
"""Get [`Group`](@ref) `input`."""
get_input(value::Group) = value.input
"""Get [`Group`](@ref) `output`."""
get_output(value::Group) = value.output

"""Set [`Group`](@ref) `file`."""
set_file!(value::Group, val) = value.file = val
"""Set [`Group`](@ref) `from`."""
set_from!(value::Group, val) = value.from = val
"""Set [`Group`](@ref) `to`."""
set_to!(value::Group, val) = value.to = val
"""Set [`Group`](@ref) `input`."""
set_input!(value::Group, val) = value.input = val
"""Set [`Group`](@ref) `output`."""
set_output!(value::Group, val) = value.output = val
