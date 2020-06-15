using CSV
using DataFrames
using DelimitedFiles
using YAML
using Query

using SLiDE

UNITS = "billions of us dollars (USD)"

# ******************************************************************************************
#   READ BLUENOTE DATA -- For benchmarking!
# ******************************************************************************************
BLUE_DIR = joinpath("data", "windc_output", "2a_build_national_cgeparm_raw")
bluenote_lst = [x for x in readdir(joinpath(SLIDE_DIR, BLUE_DIR)) if occursin(".csv", x)]
bluenote = Dict(Symbol(k[1:end-4]) => sort(edit_with(
    read_file(joinpath(BLUE_DIR, k)), Rename(:Val, :value))) for k in bluenote_lst)

# Add supply/use info for checking.
BLUE_DIR_IN = joinpath("data", "windc_output", "1b_stream_windc_base")
[bluenote[k] = sort(edit_with(read_file(joinpath(BLUE_DIR_IN, string(k, "_units.csv"))), [
    Rename.([:Dim1,:Dim2,:Dim3,:Dim4,:Val], [:yr,:i,:j,:units,:value]);
    Replace.([:i,:j], "upper", "lower")])) for k in [:supply, :use]]

[bluenote[k][!,:value] .= round.(bluenote[k][:,:value]*1E-3, digits=3) # convert millions -> billions USD
    for k in [:supply,:use]]

# ******************************************************************************************
#   READ SETS AND SLiDE SUPPLY/USE DATA.
# ******************************************************************************************
y = read_file(joinpath("dev","buildstream","setlist.yml"));
set = Dict(Symbol(k) => sort(read_file(joinpath(y["SetPath"]..., ensurearray(v)...)))[:,1]
    for (k,v) in y["SetInput"])

# Read supply/use data.
DATA_DIR = joinpath("data", "output")
io_lst = convert_type.(Symbol, ["supply", "use"])
io = Dict(k => read_file(joinpath(DATA_DIR, string(k, ".csv"))) for k in io_lst)

# Perform some minor edits that will apply to all parameters in order to maintain
# consistency with the data in build_national_cgeparm_raw.gdx for easier benchmarking.

for k in keys(io)
    global io[k] = edit_with(io[k], Drop.([:value], [0.], "=="))
    global io[k] = io[k] |> @filter(_.yr in set[:yr]) |> DataFrame

    # global io[k][!,:value] .= round.(io[k][:,:value]*1E-3, digits=3)
    # global io[k][!,:units] .= UNITS
end

io[:supply], io[:use] = fill_zero(io[:supply], io[:use]; permute_keys = true);

# ******************************************************

# io[:id0] = io[:use] |> @filter(.&(_.i in set[:i],  _.j in set[:j] ))  |> DataFrame


df = io[:use]


# function filter_with(df::DataFrame, set::Dict)




    cols = find_oftype(df, Not(AbstractFloat))

    cols_sets = intersect(cols, collect(keys(set)));
    vals_sets = [set[k] for k in cols_sets]
    set = NamedTuple{Tuple(cols_sets,)}(vals_sets,)

    # df = filter_with(df, NamedTuple{Tuple(cols_sets,)}(vals_sets,))

    # df_sets = DataFrame(permute(NamedTuple{Tuple(cols_sets,)}(vals_sets,)));

    # # Drop values that are not in the current set.
    # df = join(df, df_sets, on = cols_sets, kind = :inner)

    # # Fill zeros.
    # vals_sets = [vals_sets; unique.(eachcol(df[:,setdiff(cols,cols_sets)]))]
    # list_sets = NamedTuple{Tuple(cols,)}(vals_sets,)
    # df = fill_zero(list_sets, df);
    # return df
# end


# function filter_with(df::DataFrame, set::NamedTuple)
    cols = find_oftype(df, Not(AbstractFloat))
    df_sets = DataFrame(permute(set));

    # Drop values that are not in the current set.
    df = join(df, df_sets, on = cols_sets, kind = :inner)
    
    # Fill zeros.
    vals_sets = [vals_sets; unique.(eachcol(df[:,setdiff(cols,cols_sets)]))]
    list_sets = NamedTuple{Tuple(cols,)}(vals_sets,)
    df = fill_zero(list_sets, df);
    return df
# end