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
BLUE2 = joinpath("data", "windc_output", "2z_windcdatabase")
b2_lst = [x for x in readdir(joinpath(SLIDE_DIR, BLUE2)) if occursin(".csv", x)]
# b2 = Dict(Symbol(k[1:end-4]) => sort(edit_with(
#     read_file(joinpath(BLUE2, k))), Rename(:Val, :value))) for k in b2_lst)

BLUE_DIR = joinpath("data", "windc_output", "2a_io_national_cgeparm_raw")
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
y = read_file(joinpath("data","readfiles","list_sets.yml"));
set = Dict(Symbol(k) => sort(read_file(joinpath(y["Path"]..., ensurearray(v)...)))[:,1]
    for (k,v) in y["Input"])

# Read supply/use data.
DATA_DIR = joinpath("data", "input")
io_lst = convert_type.(Symbol, ["supply", "use"])
jo = Dict(k => read_file(joinpath(DATA_DIR, string(k, ".csv"))) for k in io_lst)

# Perform some minor edits that will apply to all parameters in order to maintain
# consistency with the data in build_national_cgeparm_raw.gdx for easier benchmarking.

for k in keys(jo)
    global jo[k] = edit_with(jo[k], [Rename(:value, k); Drop.([:value,:units], [0.,"all"], "==")])
    global jo[k] = jo[k] |> @filter(_.yr in set[:yr]) |> DataFrame

    # global jo[k][!,:value] .= round.(jo[k][:,:value]*1E-3, digits=3)
    # global jo[k][!,:units] .= UNITS
end

jo[:supply], jo[:use] = fill_zero(jo[:supply], jo[:use]; permute_keys = true);

df = jo[:supply][:,find_oftype(jo[:supply], Not(AbstractFloat))]
df = hcat(df, [edit_with(jo[k],Rename(:value,k))[:,[k]] for k in sort(collect(keys(jo)))]...)
df = fill_zero((yr = set[:yr], i = set[:i], j = set[:j]), df)

# df = copy(df)
# x = (i = set[:i], j = set[:j])
# col = [:a, :b]

function add_filter(df::DataFrame, col::Array{Symbol,1}, set)
    df = copy(df)
    cols = intersect(find_oftype(df, Not(AbstractFloat)), find_oftype(df, Not(Bool)))
    inset = [col in collect(keys(set)) for col in cols]

    vals_sets = [[set[k] for k in cols[inset]]; unique.(eachcol(df[:,cols[.!inset]]))]
    cols_sets = [cols[inset]; cols[.!inset]]

    df_sets = edit_with(DataFrame(permute(NamedTuple{Tuple(cols_sets,)}(vals_sets,))),
        Add.(col, true))
    df = leftjoin(df, df_sets, on = cols_sets)

    df = edit_with(df, Replace.(col, missing, false))
    return df
end

s = Dict()


mutable struct Filter
    set::NamedTuple
    col::Array{Symbol,1}
end

filters = []

push!(filters, Filter((yr = set[:yr], i = set[:i], j = set[:j]),     [:ys0, :id0]))
push!(filters, Filter((yr = set[:yr], i = set[:i], j = set[:fd]),    [:fd0]))
push!(filters, Filter((yr = set[:yr], i = set[:va], j = set[:j]),    [:va0]))
push!(filters, Filter((yr = set[:yr], i = set[:ts], j = set[:j]),    [:ts0]))

push!(filters, Filter((yr = set[:yr], i = set[:i], j = "exports"),   [:x0]))
push!(filters, Filter((yr = set[:yr], i = set[:i], j = "imports"),   [:m0]))
push!(filters, Filter((yr = set[:yr], i = set[:i], j = "margins"),   [:mrg0]))
push!(filters, Filter((yr = set[:yr], i = set[:i], j = "trncost"),   [:trn0]))
push!(filters, Filter((yr = set[:yr], i = set[:i], j = "ciffob"),    [:cif0]))
push!(filters, Filter((yr = set[:yr], i = set[:i], j = "duties"),    [:duty0]))
push!(filters, Filter((yr = set[:yr], i = set[:i], j = "tax"),       [:tax0]))
push!(filters, Filter((yr = set[:yr], i = set[:i], j = "subsidies"), [:sbd0]))

# Create DataFrame from filters.
df_filtered = copy(df[:,[:yr,:i,:j]])
[global df_filtered = add_filter(df_filtered, f.col, f.set) for f in filters]

# Create final DataFrames
ij = fill_zero((yr = set[:yr], i = set[:i], j = set[:j]))[:,1:end-1]
i  = fill_zero((yr = set[:yr], i = set[:i]))[:,1:end-1]
fd = fill_zero((yr = set[:yr], i = set[:i], fd = set[:fd]))[:,1:end-1]
ts = fill_zero((yr = set[:yr], ts = set[:ts], j = set[:j]))[:,1:end-1]
va = fill_zero((yr = set[:yr], va = set[:va], j = set[:j]))[:,1:end-1]

kij = [:ys0,:id0]
vij = [:supply,:use]

ki = [:x0,:m0,:mrg0,:trn0,:cif0,:duty0,:tax0,:sbd0]
vi = [:use; fill(:supply,7)]

[global i[!,k] .= df[df_filtered[:,k],v] for (k,v) in zip(ki,vi)]
[global ij[!,k] .= df[df_filtered[:,k],v] for (k,v) in zip(kij,vij)]
fd[!,:fd0] = df[df_filtered[:,:fd0],:use]
ts[!,:ts0] = df[df_filtered[:,:ts0],:use]
va[!,:va0] = df[df_filtered[:,:va0],:use]

# Treat negative inputs as outputs.
ij[!,:ys0] = ij[:,:ys0] - min.(0, ij[:,:id0])
ij[!,:id0] = max.(0, ij[:,:id0])