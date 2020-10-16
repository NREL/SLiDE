"""
Generate structures using the `generate_structs()` function from InfrastructureSystems.
"""
SRC_DIR = joinpath(SLIDE_DIR, "src")

# DataStream
# Check <: DataStream
descriptor_file = joinpath(SRC_DIR, "descriptors", "check_structs.json")
output_dir = joinpath(SRC_DIR, "parse", "generated_check")
IS.generate_structs(descriptor_file, output_dir; print_results = true)

# Edit <: DataStream
descriptor_file = joinpath(SRC_DIR, "descriptors", "edit_structs.json")
output_dir = joinpath(SRC_DIR, "parse", "generated_edit")
IS.generate_structs(descriptor_file, output_dir; print_results = true)

# Load <: DataStream
descriptor_file = joinpath(SRC_DIR, "descriptors", "file_structs.json")
output_dir = joinpath(SRC_DIR, "parse", "generated_file")
IS.generate_structs(descriptor_file, output_dir; print_results = true)

# CGE
descriptor_file = joinpath(SRC_DIR, "descriptors", "cge_structs.json")
output_dir = joinpath(SRC_DIR, "model", "generated_cge")
IS.generate_structs(descriptor_file, output_dir; print_results = true)