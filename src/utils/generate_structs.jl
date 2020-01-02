import InfrastructureSystems
const IS = InfrastructureSystems

using DataFrames
using YAML

# -------------------------------------------------------
# begin

# # Create abstract type...
# abstract type Edit end

# # Generate macros? lol Idk.
# descriptor_file = "parse_structs.json"
# output_dir = "tmp"

# IS.generate_structs(descriptor_file, output_dir; print_results = false)

# include("tmp/includes.jl")

# end

# r = Rename(from = :State, to = :Region)

# -------------------------------------------------------

# rename = DataFrame(
#     from = [:State, :Price],
#     to = [:region, :value]
# )

# for x in eachrow(rename)
#     println(x.from, " -> ", x.to)
# end

# const EDITS = ["rename", ]

y = YAML.load(open("parse_test.yml"))
# [println(k, "\t", typeof(y[k])) for k in keys(y)]



# --------------------------------------------
[make_editor(y[k]) for k in keys(y)]

# macro make_editor(name::Dict)
#     return :( println("Hello, ", $name, "!") )
# end