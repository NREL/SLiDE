#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Mapping <: Scale
        data::DataFrame
        from::Union{Symbol,Array{Symbol,1}}
        to::Union{Symbol,Array{Symbol,1}}
        on::Union{Symbol,Array{Symbol,1}}
        direction::Symbol
    end

Store mapping information for scaling. This should NOT include any multiplication factors.

# Arguments
- `data::DataFrame`
- `from::Union{Symbol,Array{Symbol,1}}`: `data` columns that overlap with `on`
- `to::Union{Symbol,Array{Symbol,1}}`: `data` columns that DO NOT overlap with `on`
- `on::Union{Symbol,Array{Symbol,1}}`: columns that can be mapped with `data`
- `direction::Symbol`: indicator describing whether to aggregate/disaggregate
"""
mutable struct Mapping <: Scale
    data::DataFrame
    "`data` columns that overlap with `on`"
    from::Union{Symbol,Array{Symbol,1}}
    "`data` columns that DO NOT overlap with `on`"
    to::Union{Symbol,Array{Symbol,1}}
    "columns that can be mapped with `data`"
    on::Union{Symbol,Array{Symbol,1}}
    "indicator describing whether to aggregate/disaggregate"
    direction::Symbol
end


function Mapping(; data, from, to, on, direction, )
    Mapping(data, from, to, on, direction, )
end

"""Get [`Mapping`](@ref) `data`."""
get_data(value::Mapping) = value.data
"""Get [`Mapping`](@ref) `from`."""
get_from(value::Mapping) = value.from
"""Get [`Mapping`](@ref) `to`."""
get_to(value::Mapping) = value.to
"""Get [`Mapping`](@ref) `on`."""
get_on(value::Mapping) = value.on
"""Get [`Mapping`](@ref) `direction`."""
get_direction(value::Mapping) = value.direction

"""Set [`Mapping`](@ref) `data`."""
set_data!(value::Mapping, val) = value.data = val
"""Set [`Mapping`](@ref) `from`."""
set_from!(value::Mapping, val) = value.from = val
"""Set [`Mapping`](@ref) `to`."""
set_to!(value::Mapping, val) = value.to = val
"""Set [`Mapping`](@ref) `on`."""
set_on!(value::Mapping, val) = value.on = val
"""Set [`Mapping`](@ref) `direction`."""
set_direction!(value::Mapping, val) = value.direction = val
