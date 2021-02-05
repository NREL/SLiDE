import Pkg; Pkg.add("InfrastructureSystems")

using DelimitedFiles
using Documenter

# Include SLiDE modules.
using SLiDE

if haskey(ENV, "DOCSARGS")
    for arg in split(ENV["DOCSARGS"])
        (arg in ARGS) || push!(ARGS, arg)
    end
end

DocMeta.setdocmeta!(SLiDE, :DocTestSetup, :(using SLiDE, DataFrames); recursive=true)

# Now, generate the documentation.
makedocs(clean = true,
    modules = [SLiDE],
    format = Documenter.HTML(
        mathengine = Documenter.MathJax(),
        prettyurls = get(ENV, "CI", nothing) == "true",
    ),
    sitename = "SLiDE.jl",
    authors = "Jonathon Becker, Maxwell Brown, Caroline L. Hughes",
    # workdir = "../",
    pages = [
        "Home" => "index.md",
        "Introduction" => Any[
            "Data" => Any[
                "Overview" => "man/data/overview.md",
                "Preparation" => "man/data/preparation.md",
            ],
            "Build" => Any[
                "Overview" => "man/build/overview.md",
                "Partition" => "man/build/partition.md",
                "Share" => "man/build/share_region.md",
                "Disaggregate" => "man/build/disagg_region.md",
            ],
            "Scale" => Any[
                "Overview" => "man/scale/overview.md",
                "Sector" => "man/scale/sector.md",
            ],
            "EEM" => Any[
                "SEDS" => "man/eem/seds.md",
            ],
            "Parameters" => "man/parameters.md"
        ],
        "API" => [
            "Types" => map(
                s -> "api/types/$(s)",
                sort(readdir(joinpath(@__DIR__, "src/api/types")))),
            "Functions" => map(
                s -> "api/functions/$(s)",
                sort(readdir(joinpath(@__DIR__, "src/api/functions")))),
            "Internals" => map(
                s -> "api/internals/$(s)",
                sort(readdir(joinpath(@__DIR__, "src/api/internals"))))
            ],
        "Model" => "api/model.md",
    ]
)

# deploydocs(
#     repo = "https://github.com/NREL/SLiDE.git",
#     target = "build",
#     branch = "gh-pages",
#     devbranch = "docs",
#     devurl = "dev",
#     versions = ["stable" => "v^", "v#.#"],
# )