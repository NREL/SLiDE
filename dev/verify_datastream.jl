using CSV
using DataFrames
using DelimitedFiles
using Printf

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

"""
    compare_summary(df_lst::Array{DataFrame,1}, inds::Array{Symbol,1}; value = :value)
"""
function compare_summary(df_lst::Array{DataFrame,1}, inds::Array{Symbol,1}; value = :value)
    df_lst = copy(df_lst)

    vals = Symbol.(value, :_, inds)
    df_lst = [edit_with(df, Rename.(value, val)) for (df, val) in zip(df_lst, vals)]
    cols = intersect(intersect(names.(df_lst)...))

    df = df_lst[1]
    [df = join(df, df_lst[ii], on = cols, kind = :outer) for ii in 2:length(inds)]
    [df[!,ind] .= .!ismissing.(df[:,val]) for (ind, val) in zip(inds, vals)]
    
    # Are all keys equal/present in the DataFrame?
    df[!,:equal_keys] .= prod.(eachrow(df[:,inds]))
    
    # Are there discrepancies between PRESENT values?
    ii_compare = sum.(eachrow(.!ismissing.(df[:,vals]))) .!= 1;
    df[!,:equal_values] .= [x ? x : missing for x in ii_compare];
    df[ii_compare,:equal_values] .= length.(unique.(skipmissing.(eachrow(df[ii_compare,vals])))) .== 1

    # If we want to consider cases with missing values as unequal, instead use:
    # df[ii_compare,:equal_values] .= length.(unique.(eachrow(df[ii_compare,vals]))) .== 1

    return sort(df[:,[cols; sort(vals); sort(inds); [:equal_keys, :equal_values]]], cols)
end

"""
    compare_values(df_lst::Array{DataFrame,1}, inds::Array{Symbol,1}; value = :value)
"""
function compare_values(df_lst::Array{DataFrame,1}, inds::Array{Symbol,1}; value = :value)
    df_lst = copy(df_lst)

    df = dropmissing(compare_summary(copy.(df_lst), inds;), :equal_values);
    df = df[.!df[:,:equal_values],:];
    size(df,1) == 0 ? println("All values are consistent.") : @warn("Values inconsistent.")
    return df
end

"""
    compare_keys2(df_lst::Array{DataFrame,1}, inds::Array{Symbol,1}; value = :value)
"""
function compare_keys2(df_lst::Array{DataFrame,1}, inds::Array{Symbol,1}; value = :value)
    df_lst = copy(df_lst)

    N = length(inds);
    cols = setdiff(intersect(names.(df_lst)...), [value])
    ii_other = setdiff.(fill(1:N,N), 1:N)

    d_temp = Dict(col => Dict(inds[ii] =>
            setdiff(unique(df_lst[ii][:,col]), unique([df_lst[ii_other[ii]]...;][:,col]))
        for ii in 1:N) for col in cols)

    d = Dict(k1 => Dict(k2 => sort(d2) for (k2,d2) in d1 if length(d2) != 0)
        for (k1,d1) in d_temp if any(length.(values(d1)).!==0))
    return d
end


function compare_keys(df_lst::Array{DataFrame,1}, inds::Array{Symbol,1}; value = :value)
    df_lst = copy(df_lst)

    N = length(inds);
    cols = setdiff(intersect(names.(df_lst)...), [value])
    ii_other = setdiff.(fill(1:N,N), 1:N)

    d_unique = Dict(col => Dict(inds[ii] => sort(unique(df_lst[ii][:,col]))
        for ii in 1:N) for col in cols);
    d_lower = Dict(col => Dict(inds[ii] => lowercase.(d_unique[col][inds[ii]]) for ii in 1:N) for col in cols);

    CHECKCASE = Dict(col => any(length.(unique.(values(d_lower[col]))) .!==
        length.(values(d_unique[col]))) for col in cols)

    d_all = Dict(col => CHECKCASE[col] ? sort(unique([values(d_unique[col])...;])) :
        sort(unique([values(d_lower[col])...;])) for col in cols);

    df = DataFrame()

    for col in cols

        df_temp = DataFrame(key = fill(col, size(d_all[col])))
        d_check = CHECKCASE[col] ? d_unique[col] : d_lower[col]

        [df_temp[!,ind] = [v in d_check[ind] ? d_unique[col][ind][v .== d_check[ind]][1] :
            missing for v in d_all[col]] for ind in inds]
        df_temp = unique(df_temp[length.(unique.(eachrow(df_temp[:,inds]))) .> 1, :])

        df = vcat(df,df_temp)
    end
    return df
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

path_slide = joinpath("..","data","output")
path_bluenote = joinpath("..","data","windc_output","2_stream")

dfs = DataFrame()
dfb = DataFrame()

y = read_file("verify_data.yml");
lst = y["FileInput"];

df_attn = Dict()

# for inp in lst[[end]]

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

#     global df_keys = compare_keys(copy.([dfs, dfb]), [:slide, :bluenote]);
#     size(df_keys,1) == 0 ? println("All keys are consistent.") : show(df_keys);
#     println("");

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


# N = 2
# dfa = DataFrame(year = sort(repeat([2019,2020], outer=[2])),
#                 region = repeat(["co","wi"], outer=[2]),
#                 value = 1:N*2);
# dfb = edit_with(copy(dfa), Drop(:region, "co", "=="))

# dfc = copy(dfa)

# dfc[2,:region] = "md"
# # dfc[3,:region] = "Co"
# dfc[end,:value] = 1

# # ******************************************************************************************
# df_lst = copy.([dfa,dfb,dfc]);
# inds = [:a,:b,:c];

# leavespace = false;

# df = compare_keys(df_lst, inds)

# LENS = [length.(skipmissing(values(row)))[1] for row in eachrow(df[:,inds])];
# [df[ismissing.(df[:,ind]),ind] .= repeat.(" ", LENS[ismissing.(df[:,ind])]) for ind in inds]

# d = Dict(key => Dict(ind => df[df[:,:key] .== key, ind] for ind in inds) for key in allkeys)

# print_key_comparison(df::DataFrame; leavespace = false)

# df = copy(df_keys)
# df[!,:other] .= df[:,:bluenote] + 1.1



# df = convert_type.(String, df);
# inds = names(df)[2:end];
# allkeys = unique(df[:,1]);


# [df[ismissing.(df[:,ind]),ind] .= "" for ind in inds]

# d = Dict(key => Dict(ind => unique(skipmissing(df[df[:,:key] .== key, ind])) for ind in inds) for key in allkeys)



    # df_temp = DataFrame(keys = sort(unique([[df[:,col] for df in df_lst]...;])));

    
    # [df_temp[!,k2] .= [k3 in lowercase.(d_unique[k1][k2]) ? d_unique[k1][k2][k3 .== lowercase.(d_unique[k1][k2])][1] : missing for k3 in df_temp[:,:keys]] for k2 in inds]
    



#     d_temp = Dict(col => Dict(inds[ii] =>
#             setdiff(unique(df_lst[ii][:,col]), unique([df_lst[ii_other[ii]]...;][:,col]))
#         for ii in 1:N) for col in cols)

#     # [all(length.(values(d1)).==0) ? pop!(d_temp,k1) :
#     #     [pop!(d_temp[k1],k2) for (k2,d2) in d1 if length(d2)==0] for (k1,d1) in d_temp]

#     d = Dict(k1 => Dict(k2 => sort(d2) for (k2,d2) in d1 if length(d2) != 0)
#         for (k1,d1) in d_temp if any(length.(values(d1)).!==0))
    


# for (k1,d1) in d
#     @printf("  %s\n", k1)
#     [@printf("    %-10s[%s]\n", k2,
#             string((length(d2) > 1 ? string.(d2[1:end-1], ", ") : "")..., d2[end]))
#         for (k2,d2) in d1]
# end





    # Print summary.
    # isempty(d) ? println("All sets are consistent.") : println("Set differences:")

    # for (k1,d1) in d
    #     @printf("  %s\n", k1)
    #     [@printf("    %-10s[%s]\n", k2,
    #             string((length(d2) > 1 ? string.(d2[1:end-1], ", ") : "")..., d2[end]))
    #         for (k2,d2) in d1 if length(d2) > 0]
        



        # [@printf("    %-10s%s\n", k2, string(string.(d2, " ")...)) for (k2,d2) in d1]
    # end
    # return d
# # end