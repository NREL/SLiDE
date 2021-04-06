function Dataset(name;
    build="io",
    step=PARAM_DIR,
    sector=:summary,
    eem=false,
    save_build=false,
    overwrite=false,
)
    return Dataset(name, build, step, sector, eem, save_build, overwrite)
end

function set!(dataset::Dataset;
    name=missing,
    build=missing,
    step=missing,
    sector=missing,
    eem=missing,
    save_build=missing,
    overwrite=missing,
)
    !ismissing(eem) && set_eem!(dataset, eem)
    !ismissing(name) && set_name!(dataset, name)
    !ismissing(step) && set_step!(dataset, step)
    !ismissing(build) && set_build!(dataset, build)
    !ismissing(sector) && set_sector!(dataset, sector)
    !ismissing(overwrite) && set_overwrite!(dataset, overwrite)
    !ismissing(save_build) && set_save_build!(dataset, save_build)
    return dataset
end


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