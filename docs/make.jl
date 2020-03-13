import Pkg; Pkg.add("InfrastructureSystems")

push!(LOAD_PATH, "../src/")
push!(LOAD_PATH, "../src/parse")

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
            "blueNOTE Data Set" => "lib/data.md",
            "Data Stream" => "lib/datastream.md",
            "Build Stream" => "lib/buildstream.md",
            "Scaling" => "lib/scaling.md"
        ],
        "Model" => "api/model.md",
        "Functions" => "SLiDE.md"
    ]
)


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