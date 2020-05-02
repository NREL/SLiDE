using CSV
using DataFrames
using DelimitedFiles
using Printf
using Statistics

using SLiDE

"""
    make_uniform(df::DataFrame, cols::Array{Symbol,1})
This function is specific to the verify_datastream.jl file. It makes input DataFrames
uniform (same columns; should add support to standardize types)
"""
function make_uniform(df::DataFrame, cols::Array{Symbol,1})
    .&(size(names(df)) == size(cols), length(setdiff(cols, names(df))) > 0) ?
        df = edit_with(df, Rename.(names(df), cols))[:,cols] : nothing
    df = df[:,cols]

    # !!!! Assumptions about value column name and type: (1) values are stored in a column
    # named :value and (2) values are type FLOAT64. This is a common theme throughout SLiDE;
    # may need to address.
    df[!,:value] .= convert_type.(Float64, df[:,:value])

    df = edit_with(df, Drop(:value, 0.0, "=="));
    return unique(sort(df, names(df)[1:end-1]));
end

# ******************************************************************************************

# PATHS TO DATA LOCATIONS:
# - path_side is general: the contents of this directory should have been created by
#     auto_standardize_data.
# - path_bluenote is specific to where Caroline stored WiNDC windc_datastream output.
#     This line must be changed to be consistent with user-specific file storage organizations.
path_slide = joinpath("data","output")
path_bluenote = joinpath("data","windc_output","1b_stream_windc_base")

y = read_file(joinpath("dev", "verify_data.yml"));
lst = y["FileInput"];

df_attn = Dict()

# Iterate through list of datafiles to compare and shared column names.
for inp in lst[[5]]
    println("\n",uppercase(inp.f1));

    # For SLiDE and bluenote data sets, read and save the DataFrames.
    dfs = read_file(joinpath(path_slide, inp.f1));
    global dfs = make_uniform(dfs, inp.colnames);

    dfb = read_file(joinpath(path_bluenote, inp.f2));
    global dfb = make_uniform(dfb, inp.colnames);
    
    # If comparing SEDS data, compare unstandardized units.
    # if occursin("seds", inp.f1)
    #     x = [Rename.([:units_0, :value_0], [:units, :value]);
    #          Replace.([:source_code, :sector_code], "lower", "upper");
    #          Map("parse/units.csv", [:from], [:to], [:units], [:units])];
    #     global dfs = edit_with(dfs, x)
    #     global dfb = edit_with(dfb, x)
    # end

    global df_keys = compare_keys(copy.([dfs, dfb]), [:slide, :bluenote]);
    size(df_keys,1) == 0 ? println("All keys are consistent.") : show(df_keys);
    println("");

    # Resolve MINOR discrepancy to compare values for heatrate calculations.
    x = Replace(:units, "btu per kWh generated", "btu per kilowatthour");
    global dfs = edit_with(dfs, x);
    global dfb = edit_with(dfb, x);

    # Compare values. Print a warning if there are discrepancies and
    # save the summary DataFrame in a list of DataFrames in need of attention.
    global df = compare_values(copy.([dfs, dfb]), [:slide, :bluenote]);
    size(df,1) > 0 && (df_attn[inp.f1[1:end-4]] = df)
end

# ******************************************************************************************
# cols = [:year, :state, :sgf_code, :units, :value];
# dfs = read_file(joinpath(path_slide, "sgf.csv"));
# dfs[!,:windc_code] .= ismissing.(dfs[:,:windc_code])
# dfs = unique(sort(dropmissing(dfs, :sgf_code), cols));
# display(first(dfs,4));

# dfb = read_file(joinpath(path_bluenote, "sgf_units.csv"));
# dfb = make_uniform(edit_with(dfb, Replace(:sgf_code, "othtax", "OTHTAX")), cols);
# display(first(dfb,4));