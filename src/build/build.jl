"""
    build_data(; kwargs...)
"""
function build_data(; save = true, overwrite = false)
    set = read_set(joinpath("src","readfiles","setlist.yml"))

    disagg = read_build("disagg"; save = save, overwrite = overwrite);
    !isempty(disagg) && (return (disagg, set))
    
    io = read_from(joinpath("src","readfiles","build","partitioninp.yml"))

    io = partition!(io, set; save = save, overwrite = overwrite)
    cal = calibrate(copy(io), set; save = save, overwrite = overwrite)

    shr = Dict(:va0 => cal[:va0])
    shr = share!(shr, set; save = save, overwrite = overwrite)

    disagg = merge(copy(shr),copy(cal),Dict(
        :r => fill_with((r = set[:r],), 1.0),
        (:yr,:r,:g) => fill_with((yr = set[:yr], r = set[:r], g = set[:g]), 1.0)))

    disagg = disagg!(disagg, set; save = save, overwrite = overwrite)
    return (disagg, set)
end

"""
    build_path(build_step::String; kwargs...)
"""
function build_path(build_step::String; save = true)
    path = save == true ? convert_type(String, today()) : save
    path = joinpath(SLIDE_DIR, "data", path, "build", build_step)
    return path
end

"""
    read_from(path::String)
"""
function read_from(path::String)
    println("  Reading from $path")
    y = read_file(joinpath(SLIDE_DIR, path));
    d = Dict((length(ensurearray(k)) == 1 ? Symbol(k) : Tuple(Symbol.(k))) => 
        read_file(joinpath(y["Path"]..., ensurearray(v)...)) for (k,v) in y["Input"])
    return d
end

"""
    read_set(path::String)
"""
function read_set(path::String)
    cp(joinpath(SLIDE_DIR,"temp","gdpcat.csv"), joinpath(SLIDE_DIR,"data","coresets","gdpcat.csv"), force = true)
    cp(joinpath(SLIDE_DIR,"temp","oth_use.csv"), joinpath(SLIDE_DIR,"data","coresets","i","oth_use.csv"), force = true)
    cp(joinpath(SLIDE_DIR,"temp","cross_fd.csv"), joinpath(SLIDE_DIR,"data","coremaps","crosswalk","fd.csv"), force = true)
    cp(joinpath(SLIDE_DIR,"temp","parse_fd.csv"), joinpath(SLIDE_DIR,"data","coremaps","parse","fd.csv"), force = true)

    d = read_from(path)
    d = Dict(k => sort(v[:,1]) for (k,v) in d)
    return d
end

"""
    write_build(build_step::String, d::Dict; kwargs...)
"""
function write_build(build_step::String, d::Dict; save = false)
    if save !== false
        save_path = build_path(build_step; save = save)

        !isdir(save_path) && mkpath(save_path)
        println("Saving $build_step in $save_path")
        
        for (k,df) in d
            println("  Saving $k")
            CSV.write(joinpath(save_path, "$k.csv"), df)
        end
    end
end

"""
    read_build(build_step::String; kwargs...)
"""
function read_build(build_step::String; save = true, overwrite::Bool = false)

    save_path = build_path(build_step; save = save)

    if overwrite == true
        d = Dict()
    else
        if !isdir(save_path)
            @warn("Cannot read data from $save_path, as it does not exist.
                \nCalculating $build_step data.")
            d = Dict()
        else
            println("Reading $build_step data from $save_path")
            files = readdir(save_path)
            d = Dict(Symbol(file[1:end-4]) => read_file(joinpath(save_path,file)) for file in files)
        end
    end
    return d
end