include("run.jl")
include(joinpath(SLIDE_DIR,"src","build","share_cfs.jl"))
include(joinpath(SLIDE_DIR,"src","build","share_gsp.jl"))
include(joinpath(SLIDE_DIR,"src","build","share_pce.jl"))
include(joinpath(SLIDE_DIR,"src","build","share_sgf.jl"))
include(joinpath(SLIDE_DIR,"src","build","share_utd.jl"))

bshr_int = read_to_check(joinpath(SLIDE_DIR,"data","readfiles","benchmark","shr","shr_int.yml"));
bshr_out = read_to_check(joinpath(SLIDE_DIR,"data","readfiles","benchmark","shr","shr_out.yml"));
bshr = merge(bshr_int, bshr_out)

# files_share = write_yaml(READ_DIR, XLSXInput("generate_yaml.xlsx", "share", "B1:G150", "share"))
# y = [read_file(files_share[ii]) for ii in 1:length(files_share)]
# files_share = run_yaml(ensurearray(files_share))
# shr_read = Dict(Symbol(y[ii]["PathOut"][end][1:end-4]) =>
#     read_file(joinpath(y[ii]["PathOut"]...)) for ii in 1:length(y))

# Filter data and extrapolate values as appropriate.
shr = copy(shr_read)
shr = Dict(k => sort(filter_with(df, set; extrapolate = true)) for (k, df) in shr)
shr[:va0] = edit_with(io[:va0], Rename(:j,:s))

share_pce!(shr)
share_sgf!(shr)
share_utd!(shr, set)
share_region!(shr, set)
share_labor!(shr, set)
share_rpc!(shr, set)

# Read files to benchmark.
shr_bench = Dict()
[benchmark!(shr_bench, k, bshr_out, shr) for k in intersect(keys(bshr_out),keys(shr))]