"""
Generate structures using the `generate_structs()` function from InfrastructureSystems.
"""
SRC_DIR = abspath(dirname(Base.find_package("SLiDE")))

descriptor_file = joinpath(SRC_DIR, "descriptors", "check_data_structs.json")
output_dir = joinpath(SRC_DIR, "parse", "generated_check")

IS.generate_structs(descriptor_file, output_dir; print_results = true)


descriptor_file = joinpath(SRC_DIR, "descriptors", "edit_data_structs.json")
output_dir = joinpath(SRC_DIR, "parse", "generated_edit")

IS.generate_structs(descriptor_file, output_dir; print_results = true)


descriptor_file = joinpath(SRC_DIR, "descriptors", "load_data_structs.json")
output_dir = joinpath(SRC_DIR, "parse", "generated_load")

IS.generate_structs(descriptor_file, output_dir; print_results = true)