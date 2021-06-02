#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Weighting <: Scale
        data::DataFrame
        constant::Array{Symbol,1}
        from::Union{Symbol,Array{Symbol,1}}
        to::Union{Symbol,Array{Symbol,1}}
        on::Union{Symbol,Array{Symbol,1}}
        direction::Symbol
    end

Store mapping AND weighting information for scaling

# Arguments
- `data::DataFrame`
- `constant::Array{Symbol,1}`: `data` columns that are included in but not changed by the mapping process
- `from::Union{Symbol,Array{Symbol,1}}`: `data` columns that overlap with `on`
- `to::Union{Symbol,Array{Symbol,1}}`: `data` columns that DO NOT overlap with `on`
- `on::Union{Symbol,Array{Symbol,1}}`: columns that can be mapped with `data`
- `direction::Symbol`: indicator describing whether to aggregate/disaggregate
"""
mutable struct Weighting <: Scale
    data::DataFrame
    "`data` columns that are included in but not changed by the mapping process"
    constant::Array{Symbol,1}
    "`data` columns that overlap with `on`"
    from::Union{Symbol,Array{Symbol,1}}
    "`data` columns that DO NOT overlap with `on`"
    to::Union{Symbol,Array{Symbol,1}}
    "columns that can be mapped with `data`"
    on::Union{Symbol,Array{Symbol,1}}
    "indicator describing whether to aggregate/disaggregate"
    direction::Symbol
end


function Weighting(; data, constant, from, to, on, direction, )
    Weighting(data, constant, from, to, on, direction, )
end

"""Get [`Weighting`](@ref) `data`."""
get_data(value::Weighting) = value.data
"""Get [`Weighting`](@ref) `constant`."""
get_constant(value::Weighting) = value.constant
"""Get [`Weighting`](@ref) `from`."""
get_from(value::Weighting) = value.from
"""Get [`Weighting`](@ref) `to`."""
get_to(value::Weighting) = value.to
"""Get [`Weighting`](@ref) `on`."""
get_on(value::Weighting) = value.on
"""Get [`Weighting`](@ref) `direction`."""
get_direction(value::Weighting) = value.direction

"""Set [`Weighting`](@ref) `data`."""
set_data!(value::Weighting, val) = value.data = val
"""Set [`Weighting`](@ref) `constant`."""
set_constant!(value::Weighting, val) = value.constant = val
"""Set [`Weighting`](@ref) `from`."""
set_from!(value::Weighting, val) = value.from = val
"""Set [`Weighting`](@ref) `to`."""
set_to!(value::Weighting, val) = value.to = val
"""Set [`Weighting`](@ref) `on`."""
set_on!(value::Weighting, val) = value.on = val
"""Set [`Weighting`](@ref) `direction`."""
set_direction!(value::Weighting, val) = value.direction = val
