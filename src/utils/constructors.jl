function Dataset(name;
    build="io",
    step=PARAM_DIR,
    region_level=:state,
    sector_level=:summary,
    eem=false,
    save_build=false,
    overwrite=false,
)
    return Dataset(name, build, step, region_level, sector_level, eem, save_build, overwrite)
end


function set!(dataset::Dataset;
    name=missing,
    build=missing,
    step=missing,
    region_level=missing,
    sector_level=missing,
    eem=missing,
    save_build=missing,
    overwrite=missing,
)
    !ismissing(eem) && set_eem!(dataset, eem)
    !ismissing(name) && set_name!(dataset, name)
    !ismissing(step) && set_step!(dataset, step)
    !ismissing(build) && set_build!(dataset, _check_build(build))
    !ismissing(overwrite) && set_overwrite!(dataset, overwrite)
    !ismissing(save_build) && set_save_build!(dataset, save_build)
    !ismissing(region_level) && set_region_level!(dataset, _check_region_level(region_level))
    !ismissing(sector_level) && set_sector_level!(dataset, _check_sector_level(sector_level))
    return dataset
end

function _check_dataset(field, allowed, value)
    if !(value in allowed)
        throw(ArgumentError("allowed values for $field: $(_write_list(allowed))"))
    else
        return value
    end
end

_check_sector_level(value) = _check_dataset(:sector_level, [:summary,:detail], value)
_check_region_level(value) = _check_dataset(:region_level, [:state,:division,:region], value)
_check_build(value) = _check_dataset(:build, ["io","eem"], value)



"""
"""
function Weighting(data::DataFrame;
    constant=[:undef],
    from=:undef,
    to=:undef,
    on=:undef,
    direction=:undef,
)
    return Weighting(data, constant, from, to, on, direction)
end


"""
"""
function Mapping(data::DataFrame; from=:undef, to=:undef, on=:undef, direction=:undef)
    return Mapping(data, from, to, on, direction)
end