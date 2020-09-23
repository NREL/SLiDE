using CSV
using DataFrames
using DelimitedFiles
using YAML
using Query

using SLiDE

println("\nPARTITION BEA SUPPLY/USE DATA INTO PARAMETERS:")
UNITS = "billions of us dollars (USD)"
include(joinpath(SLIDE_DIR, "dev", "buildstream", "build_functions.jl"))


# ******************************************************************************************
#   READ BLUENOTE DATA -- For benchmarking!
# ******************************************************************************************
BLUE_DIR_IO = joinpath("data", "windc_output", "2a_io_national_cgeparm_raw")
bluenote_lst_io = [x for x in readdir(joinpath(SLIDE_DIR, BLUE_DIR_IO)) if occursin(".csv", x)]
io = Dict(Symbol(k[1:end-4]) => sort(edit_with(
    read_file(joinpath(BLUE_DIR_IO, k)), Rename(:Val, :value))) for k in bluenote_lst_io)

# # Add supply/use info for checking.
# BLUE_DIR_IN = joinpath("data", "windc_output", "1b_stream_windc_base")
# [bio[k] = sort(edit_with(read_file(joinpath(BLUE_DIR_IN, string(k, "_units.csv"))), [
#     Rename.([:Dim1,:Dim2,:Dim3,:Dim4,:Val], [:yr,:i,:j,:units,:value]);
#     Replace.([:i,:j], "upper", "lower")])) for k in [:supply, :use]]

# [bio[k][!,:value] .= round.(bio[k][:,:value]*1E-3, digits=3) # convert millions -> billions USD
#     for k in [:supply,:use]]

# ******************************************************************************************
#   READ SETS AND SLiDE SUPPLY/USE DATA.
# ******************************************************************************************
println("  Reading sets...")
y = read_file(joinpath("data", "readfiles", "list_sets.yml"));
set = Dict(Symbol(k) => sort(read_file(joinpath(y["SetPath"]..., ensurearray(v)...)))[:,1]
    for (k,v) in y["SetInput"])

# Read supply/use data.
println("  Reading supply/use data...")
DATA_DIR = joinpath("data", "input")
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

# Read from use data.
# "Intermediate demand"
# "Final demand"
# "Value added"
# "Taxes and subsidies"
# "Exports of goods and services"
println("  Extracting parameters from USE data...")
io[:id0] = filter_with(io[:use], set)
io[:fd0] = filter_with(io[:use], (i = set[:i],  j = set[:fd]))
io[:va0] = filter_with(io[:use], (i = set[:va], j = set[:j]))
io[:ts0] = filter_with(io[:use], (i = set[:ts], j = set[:j]))
io[:x0]  = filter_with(io[:use], (i = set[:i],  j = "exports"))

io[:fd0] = edit_with(io[:fd0], Rename(:j, :fd));
io[:va0] = edit_with(io[:va0], Rename(:i, :va));

# Read from supply data.
# "Sectoral supply"
# "Imports"
# "Trade margins"
# "Transportation costs"
# "CIF/FOB Adjustments on Imports"
# "Import duties"
# "Taxes on products"
# "Subsidies on products"
println("  Extracting parameters from SUPPLY data...")
io[:ys0]   = filter_with(io[:supply], set)
io[:m0]    = filter_with(io[:supply], (i = set[:i], j = "imports"))
io[:mrg0]  = filter_with(io[:supply], (i = set[:i], j = "margins"))
io[:trn0]  = filter_with(io[:supply], (i = set[:i], j = "trncost"))
io[:cif0]  = filter_with(io[:supply], (i = set[:i], j = "ciffob"))
io[:duty0] = filter_with(io[:supply], (i = set[:i], j = "duties"))
io[:tax0]  = filter_with(io[:supply], (i = set[:i], j = "tax"))
io[:sbd0]  = filter_with(io[:supply], (i = set[:i], j = "subsidies"))

# Treat negative inputs as outputs.
io[:ys0][!,:value] = io[:ys0][:,:value] - min.(0, io[:id0][:,:value])
io[:id0][!,:value] = max.(0, io[:id0][:,:value])
io[:ts0][io[:ts0][:,:i] .== "subsidies", :value] *= -1
io[:sbd0][!,:value] *= -1

# Adjust transport margins for transport sectors according to CIF/FOB adjustments.
# Insurance imports are specified as net of adjustments.
i_ins = io[:cif0][:,:i] .== "ins"
io[:trn0][.!i_ins, :value] .= io[:trn0][.!i_ins,:value] + io[:cif0][.!i_ins,:value]
io[:m0  ][  i_ins, :value] .= io[:m0][i_ins,:value] + io[:cif0][i_ins,:value]
io[:cif0][      !, :value] .= 0.0

println("  Calculating parameters...")
# "Aggregate supply"
# "Gross output"
io[:s0] = sum_over(io[:ys0], :i; values_only = false)
io[:y0] = sum_over(io[:ys0], :j; values_only = false)

# "Balance of payments deficit"
io[:bopdef] = fill_zero((yr = set[:yr], ))

# "Margin supply"
io[:ms0] = fill_zero((yr = set[:yr], i = set[:i], m = set[:m]))
io[:ms0][io[:ms0][:,:m] .== "trd", :value] .= max.(-io[:mrg0][:,:value], 0)
io[:ms0][io[:ms0][:,:m] .== "trn", :value] .= max.(-io[:trn0][:,:value], 0)

# "Margin demand" !!!! should this be (yr,m,j) instead of (yr,m,i)?
io[:md0] = fill_zero((yr = set[:yr], m = set[:m], i = set[:i]))
io[:md0][io[:md0][:,:m] .== "trd", :value] .= max.(io[:mrg0][:,:value], 0)
io[:md0][io[:md0][:,:m] .== "trn", :value] .= max.(io[:trn0][:,:value], 0)

# "Household supply"
# Move household supply of recycled goods into the domestic output market
# from which some may be exported. Net out margin supply from output.
io[:fs0] = filter_with(io[:fd0], (fd = "pce",))
io[:fs0][!,:value] .= - min.(io[:fs0][:,:value], 0)
io[:y0][!,:value]  .= sum_over(io[:ys0], :j) + io[:fs0][:,:value] - sum_over(io[:ms0], :m)

# "Armington supply"
io[:a0] = fill_zero((yr = set[:yr], i = set[:i]))
io[:a0][!,:value] .= sum_over(io[:fd0], :fd) + sum_over(io[:id0], :j)

# Remove commodity taxes and subsidies on the goods which are produced solely
# for supplying retail sales margin:
# Here's how to do this: https://discourse.julialang.org/t/dataframes-obtaining-the-subset-of-rows-by-a-set-of-values/15923/10
[io[k][findall(in(set[:imrg]), io[k][:,:i]), :value] .= 0.0
    for k in [:y0, :a0, :tax0, :sbd0, :x0, :m0, :md0, :duty0]]

# "Tax net subsidy rate on intermediate demand."
io[:tm0] = fill_zero((yr = set[:yr], i = set[:i]))
i_div = io[:m0][:,:value] .!= 0.0
io[:tm0][i_div, :value] .=  io[:duty0][i_div,:value] ./ io[:m0][i_div,:value]

# "Import tariff"
io[:ta0] = fill_zero((yr = set[:yr], i = set[:i]))
i_div = io[:a0][:,:value] .!= 0.0
io[:ta0][i_div, :value] .= (io[:tax0][i_div,:value] - io[:sbd0][i_div,:value]) ./ io[:a0][i_div,:value]

# "Labor share of value added"
# io[:va0] = unstack(edit_with(io[:va0], Drop(:units,"all","==")), :va, :value)
# io[:lshr0] = fill_zero((yr = set[:yr], g = set[:g]))
# io[:lshr0][!,:value] .= io[:va0][:,:compen] ./ (io[:va0][:,:compen] + io[:va0][:,:surplus])
# io[:lshr0] = edit_with(io[:lshr0], Replace(:value, NaN, 0.0))
va0 = unstack(edit_with(copy(io[:va0]), Drop(:units,"all","==")), :va, :value)
io[:lshr0] = fill_zero((yr = set[:yr], g = set[:g]))
io[:lshr0][!,:value] .= va0[:,:compen] ./ (va0[:,:compen] + va0[:,:surplus])
io[:lshr0] = edit_with(io[:lshr0], Replace(:value, NaN, 0.0))

# Remove columns that contain only one value.
[io[k] = io[k][:,[length.(unique.(eachcol(df)[1:end-1])) .!= 1; true]] for (k,df) in io]