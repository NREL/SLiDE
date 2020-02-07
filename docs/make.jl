import Pkg; Pkg.add("InfrastructureSystems")

push!(LOAD_PATH, "../src/")

using DelimitedFiles
using Documenter

# Include SLiDE modules.
using SLiDE

# Now, generate the documentation.
makedocs(clean = true,
    modules = [SLiDE],
    format = Documenter.HTML(prettyurls = false),
    sitename="SLiDE",
    # pages=[
    #     "Home" => "index.md",
    #     "Data" => "lib/data.md",
    #     "API" => Any[
    #         "SLiDE" => "api/SLiDE.md"
    #     ]
    # ]
)