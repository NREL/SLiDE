"""
EXAMPLE: Generate structures using the `generate_structs()` function from the
InfrastructureSystems module.

Specifically, generate the structures required to edit input files into the required formats.
These all share the supertype `Edit`, defined in src/SLiDE.jl.
The new structures are defined in the descriptor files.
"""

# See ../src/utils/generate_structs.jl.
# The entirity of this example migrated here and is called by src/SLiDE.jl.
# to ensure that all of the necessary structs are generated
# upon compilatiion of the SLiDE module.