using SLiDE

function build_data()
    println("Beginning data build process.")

    println("  Reading sets.")
    y = read_file(joinpath("data", "readfiles", "list_sets.yml"));
    set = Dict((length(ensurearray(k)) == 1 ? Symbol(k) : Tuple(Symbol.(k))) =>
        sort(read_file(joinpath(y["Path"]..., ensurearray(v)...)))[:,1] for (k,v) in y["Input"])

    println("***** PARTITION *****")
    println("  Reading supply/use data.")
    io = Dict()
    io[:supply] = read_file(joinpath("data","input","supply.csv"))
    io[:use] = read_file(joinpath("data","input","use.csv"))

    # PARTITION
    partition!(io, set)

    # CALIBRATE.
    cal = calibrate(copy(io), set)

    # SHARE.
    # Adjust input data to share.
    println("***** SHARE *****")
    READ_DIR = joinpath("data","readfiles")
    files_share = write_yaml(READ_DIR, XLSXInput("generate_yaml.xlsx", "share", "B1:G150", "share"))
    y = [read_file(files_share[ii]) for ii in 1:length(files_share)]
    files_share = run_yaml(ensurearray(files_share))
    shr_read = Dict(Symbol(y[ii]["PathOut"][end][1:end-4]) =>
        read_file(joinpath(y[ii]["PathOut"]...)) for ii in 1:length(y))

    # Filter data and extrapolate values as appropriate.
    shr = copy(shr_read)
    shr = Dict(k => sort(filter_with(df, set; extrapolate = true)) for (k, df) in shr)
    shr[:va0] = edit_with(cal[:va0], Rename(:j,:s))

    share_pce!(shr)
    share_sgf!(shr)
    share_utd!(shr, set)
    share_region!(shr, set)
    share_labor!(shr, set)
    share_rpc!(shr, set)

    println("***** DISAGGREGATE *****")
    d = merge(copy(shr),copy(cal),Dict(
        :r => fill_with((r = set[:r],), 1.0),
        (:yr,:r,:g) => fill_with((yr = set[:yr], r = set[:r], g = set[:g]), 1.0)))

    (disagg, set) = disagg!(d, set)

    d = Dict()
    d[:a0]  = ensurenames(disagg[:a0], [:yr, :r, :g, :value])
    d[:bopdef0] = ensurenames(disagg[:bopdef0], [:yr, :r, :value])
    d[:c0]  = ensurenames(disagg[:c0], [:yr, :r, :value])
    d[:cd0] = ensurenames(disagg[:cd0], [:yr, :r, :s, :value])
    d[:dd0] = ensurenames(disagg[:dd0], [:yr, :r, :g, :value])
    d[:dm0] = ensurenames(disagg[:dm0], [:yr, :r, :g, :m, :value])
    d[:g0]  = ensurenames(disagg[:g0], [:yr, :r, :s, :value])
    d[:hhadj] = ensurenames(disagg[:hhadj], [:yr, :r, :value])
    d[:i0]  = ensurenames(disagg[:i0], [:yr, :r, :s, :value])
    d[:id0] = ensurenames(disagg[:id0], [:yr, :r, :g, :s, :value])
    d[:kd0] = ensurenames(disagg[:kd0], [:yr, :r, :s, :value])
    d[:ld0] = ensurenames(disagg[:ld0], [:yr, :r, :s, :value])
    d[:m0]  = ensurenames(disagg[:m0], [:yr, :r, :g, :value])
    d[:md0] = ensurenames(disagg[:md0], [:yr, :r, :m, :g, :value])
    d[:nd0] = ensurenames(disagg[:nd0], [:yr, :r, :g, :value])
    d[:nm0] = ensurenames(disagg[:nm0], [:yr, :r, :g, :m, :value])
    d[:rx0] = ensurenames(disagg[:rx0], [:yr, :r, :g, :value])
    d[:s0]  = ensurenames(disagg[:s0], [:yr, :r, :g, :value])
    d[:ta0] = ensurenames(disagg[:ta0], [:yr, :r, :g, :value])
    d[:tm0] = ensurenames(disagg[:tm0], [:yr, :r, :g, :value])
    d[:ty0] = ensurenames(disagg[:ty0], [:yr, :r, :s, :value])
    d[:x0]  = ensurenames(disagg[:x0], [:yr, :r, :g, :value])
    d[:xd0] = ensurenames(disagg[:xd0], [:yr, :r, :g, :value])
    d[:xn0] = ensurenames(disagg[:xn0], [:yr, :r, :g, :value])
    d[:yh0] = ensurenames(disagg[:yh0], [:yr, :r, :s, :value])
    d[:ys0] = ensurenames(disagg[:ys0], [:yr, :r, :s, :g, :value])
    
    return (d, set)
end