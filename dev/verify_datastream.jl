using CSV
using DataFrames
using DelimitedFiles
using SLiDE

function make_uniform(df::DataFrame, cols::Array{Symbol,1})
    size(names(df)) == size(cols) ?
        df = edit_with(df, Rename.(names(df), cols))[:,cols] : nothing
    df = df[:,cols]
        
    df = edit_with(df, Drop(:value, 0.0, "=="));
    return unique(sort(df, names(df)[1:end-1]));
end

function compare_summary(df1::DataFrame, df2::DataFrame, ind::Array{Symbol,1}; value = :value)
    
    df1 = copy(df1)
    df2 = copy(df2)

    vals = Symbol.(value, :_, ind)
    [df = edit_with(df, [Add(col, true); Rename.(:value, Symbol(value, :_, col))])
        for (df, col) in zip([df1,df2], ind)]
    cols = intersect(names(df1), names(df2))

    df = size(df2,1) > size(df1,1) ?
        join(df1, df2, on = cols, kind = :right) :
        join(df1, df2, on = cols, kind = :left)

    for col in ind
        df[ismissing.(df[:,col]),col] .= false
        df[!,col] *= true
    end

    df[!,:equal_set] .= prod.(eachrow(df[:,ind]))
    df[!,:equal_value] .= df[:,vals[1]] .== df[:,vals[2]]

    return df[:,[cols; vals; ind; [:equal_set, :equal_value]]]
end

function compare_values(df1::DataFrame, df2::DataFrame, ind::Array{Symbol,1}; value = :value)

    cols = intersect(names(df1),names(df2))
    
    df1 = copy(df1[:,cols]);
    df2 = copy(df2[:,cols]);

    df = dropmissing(compare_summary(df1, df2, ind;), :equal_value);
    df = df[.!df[:,:equal_value],:];

    size(df,1) == 0 ?
        println("All values are consistent.") :
        println("Values inconsistent:")

    return df
end

function compare_sets(df1::DataFrame, df2::DataFrame, ind::Array{Symbol,1}; value = :value)

    df_dict = Dict(k => df for (df, k) in zip([df1,df2], ind))
    cols = setdiff(intersect(names(df1), names(df2)), [value])

    d = Dict(k1 => Dict(k2 =>
            unique(setdiff(df[:,k2], df_dict[setdiff(ind,[k1])[1]][:,k2]))
        for k2 in cols) for (k1,df) in df_dict)

    # df = [[edit_with(DataFrame(Dict(col => length(v) == 0 ? "" : v for (col,v) in d)),
    #         Add.([k; setdiff(ind,[k])], [true,false])) for (k,d) in d_all]...;]
    # df = df[.!all.(eachrow(df[:,cols] .== "")), :];

    all([[length.(collect(values(d1))) for (k1,d1) in d]...;] .== 0) ?
        println("All sets are consistent.") :
        println("Summary of set differences:")

    for (k1,d1) in d
        any(length.(collect(values(d1))) .!== 0) ? println("  ", k1, " only") : continue
        for (k2,v2) in d1
            length(v2) !== 0 ? println("    ", k2, ":  ", string.(v2," ")...,) : continue
        end
    end
    return d
end

# ******************************************************************************************s

path_slide = joinpath("..","data","output")
path_bluenote = joinpath("..","data","windc_output","2_stream")

df_slide = DataFrame()
df_bluenote = DataFrame()



# mutable struct Compare <: Edit
#     col::Array{Symbol,1}
#     f1::String
#     f2::String
# end



# ******************************************************************************************
# cols = [:year, :input_bea_windc, :output_bea_windc, :units, :value]

# f_slide = ["bea_use.csv", "bea_supply.csv", "bea_use_det.csv", "bea_supply_det.csv"];
# f_bluenote = ["use_units.csv", "supply_units.csv", "use_det_units.csv", "supply_det_units.csv"];

# for (fs, fb) in zip(f_slide, f_bluenote)
#     println("\n",fs);

#     df_slide = read_file(joinpath(path_slide, fs));
#     global df_slide = make_uniform(df_slide, cols);

#     df_bluenote = read_file(joinpath(path_bluenote, fb));
#     global df_bluenote = make_uniform(df_bluenote, cols);

#     d = compare_sets(df_slide, df_bluenote, [:slide, :bluenote]);

#     df_bluenote = edit_with(df_bluenote, Replace(:output_bea_windc, "subsidies", "Subsidies"))

#     df = compare_values(df_slide, df_bluenote, [:slide, :bluenote]);
# end

# ******************************************************************************************
# cols = [:region_desc, :year, :component, :industry_id, :units, :value]

# fs = "gsp_state.csv"
# fb = "gsp_units.csv"

# println("")
# # for (fs, fb) in zip(f_slide, f_bluenote)

#     # println(fs);

# df_slide = read_file(joinpath(path_slide, fs));
# df_slide = make_uniform(df_slide, cols);
# # display(first(df_slide,4))

# df_bluenote = read_file(joinpath(path_bluenote, fb));
# df_bluenote = make_uniform(df_bluenote, cols);
# # display(first(df_bluenote,4))

# d = compare_sets(df_slide, df_bluenote, [:slide, :bluenote]);
# df = compare_values(df_slide, df_bluenote, [:slide, :bluenote]);
# end

println("")

# ******************************************************************************************
cols = [:year, :region_desc, :windc_code, :units, :value]

fs = "pce.csv"
fb = "pce_units.csv"

println("")
# for (fs, fb) in zip(f_slide, f_bluenote)

    # println(fs);

df_slide = read_file(joinpath(path_slide, fs));
df_slide = make_uniform(df_slide, cols);
display(first(df_slide,4))

df_bluenote = read_file(joinpath(path_bluenote, fb));
df_bluenote = make_uniform(df_bluenote, cols);
display(first(df_bluenote,4))

d = compare_sets(df_slide, df_bluenote, [:slide, :bluenote]);
df = compare_values(df_slide, df_bluenote, [:slide, :bluenote]);
# end

println("")