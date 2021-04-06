#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Dataset <: CGE
        name::String
        build::String
        step::String
        sector::Symbol
        eem::Bool
        save_build::Bool
        overwrite::Bool
    end



# Arguments
- `name::String`
- `build::String`
- `step::String`
- `sector::Symbol`
- `eem::Bool`
- `save_build::Bool`
- `overwrite::Bool`
"""
mutable struct Dataset <: CGE
    name::String
    build::String
    step::String
    sector::Symbol
    eem::Bool
    save_build::Bool
    overwrite::Bool
end


function Dataset(; name, build, step, sector, eem, save_build, overwrite, )
    Dataset(name, build, step, sector, eem, save_build, overwrite, )
end

"""Get [`Dataset`](@ref) `name`."""
get_name(value::Dataset) = value.name
"""Get [`Dataset`](@ref) `build`."""
get_build(value::Dataset) = value.build
"""Get [`Dataset`](@ref) `step`."""
get_step(value::Dataset) = value.step
"""Get [`Dataset`](@ref) `sector`."""
get_sector(value::Dataset) = value.sector
"""Get [`Dataset`](@ref) `eem`."""
get_eem(value::Dataset) = value.eem
"""Get [`Dataset`](@ref) `save_build`."""
get_save_build(value::Dataset) = value.save_build
"""Get [`Dataset`](@ref) `overwrite`."""
get_overwrite(value::Dataset) = value.overwrite

"""Set [`Dataset`](@ref) `name`."""
set_name!(value::Dataset, val) = value.name = val
"""Set [`Dataset`](@ref) `build`."""
set_build!(value::Dataset, val) = value.build = val
"""Set [`Dataset`](@ref) `step`."""
set_step!(value::Dataset, val) = value.step = val
"""Set [`Dataset`](@ref) `sector`."""
set_sector!(value::Dataset, val) = value.sector = val
"""Set [`Dataset`](@ref) `eem`."""
set_eem!(value::Dataset, val) = value.eem = val
"""Set [`Dataset`](@ref) `save_build`."""
set_save_build!(value::Dataset, val) = value.save_build = val
"""Set [`Dataset`](@ref) `overwrite`."""
set_overwrite!(value::Dataset, val) = value.overwrite = val
