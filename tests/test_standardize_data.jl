begin

    import InfrastructureSystems
    const IS = InfrastructureSystems
    
    using CSV
    using DataFrames
    using YAML
    
    BASE_DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), ".."))
    SRC_DIR = joinpath(BASE_DIR, "src")
    
    ### GENERATE MACROS
    abstract type Edit end
    descriptor_file = joinpath(SRC_DIR, "descriptors", "standardize_data_structs.json")
    output_dir = joinpath(SRC_DIR, "parse", "generated")
    IS.generate_structs(descriptor_file, output_dir; print_results = false)
    include(joinpath(output_dir, "includes.jl"))
    
    ### CREATE EDITING FUNCTIONS
    include(joinpath(SRC_DIR, "parse", "standardize_data.jl"))
    
    ### READ TEST DATAFRAME
    df = CSV.read(joinpath("data", "test_datastream.csv"))
    include(joinpath("data", "test_datastream.jl"))
    
    ### EDIT DATAFRAME
    df = rename_with(df, renaming)
    df = melt_with(df, melting)
    df = replace_with(df, replacing)
    df = add_with(df, adding)
    
end