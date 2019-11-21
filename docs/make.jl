push!(LOAD_PATH, "../data/")

using DelimitedFiles
using Documenter

# Include SLiDE modules.
using Read

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