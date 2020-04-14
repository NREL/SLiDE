using CSV
using DataFrames
using DelimitedFiles
using Printf

using SLiDE

function make_uniform(df::DataFrame, cols::Array{Symbol,1})
    .&(size(names(df)) == size(cols), length(setdiff(cols, names(df))) > 0) ?
        df = edit_with(df, Rename.(names(df), cols))[:,cols] : nothing
    df = df[:,cols]
        
    df = edit_with(df, Drop(:value, 0.0, "=="));
    return unique(sort(df, names(df)[1:end-1]));
end

function compare_summary(df_lst::Array{DataFrame,1}, ind::Array{Symbol,1}; value = :value)
    df_lst = copy(df_lst)

    # Sort inputs in order of longest to shortest DataFrame.
    # This is important when preserving missing values to indicate inconsistencies.
    ii_sort = reverse(sortperm(size.(df_lst,1)))
    df_lst = df_lst[ii_sort]
    ind = ind[ii_sort]

    vals = Symbol.(value, :_, ind)
    [df = edit_with(df, [Add(col, true); Rename.(value, Symbol(value, :_, col))])
        for (df, col) in zip(df_lst, ind)]
    cols = intersect(intersect(names.(df_lst)...))

    df = df_lst[1]
    [df = join(df, df_lst[ii], on = cols, kind = :left) for ii in 2:length(ind)]
    [df[!,col] .= .!ismissing.(df[:,col]) for col in ind]

    # Are all keys equal/present in the DataFrame?
    df[!,:equal_keys] .= prod.(eachrow(df[:,ind]))
    
    # Are there discrepancies between PRESENT values?
    # df[!,:equal_values] .= df[:,vals[1]] .== df[:,vals[2]]
    ii_compare = sum.(eachrow(.!ismissing.(df[:,vals]))) .!= 1;
    df[!,:equal_values] .= [x ? x : missing for x in ii_compare];
    # df[ii_compare,:equal_values] .= length.(unique.(eachrow(df[ii_compare,vals]))) .== 1
    df[ii_compare,:equal_values] .= length.(unique.(skipmissing.(eachrow(df[ii_compare,vals])))) .== 1

    return sort(df[:,[cols; sort(vals); sort(ind); [:equal_keys, :equal_values]]], cols)
end

function compare_values(df_lst::Array{DataFrame,1}, ind::Array{Symbol,1}; value = :value)
    df_lst = copy(df_lst)

    df = dropmissing(compare_summary(copy.(df_lst), ind;), :equal_values);
    df = df[.!df[:,:equal_values],:];
    size(df,1) == 0 ? println("All values are consistent.") : @warn("Values inconsistent.")
    return df
end

function compare_keys(df_lst::Array{DataFrame,1}, ind::Array{Symbol,1}; value = :value)
    df_lst = copy(df_lst)

    N = length(ind);
    cols = setdiff(intersect(names.(df_lst)...), [value])
    ii_other = setdiff.(fill(1:N,N), 1:N)

    d_temp = Dict(col => Dict(ind[ii] =>
            setdiff(unique(df_lst[ii][:,col]), unique([df_lst[ii_other[ii]]...;][:,col]))
        for ii in 1:N) for col in cols)

    # [all(length.(values(d1)).==0) ? pop!(d_temp,k1) :
    #     [pop!(d_temp[k1],k2) for (k2,d2) in d1 if length(d2)==0] for (k1,d1) in d_temp]

    d = Dict(k1 => Dict(k2 => sort(d2) for (k2,d2) in d1 if length(d2) != 0)
        for (k1,d1) in d_temp if any(length.(values(d1)).!==0))
    
    # Print summary.
    isempty(d) ? println("All sets are consistent.") : println("Set differences:")
    for (k1,d1) in d
        @printf("  %s\n", k1)
        [@printf("    %-10s[%s]\n", k2,
                string((length(d2) > 1 ? string.(d2[1:end-1], ", ") : "")..., d2[end]))
            for (k2,d2) in d1]
    end
    return d_temp
end

# ******************************************************************************************

path_slide = joinpath("..","data","output")
path_bluenote = joinpath("..","data","windc_output","2_stream")

dfs = DataFrame()
dfb = DataFrame()

y = read_file("verify_data.yml");
lst = y["FileInput"];

df_attn = Dict()

# for inp in lst
#     println("\n",uppercase(inp.f1));

#     dfs = read_file(joinpath(path_slide, inp.f1));
#     global dfs = make_uniform(dfs, inp.colnames);

#     dfb = read_file(joinpath(path_bluenote, inp.f2));
#     global dfb = make_uniform(dfb, inp.colnames);

#     if occursin("seds", inp.f1)
#         x = [Rename.([:units_0, :value_0], [:units, :value]);
#              Replace.([:source_code, :sector_code], "lower", "upper");
#              Map("parse/units.csv", [:from], [:to], [:units], [:units])];
#         global dfs = edit_with(dfs, x)
#         global dfb = edit_with(dfb, x)
#     end

#     d = compare_keys(copy.([dfs, dfb]), [:slide, :bluenote]);

#     # Resolve MINOR discrepancies to compare values.
#     x = [Replace(:output_bea_windc, "subsidies", "Subsidies"),  # bea
#          Replace(:component,        "Tax",       "tax"),        # gsp
#          Replace(:sgf_code,         "othtax",    "OTHTAX"),     # sgf
#          Replace(:units, "btu per kWh generated", "btu per kilowatthour") # heatrate
#     ]

#     global dfs = edit_with(dfs, x);
#     global dfb = edit_with(dfb, x);

#     global df = compare_values(copy.([dfs, dfb]), [:slide, :bluenote]);
#     size(df,1) > 0 ? df_attn[inp.f1[1:end-4]] = df : nothing
# end

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
# TESTING
# df = compare_summary(copy.([dfs,dfb]), [:slide,:bluenote]);

# dfa = dfs[.&(dfs[:,:year] .> 2014),:];
# dfb = edit_with(dfa, Drop.(:source,["oil"],"=="));
# dfc = copy(dfb);
# dfc[.&(dfc[:,:source] .== "gas"), :value] *= 10;
# dfc[4,:value] *= 10;
# dfa = dfa[1:end-1,:]

# ******************************************************************************************