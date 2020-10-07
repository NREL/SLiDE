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
    authors="Maxwell Brown, Caroline Hughes",
    pages=[
        "Home" => "index.md",
        "Data" => Any[
            "blueNOTE Data Set" => "man/data.md",
            "Build Stream" => "man/build.md",
            "Scaling" => "man/scaling.md",
            "Parameters" => "man/parameters.md"
        ],
        "Model" => "api/model.md",
        "Functions" => "api/functions.md"
    ]
)

# "API" => Any[
#             "Types" => "lib/types.md",
#             "Functions" => "lib/functions.md",
#             "Indexing" => "lib/indexing.md",
#             hide("Internals" => "lib/internals.md"),


# pages = [
#         "Home" => "index.md",
#         "Manual" => Any[
#             "Guide" => "man/guide.md",
#             "man/examples.md",
#             "man/syntax.md",
#             "man/doctests.md",
#             "man/latex.md",
#             hide("man/hosting.md", [
#                 "man/hosting/walkthrough.md"
#             ]),
#             "man/other-formats.md",
#         ],