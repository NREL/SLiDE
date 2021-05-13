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
        "Data" => Any[
            "Overview" => "man/data/overview.md",
            "Preparation" => "man/data/preparation.md",
            # "Parameters" => "man/parameters.md"
        ],
        "Build" => Any[
            "Overview" => "man/build/overview.md",
            "Regional" => Any[
                "Partition: BEA" => "man/build/io/partition_bea.md",
                "National Calibration" => "man/build/io/calibrate_national.md",
                "Regional Sharing" => "man/build/io/share_region.md",
                "Regional Disaggregation" => "man/build/io/disagg_region.md",
            ],
            "Energy-Environment Module" => Any[
                "Partition: Energy and Electricity" => "man/build/eem/partition_seds.md",
                "Energy Disaggregation" => "man/build/eem/disagg_energy.md",
                "Partition: CO2 Emissions" => "man/build/eem/partition_co2.md",
                "Regional Calibration" => "man/build/eem/calibrate_regional.md",
            ],
        ],
        "Scale" => "man/scale/overview.md",
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