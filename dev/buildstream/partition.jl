include("run.jl")
include(joinpath(SLIDE_DIR,"src","build","partition.jl"))

# Read and partition the data.
println("  Reading supply/use data...")
io = read_to_check(joinpath(SLIDE_DIR,"data","readfiles","build","partition.yml"));
partition!(io, set)

# Read benchmarking data and benchmark!
println("  Reading i/o data...")
bio_out = read_to_check(joinpath(SLIDE_DIR,"data","readfiles","benchmark","io","io_out.yml"));

io_bench = Dict()
[benchmark!(io_bench, k, bio_out, io) for k in intersect(keys(io), keys(bio_out))];
io_bench