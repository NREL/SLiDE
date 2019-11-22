SRC_PATH = joinpath("..", "src")
DATA_PATH = joinpath("..", "data")

# Add data paths.
# push!(LOAD_PATH, DATA_PATH)
# push!(LOAD_PATH, joinpath(DATA_PATH, "core_maps"))
# push!(LOAD_PATH, joinpath(DATA_PATH, "readfiles"))

# Add source paths.
push!(LOAD_PATH, SRC_PATH)
push!(LOAD_PATH, joinpath(SRC_PATH, "parse"))

using DelimitedFiles
using Documenter

# Include SLiDE modules.
# using Read
using Parse

# First, combine README and auto-documentation markdown files.
# Add the contents at the top of the file.
# reading(x::String) = open(x) do f
#     readlines(f)
# end

# writing(x::String, s::Array) = open("src/$x", "w") do f
#     writedlm(f, s, "\n")
# end

# s = reading("../README.md")

# Now, generate the documentation.
makedocs(clean = true, sitename="SLiDE")