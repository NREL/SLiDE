#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Describe <: Edit
        col::Symbol
    end

This DataType is required when multiple DataFrames will be appended into one output file (say, if multiple sheets from an XLSX file are included). Before the DataFrames are appended, a column `col` will be added and filled with the value in the file descriptor. !!!! Does it make sense to have a DataType with one field?

# Arguments
- `col::Symbol`: name of new column
"""
mutable struct Describe <: Edit
    "name of new column"
    col::Symbol
end


function Describe(; col, )
    Describe(col, )
end

"""Get [`Describe`](@ref) `col`."""
get_col(value::Describe) = value.col

"""Set [`Describe`](@ref) `col`."""
set_col!(value::Describe, val) = value.col = val
