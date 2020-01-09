BASE_PATH = abspath(joinpath(dirname(Base.find_package("SLiDE")), ".."))
SRC_PATH = joinpath(BASE_PATH, "src")

# Add data paths.
# push!(LOAD_PATH, DATA_PATH)
# push!(LOAD_PATH, joinpath(DATA_PATH, "core_maps"))
# push!(LOAD_PATH, joinpath(DATA_PATH, "readfiles"))

# Add source paths.
SRC_PATH in LOAD_PATH ? nothing : push!(LOAD_PATH, SRC_PATH)
joinpath(SRC_PATH, "parse") in LOAD_PATH ? nothing : push!(LOAD_PATH, joinpath(SRC_PATH, "parse"))

using DelimitedFiles
using Documenter

# Include SLiDE modules.
# using Read
using SLiDE

# Now, generate the documentation.
makedocs(clean = true,
    modules = [SLiDE],
    format = Documenter.HTML(prettyurls = false),
    sitename="SLiDE",
    pages=[
        "Home" => "index.md",
        "Data" => "lib/data.md",
        "API" => Any[
            "SLiDE" => "api/SLiDE.md"
        ]
    ])