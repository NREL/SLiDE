#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Replace <: Edit
        col::Symbol
        from::Any
        to::Any
    end

Replace values in `col` `from` -> `to`.

# Arguments
- `col::Symbol`: name of column containing values to be replaced
- `from::Any`: value to replace
- `to::Any`: new value
"""
mutable struct Replace <: Edit
    "name of column containing values to be replaced"
    col::Symbol
    "value to replace"
    from::Any
    "new value"
    to::Any
end


function Replace(; col, from, to, )
    Replace(col, from, to, )
end

"""Get [`Replace`](@ref) `col`."""
get_col(value::Replace) = value.col
"""Get [`Replace`](@ref) `from`."""
get_from(value::Replace) = value.from
"""Get [`Replace`](@ref) `to`."""
get_to(value::Replace) = value.to

"""Set [`Replace`](@ref) `col`."""
set_col!(value::Replace, val) = value.col = val
"""Set [`Replace`](@ref) `from`."""
set_from!(value::Replace, val) = value.from = val
"""Set [`Replace`](@ref) `to`."""
set_to!(value::Replace, val) = value.to = val
