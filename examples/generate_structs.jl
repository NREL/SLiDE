"""
EXAMPLE: Generate structures using the `generate_structs()` function from the
InfrastructureSystems module.

Specifically, generate the structures required to edit input files into the required formats.
These all share the supertype `Edit`, defined in src/SLiDE.jl.
The new structures are defined in the descriptor files.
"""

import InfrastructureSystems
const IS = InfrastructureSystems

SRC_DIR = abspath(dirname(Base.find_package("SLiDE")))



descriptor_file = joinpath(SRC_DIR, "descriptors", "edit_data_structs.json")
output_dir = joinpath(SRC_DIR, "parse", "generated_edit")

IS.generate_structs(descriptor_file, output_dir; print_results = true)


descriptor_file = joinpath(SRC_DIR, "descriptors", "load_data_structs.json")
output_dir = joinpath(SRC_DIR, "parse", "generated_load")

IS.generate_structs(descriptor_file, output_dir; print_results = true)