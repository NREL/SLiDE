#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct GAMSInput <: File
        name::String
        col::Array{Symbol,1}
    end

Read .map or .set file

# Arguments
- `name::String`: input file name
- `col::Array{Symbol,1}`: column names
"""
mutable struct GAMSInput <: File
    "input file name"
    name::String
    "column names"
    col::Array{Symbol,1}
end


function GAMSInput(; name, col, )
    GAMSInput(name, col, )
end

"""Get [`GAMSInput`](@ref) `name`."""
get_name(value::GAMSInput) = value.name
"""Get [`GAMSInput`](@ref) `col`."""
get_col(value::GAMSInput) = value.col

"""Set [`GAMSInput`](@ref) `name`."""
set_name!(value::GAMSInput, val) = value.name = val
"""Set [`GAMSInput`](@ref) `col`."""
set_col!(value::GAMSInput, val) = value.col = val
