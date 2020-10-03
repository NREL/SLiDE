using CSV
using DataFrames
using DelimitedFiles
using YAML
using Query

using SLiDE

READ_DIR = joinpath("data", "readfiles");
# include("data_temp/check_share.jl")

# bio[:ta0] = edit_with(bio[:ta0], Rename(:g,:i))
# bio[:tm0] = edit_with(bio[:tm0], Rename(:g,:i))

# bshr[:utd] = edit_with(bshr[:utd], Rename(:g,:s))
# bshr[:pce] = edit_with(bshr[:pce], Rename(:s,:g))
# bshr[:sgf] = edit_with(bshr[:sgf], Rename(:s,:g))

include("io.jl")
include("share_cfs.jl")
include("share_gsp.jl")
include("share_pce.jl")
include("share_sgf.jl")
include("share_utd.jl")

# ******************************************************************************************
#   READ SETS
# ******************************************************************************************
# Read sharing files and do some preliminary editing.
y = read_file(joinpath("data", "readfiles", "list_sets.yml"));
set = Dict((length(ensurearray(k)) == 1 ? Symbol(k) : Tuple(Symbol.(k))) =>
sort(read_file(joinpath(y["Path"]..., ensurearray(v)...)))[:,1] for (k,v) in y["Input"])

# ******************************************************************************************
#   READ SUPPLY/USE DATA
# ******************************************************************************************
println("  Reading supply/use data...")
DATA_DIR = joinpath("data", "input")
io = Dict(k => read_file(joinpath(DATA_DIR, string(k, ".csv"))) for k in [:supply, :use])

# ******************************************************************************************
#   READ SHARING DATA.
# ******************************************************************************************
files_share = write_yaml(READ_DIR, XLSXInput("generate_yaml.xlsx", "share", "B1:G150", "share"))
y = [read_file(files_share[ii]) for ii in 1:length(files_share)]
files_share = run_yaml(ensurearray(files_share))
shr = Dict(Symbol(y[ii]["PathOut"][end][1:end-4]) =>
    read_file(joinpath(y[ii]["PathOut"]...)) for ii in 1:length(y))

# Filter data and extrapolate values as appropriate.
shr = Dict(k => sort(filter_with(df, set; extrapolate = true)) for (k, df) in shr)
shr[:cfs][!,:value] .*= 1E3

shr_comp = Dict()
d = Dict(k => copy(shr[k]) for k in keys(shr))
d = merge(d, io)

# ******************************************************************************************
#   Do the things!
# ******************************************************************************************

# 
io_keys = [:a0,:fd0,:fs0,:id0,:m0,:md0,:ms0,:ta0,:tm0,:va0,:x0,:y0,:ys0]
partition!(io, set)

io_check = Dict()
[benchmark!(io_check, k, bio, io) for k in io_keys]

# shr = merge(Dict(:va0 => io[:va0]), shr)
# share_pce!(shr)
# share_sgf!(shr)
# share_utd!(shr, set)
# share_region!(shr, set)
# share_labor!(shr, set)
# share_rpc!(shr, set)

# benchmark_keys = sort(setdiff(intersect(collect(keys(bshr)),collect(keys(shr))), [:wg,:hw,:notrd,:ng]))
# [benchmark!(shr_check, k, bshr, shr) for k in benchmark_keys];