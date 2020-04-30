using CSV
using DataFrames
using DelimitedFiles
using Printf
using Statistics

using SLiDE

"""
    make_uniform(df::DataFrame, cols::Array{Symbol,1})
This function is specific to the 
"""
function make_uniform(df::DataFrame, cols::Array{Symbol,1})
    .&(size(names(df)) == size(cols), length(setdiff(cols, names(df))) > 0) ?
        df = edit_with(df, Rename.(names(df), cols))[:,cols] : nothing
    df = df[:,cols]
        
    df = edit_with(df, Drop(:value, 0.0, "=="));
    return unique(sort(df, names(df)[1:end-1]));
end

function print_key_comparison(d)
    isempty(d) ? println("All sets are consistent.") : println("Set differences:")
    for (k1,d1) in d
        @printf("  %s\n", k1)
        [@printf("    %-10s[%s]\n", k2,
                string((length(d2) > 1 ? string.(d2[1:end-1], ", ") : "")..., d2[end]))
            for (k2,d2) in d1]
    end
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
for inp in lst[1:end-1]
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
    size(df,1) > 0 ? df_attn[inp.f1[1:end-4]] = df : nothing
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

# ******************************************************************************************
# cols = [:orig_state, :dest_state, :naics, :sctg, :units, :value];
# dfs = read_file(joinpath(path_slide, "cfs_state.csv"));
# dfs = make_uniform(dfs, cols);
# display(first(dfs,4));

# dfb = read_file(joinpath(path_bluenote, "cfsdata_st_units.csv"));
# dfb = make_uniform(dfb, cols);
# # dfb = edit_with(dfb, Rename.(names(dfb),cols))
# display(first(dfb,4));

# d = compare_keys(copy.([dfs,dfb]), [:slide,:bluenote])
# df = compare_summary(copy.([dfs,dfb]), [:slide,:bluenote]);



# ******************************************************************************************
# dfs = read_file(joinpath(path_slide, "cfs.csv"));


# ******************************************************************************************
# TESTING -- Make three DataFrames with differing keys and values to test the compare_*.
# N = 2
# dfa = DataFrame(yr = sort(repeat([2019,2020], outer=[2])),
#                 r = repeat(["co","wi"], outer=[2]),
#                 v1 = Float64.(1:N*2),
#                 # v2 = Float64.(1:N*2),
#                 );
# dfb = edit_with(copy(dfa), Drop(:r, "co", "=="))

# dfc = copy(dfa)

# dfc[2,:r] = "md"
# dfc[3,:r] = "Co"
# dfc[end,:v1] = 1.

# df_lst = copy.([dfa,dfb,dfc]);
# inds = [:a,:b,:c];
# tol = 1E-6