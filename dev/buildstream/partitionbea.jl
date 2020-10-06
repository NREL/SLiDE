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
    global io[k] = edit_with(io[k], Drop.([:value, :units], [0., "all"], "=="))
    global io[k] = io[k] |> @filter(_.yr in set[:yr]) |> DataFrame

    # global io[k][!,:value] .= round.(io[k][:,:value]*1E-3, digits=3)
    # global io[k][!,:units] .= UNITS
end

io[:supply], io[:use] = fill_zero(io[:supply], io[:use]; permute_keys = true)

# ******************************************************************************************
#   PARTITION DATA INTO PARAMETERS.
# ******************************************************************************************

# Read from use data.
#!  id0(yr,i(ir_use),j(jc_use)) = use(yr,ir_use,jc_use);
#!  fd0(yr,i(ir_use),fd(jc_use)) = use(yr,ir_use,jc_use);
#!  va0(yr,va(ir_use),j(jc_use)) = use(yr,ir_use,jc_use);
#!  ts0(yr,ts(ir_use),j(jc_use)) = use(yr,ir_use,jc_use);
#!  x0(yr,i(ir_use)) = use(yr,ir_use,"exports");
io[:id0] = io[:use] |> @filter(.&(_.i in set[:i],  _.j in set[:j] ))  |> DataFrame
io[:fd0] = io[:use] |> @filter(.&(_.i in set[:i],  _.j in set[:fd]))  |> DataFrame
io[:va0] = io[:use] |> @filter(.&(_.i in set[:va], _.j in set[:j] ))  |> DataFrame
io[:ts0] = io[:use] |> @filter(.&(_.i in set[:ts], _.j in set[:j] ))  |> DataFrame
io[:x0]  = io[:use] |> @filter(.&(_.i in set[:i],  _.j == "exports")) |> DataFrame

io[:va0] = edit_with(io[:va0], Rename(:i, :va));
io[:fd0] = edit_with(io[:fd0], Rename(:j, :fd));

# Read from supply data.
#!  ys0(yr,j(jc_supply),i(ir_supply)) = supply(yr,ir_supply,jc_supply);
#!  m0(yr,i(ir_supply)) = supply(yr,ir_supply,"imports");
#!  mrg0(yr,i(ir_supply)) = supply(yr,ir_supply,"margins");
#!  trn0(yr,i(ir_supply)) = supply(yr,ir_supply,"trncost");
#!  cif0(yr,i(ir_supply)) = supply(yr,ir_supply,"ciffob");
#!  duty0(yr,i(ir_supply)) = supply(yr,ir_supply,"duties");
#!  tax0(yr,i(ir_supply)) = supply(yr,ir_supply,"tax");
#!  sbd0(yr,i(ir_supply)) = - supply(yr,ir_supply,"subsidies");
io[:ys0]   = io[:supply] |> @filter(.&(_.i in set[:i], _.j in set[:j]))   |> DataFrame
io[:m0]    = io[:supply] |> @filter(.&(_.i in set[:i], _.j == "imports")) |> DataFrame
io[:mrg0]  = io[:supply] |> @filter(.&(_.i in set[:i], _.j == "margins")) |> DataFrame
io[:trn0]  = io[:supply] |> @filter(.&(_.i in set[:i], _.j == "trncost")) |> DataFrame
io[:cif0]  = io[:supply] |> @filter(.&(_.i in set[:i], _.j == "ciffob"))  |> DataFrame
io[:duty0] = io[:supply] |> @filter(.&(_.i in set[:i], _.j == "duties"))  |> DataFrame
io[:tax0]  = io[:supply] |> @filter(.&(_.i in set[:i], _.j == "tax"))     |> DataFrame
io[:sbd0]  = io[:supply] |> @filter(.&(_.i in set[:i], _.j == "subsidies")) |> DataFrame

# Treat negative inputs as outputs.
#!  ys0(yr,j,i) = ys0(yr,j,i) - min(0,id0(yr,i,j));
#!  id0(yr,i,j) = max(0,id0(yr,i,j));
#!  ts0(yr,'subsidies',j) = - ts0(yr,'subsidies',j);
#!  sbd0(yr,i(ir_supply)) = - supply(yr,ir_supply,"subsidies");
io[:ys0][!,:value] = io[:ys0][:,:value] - min.(0, io[:id0][:,:value])
io[:id0][!,:value] = max.(0, io[:id0][:,:value])
io[:ts0][io[:ts0][:,:i] .== "subsidies", :value] *= -1
io[:sbd0][!,:value] *= -1

# Adjust transport margins for transport sectors according to CIF/FOB adjustments.
# Insurance imports are specified as net of adjustments.
#!  trn0(yr,i)$(cif0(yr,i) AND NOT SAMEAS(i,'ins')) = trn0(yr,i) + cif0(yr,i);
#!  m0(yr,i)$(SAMEAS(i,'ins')) = m0(yr,i) + cif0(yr,i);
#!  cif0(yr,i) = 0;
i_ins = io[:cif0][:,:i] .== "ins"
io[:trn0][.!i_ins, :value] .= io[:trn0][.!i_ins,:value] + io[:cif0][.!i_ins,:value]
io[:m0  ][  i_ins, :value] .= io[:m0][i_ins,:value] + io[:cif0][i_ins,:value]
io[:cif0][      !, :value] .= 0.0

# Aggregate supply and gross output
#!  s0(yr,j) = sum(i,ys0(yr,i,j));
#!  y0(yr,i) = sum(j, ys0(yr,j,i));
io[:s0] = sum_over(io[:ys0], :i; values_only = false)   # aggregate supply
io[:y0] = sum_over(io[:ys0], :j; values_only = false)   # gross output

# ******************************************************************************************

# Initialize empty DataFrames where values will be calculated.
io[:a0]  = fill_zero((yr = set[:yr], i = set[:i]))
io[:tm0] = fill_zero((yr = set[:yr], i = set[:i]))
io[:ta0] = fill_zero((yr = set[:yr], i = set[:i]))
io[:ms0] = fill_zero((yr = set[:yr], i = set[:i], m = set[:m]))
io[:md0] = fill_zero((yr = set[:yr], m = set[:m], i = set[:i]))

# Balance of payments deficit
#!  bopdef(yr) = 0;
io[:bopdef] = fill_zero((yr = set[:yr], ))

# Margin supply
#!  ms0(yr,i,"trd") = max(-mrg0(yr,i),0);
#!  ms0(yr,i,'trn') = max(-trn0(yr,i),0);
io[:ms0][io[:ms0][:,:m] .== "trd", :value] .= max.(-io[:mrg0][:,:value], 0)
io[:ms0][io[:ms0][:,:m] .== "trn", :value] .= max.(-io[:trn0][:,:value], 0)

# Margin demand
#!  md0(yr,"trd",i) = max(mrg0(yr,i),0);
#!  md0(yr,'trn',i) = max(trn0(yr,i),0);
io[:md0][io[:md0][:,:m] .== "trd", :value] .= max.(io[:mrg0][:,:value], 0)
io[:md0][io[:md0][:,:m] .== "trn", :value] .= max.(io[:trn0][:,:value], 0)

# Household supply
# Move household supply of recycled goods into the domestic output market
# from which some may be exported. Net out margin supply from output.
#!  fs0(yr,i) = -min(0, fd0(yr,i,'pce'));
#!  y0(yr,i) = sum(j,ys0(yr,j,i)) + fs0(yr,i) - sum(m,ms0(yr,i,m));
io[:fs0] = io[:fd0] |> @filter(_.fd == "pce") |> DataFrame
io[:fs0][!,:value] .= - min.(io[:fs0][:,:value], 0)
io[:y0][!,:value]  .= sum_over(io[:ys0], :j) + io[:fs0][:,:value] - sum_over(io[:ms0], :m)

# Armington supply
#!  a0(yr,i) = sum(fd, fd0(yr,i,fd)) + sum(j, id0(yr,i,j));
io[:a0][!,:value] .= sum_over(io[:fd0], :fd) + sum_over(io[:id0], :j)

# Remove commodity taxes and subsidies on the goods which are produced solely
# for supplying retail sales margin:
#!  y0(yr,imrg) = 0;
#!  a0(yr,imrg) = 0;
#!  tax0(yr,imrg) = 0;
#!  sbd0(yr,imrg) = 0;
#!  x0(yr,imrg) = 0;
#!  m0(yr,imrg) = 0;
#!  md0(yr,m,imrg) = 0;
#!  duty0(yr,imrg) = 0;
# Here's how to do this: https://discourse.julialang.org/t/dataframes-obtaining-the-subset-of-rows-by-a-set-of-values/15923/10
[io[k][findall(in(set[:imrg]), io[k][:,:i]), :value] .= 0.0
    for k in [:y0, :a0, :tax0, :sbd0, :x0, :m0, :md0, :duty0]]

# Tax net subsidy rate on intermediate demand.
#!  tm0(yr,i)$duty0(yr,i) = duty0(yr,i)/m0(yr,i);
i_div = io[:m0][:,:value] .!= 0.0
io[:tm0][i_div, :value] .=  io[:duty0][i_div,:value] ./ io[:m0][i_div,:value]

# Import tariff
#!  ta0(yr,i)$(tax0(yr,i)-sbd0(yr,i)) = (tax0(yr,i) - sbd0(yr,i))/a0(yr,i);
i_div = io[:a0][:,:value] .!= 0.0
io[:ta0][i_div, :value] .= (io[:tax0][i_div,:value] - io[:sbd0][i_div,:value]) ./ io[:a0][i_div,:value]

# include("partitionbea_check.jl")
println("Done.")