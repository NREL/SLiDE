#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct XLSXInput <: File
        name::String
        sheet::String
        range::String
        descriptor::String
    end

Read .xlsx file.

# Arguments
- `name::String`: input file name
- `sheet::String`: input sheet name
- `range::String`: input sheet range
- `descriptor::String`: file descriptor
"""
mutable struct XLSXInput <: File
    "input file name"
    name::String
    "input sheet name"
    sheet::String
    "input sheet range"
    range::String
    "file descriptor"
    descriptor::String
end


function XLSXInput(; name, sheet, range, descriptor, )
    XLSXInput(name, sheet, range, descriptor, )
end

"""Get [`XLSXInput`](@ref) `name`."""
get_name(value::XLSXInput) = value.name
"""Get [`XLSXInput`](@ref) `sheet`."""
get_sheet(value::XLSXInput) = value.sheet
"""Get [`XLSXInput`](@ref) `range`."""
get_range(value::XLSXInput) = value.range
"""Get [`XLSXInput`](@ref) `descriptor`."""
get_descriptor(value::XLSXInput) = value.descriptor

"""Set [`XLSXInput`](@ref) `name`."""
set_name!(value::XLSXInput, val) = value.name = val
"""Set [`XLSXInput`](@ref) `sheet`."""
set_sheet!(value::XLSXInput, val) = value.sheet = val
"""Set [`XLSXInput`](@ref) `range`."""
set_range!(value::XLSXInput, val) = value.range = val
"""Set [`XLSXInput`](@ref) `descriptor`."""
set_descriptor!(value::XLSXInput, val) = value.descriptor = val
