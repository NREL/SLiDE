#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Dataset <: CGE
        name::String
        build::String
        step::String
        sector_level::Symbol
        eem::Bool
        save_build::Bool
        overwrite::Bool
    end



# Arguments
- `name::String`: dataset identifier
- `build::String`: Current step of the buildstream process: `io` or `eem`
- `step::String`: Current substep of the buildstream. If `build=io`, these steps are `partition, calibrate, share, disaggregate`. If `build=eem`, these steps are ...
- `sector_level::Symbol`: Aggregation level to use when reading BEA supply/use data.
- `eem::Bool`: Flag indicating whether to include the Energy-Environment module. If `eem=true`, first build `io` supply/use data. Then build `eem` data.
- `save_build::Bool`: Flag indicating decides whether to save the information at each build step. Setting `save_build=true` will add directories in the locations returned by [`SLiDE.datapath`](@ref). This feature is particularly helpful for buildstream debugging.
- `overwrite::Bool`: If data exists, do not read it. Build the data from scratch.
"""
mutable struct Dataset <: CGE
    "dataset identifier"
    name::String
    "Current step of the buildstream process: `io` or `eem`"
    build::String
    "Current substep of the buildstream. If `build=io`, these steps are `partition, calibrate, share, disaggregate`. If `build=eem`, these steps are ..."
    step::String
    "Aggregation level to use when reading BEA supply/use data."
    sector_level::Symbol
    "Flag indicating whether to include the Energy-Environment module. If `eem=true`, first build `io` supply/use data. Then build `eem` data."
    eem::Bool
    "Flag indicating decides whether to save the information at each build step. Setting `save_build=true` will add directories in the locations returned by [`SLiDE.datapath`](@ref). This feature is particularly helpful for buildstream debugging."
    save_build::Bool
    "If data exists, do not read it. Build the data from scratch."
    overwrite::Bool
end


function Dataset(; name, build, step, sector_level, eem, save_build, overwrite, )
    Dataset(name, build, step, sector_level, eem, save_build, overwrite, )
end

"""Get [`Dataset`](@ref) `name`."""
get_name(value::Dataset) = value.name
"""Get [`Dataset`](@ref) `build`."""
get_build(value::Dataset) = value.build
"""Get [`Dataset`](@ref) `step`."""
get_step(value::Dataset) = value.step
"""Get [`Dataset`](@ref) `sector_level`."""
get_sector_level(value::Dataset) = value.sector_level
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
"""Set [`Dataset`](@ref) `sector_level`."""
set_sector_level!(value::Dataset, val) = value.sector_level = val
"""Set [`Dataset`](@ref) `eem`."""
set_eem!(value::Dataset, val) = value.eem = val
"""Set [`Dataset`](@ref) `save_build`."""
set_save_build!(value::Dataset, val) = value.save_build = val
"""Set [`Dataset`](@ref) `overwrite`."""
set_overwrite!(value::Dataset, val) = value.overwrite = val
