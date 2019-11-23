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

# Now, generate the documentation.
makedocs(clean = true,
    modules = [Parse],
    format = Documenter.HTML(prettyurls = false),
    sitename="SLiDE",
    pages=[
        "Home" => "index.md",
        "Data" => "lib/data.md",
        "Functions" => Any[
            "Parse" => "lib/parse.md"
        ]
    ])