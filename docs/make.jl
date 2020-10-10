import Pkg; Pkg.add("InfrastructureSystems")

using DelimitedFiles
using Documenter

# Include SLiDE modules.
using SLiDE

# Now, generate the documentation.
makedocs(clean = true,
    modules = [SLiDE],
    format = Documenter.HTML(prettyurls = false),
    sitename="SLiDE",
    authors="Maxwell Brown, Caroline L. Hughes",
    pages=[
        "Home" => "index.md",
        "Introduction" => Any[
            "Data" => "man/data.md",
            "Build" => Any[
                "Overview" => "man/build/overview.md",
                "Disaggregate" => "man/build/disagg.md",
            ],
            "Scaling" => "man/scaling.md",
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