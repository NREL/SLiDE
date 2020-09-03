#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct FileInput <: Check
        f1::String
        f2::String
        colnames::Array{Symbol,1}
    end

Information for files to compare.

# Arguments
- `f1::String`: First file to compare
- `f2::String`: Second file to compare
- `colnames::Array{Symbol,1}`: column names shared by the two files
"""
mutable struct FileInput <: Check
    "First file to compare"
    f1::String
    "Second file to compare"
    f2::String
    "column names shared by the two files"
    colnames::Array{Symbol,1}
end


function FileInput(; f1, f2, colnames, )
    FileInput(f1, f2, colnames, )
end

"""Get [`FileInput`](@ref) `f1`."""
get_f1(value::FileInput) = value.f1
"""Get [`FileInput`](@ref) `f2`."""
get_f2(value::FileInput) = value.f2
"""Get [`FileInput`](@ref) `colnames`."""
get_colnames(value::FileInput) = value.colnames

"""Set [`FileInput`](@ref) `f1`."""
set_f1!(value::FileInput, val) = value.f1 = val
"""Set [`FileInput`](@ref) `f2`."""
set_f2!(value::FileInput, val) = value.f2 = val
"""Set [`FileInput`](@ref) `colnames`."""
set_colnames!(value::FileInput, val) = value.colnames = val
