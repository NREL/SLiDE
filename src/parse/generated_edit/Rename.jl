#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Rename <: Edit
        from::Symbol
        to::Symbol
    end

Change column name `from` -> `to`.

# Arguments
- `from::Symbol`: original column name
- `to::Symbol`: new column name
"""
mutable struct Rename <: Edit
    "original column name"
    from::Symbol
    "new column name"
    to::Symbol
end


function Rename(; from, to, )
    Rename(from, to, )
end

"""Get [`Rename`](@ref) `from`."""
get_from(value::Rename) = value.from
"""Get [`Rename`](@ref) `to`."""
get_to(value::Rename) = value.to

"""Set [`Rename`](@ref) `from`."""
set_from!(value::Rename, val) = value.from = val
"""Set [`Rename`](@ref) `to`."""
set_to!(value::Rename, val) = value.to = val
