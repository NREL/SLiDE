using CSV
using DataFrames
using DelimitedFiles
using YAML
using Query

using SLiDE

# ******************************************************************************************
#   READ BLUENOTE OUTPUT RESULTS TO CHECK.
# ******************************************************************************************
BLUE_DIR = joinpath("data", "windc_output", "2c_shares")
bluenote_lst = [x for x in readdir(joinpath(SLIDE_DIR, BLUE_DIR)) if occursin(".csv", x)]
bluenote = Dict(Symbol(k[1:end-4]) => sort(edit_with(
    read_file(joinpath(BLUE_DIR, k)),
        Rename.([:Dim1, :Dim2, :Dim3, :Val], [:yr, :r, :g, :value])))
    for k in bluenote_lst)

# for k in keys(bluenote)
#     println("\n\n",k, "\n")
#     show(first(bluenote[k],3))
# end

# ******************************************************************************************
#   READ SETS AND SLiDE SUPPLY/USE DATA.
# ******************************************************************************************
SET_DIR = joinpath("data", "coresets")
# set_list = convert_type.(Symbol, ["i", "fd", "m", "ts", "va", "yr"])

# Define edits to perform on each input DataFrame.
x = Dict()
x[:pce] = [Map(joinpath("crosswalk","pce.csv"), [:pg], [:g], [:pg], [:g], :left);
    Map(joinpath("..","coresets","yr.csv"), [:yr], [:yr], [:yr], [:yr], :left);
    Map(joinpath("..","coresets","r_state.csv"), [:r], [:r], [:r], [:r], :left);
    Drop.([:yr,:r,:g], missing, "==");
    Order([:yr,:r,:g,:value], [Int, String, String, Float64])
];
x[:utd] = [Map(joinpath("crosswalk","naics.csv"), [:naics_code], [:windc_code], [:n], [:s], :outer);
    # Map(joinpath("..","coresets","yr.csv"), [:yr], [:yr], [:yr], [:yr], :left);
    # Map(joinpath("..","coresets","r_state.csv"), [:r], [:r], [:r], [:r], :left);
    # Drop.([:yr,:r], missing, "==");
    Order([:yr,:r,:s,:t,:value,:n], [Int, String, String, String, Float64, Int])
];
x[:cfs] = [
    Map(joinpath("crosswalk","sctg.csv"), [:sctg_code], [:windc_code], [:sg], [:g], :left);
    Drop(:g, missing, "==")
    Order([:orig_state,:dest_state,:n,:g,:units,:value],[String,String,Int,String,String,Float64])
]

# Read share info.
shr = Dict()
shr[:cfs] = read_file(joinpath("data", "output", "cfs_state.csv"))
shr[:gsp] = read_file(joinpath("data", "output", "gsp_state.csv"))
shr[:pce] = read_file(joinpath("data", "output", "pce.csv"))
shr[:sgf] = read_file(joinpath("data", "output", "sgf.csv"))
shr[:utd] = read_file(joinpath("data", "output", "utd.csv"))

# ******************************************************************************************
# PCE -- done
shr[:pce] = sort(edit_with(shr[:pce], x[:pce]))
shr[:pce][!,:share] .= shr[:pce][:,:value] ./ sum_over(shr[:pce], :r; keepkeys = true)

# ******************************************************************************************
# UTD -- struggling
shr[:utd] = sort(edit_with(shr[:utd], x[:utd]))
shr[:utd] = sum_over(shr[:utd], :n; values_only = false)

# ******************************************************************************************
# CFS
shr[:cfs] = sort(edit_with(shr[:cfs], x[:cfs]))

# Local supply-demand
#   PARAMETER d0(r,g) "Local supply-demand (CFS)";
#   d0_(r,n,sg) = cfs2012_units(r,r,n,sg,"millions of us dollars (USD)");
#   d0(r,g) = sum(map(sg,g), sum(n, d0_(r,n,sg)));
shr[:d0] = shr[:cfs][shr[:cfs][:,:orig_state] .== shr[:cfs][:,:dest_state],:]
shr[:d0] = edit_with(shr[:d0], Rename(:orig_state,:r))[:,[:r,:n,:g,:units,:value]]
shr[:d0] = sum_over(shr[:d0], :n; values_only = false)

# Interstate trade (CFS)
#   PARAMETER mrt0(r,r,g) "Interstate trade (CFS)";
shr[:mrt0] = shr[:cfs][shr[:cfs][:,:orig_state] .!= shr[:cfs][:,:dest_state],:]
shr[:mrt0] = sum_over(shr[:mrt0], :n; values_only = false)

# National exports (CFS)
#   PARAMETER xn0(r,g) "National exports (CFS)";
#   xn0(r,g) = sum(rr, mrt0(r,rr,g));
shr[:x0] = sum_over(shr[:mrt0], :dest_state; values_only = false)
shr[:x0] = edit_with(shr[:x0], Rename(:orig_state, :r))

# National demand (CFS)
#   PARAMETER mn0(r,g) "National demand (CFS)";
#   mn0(r,g) = sum(rr, mrt0(rr,r,g));
shr[:mn0] = sum_over(shr[:mrt0], :orig_state; values_only = false)
shr[:mn0] = edit_with(shr[:mn0], Rename(:dest_state, :r))

# Regional purchase coefficient
#   PARAMETER rpc(*,g) "Regional purchase coefficient";
#   rpc(r,g)$(d0(r,g) + mn0(r,g)) = d0(r,g) / (d0(r,g) + mn0(r,g));
shr[:mn0], shr[:d0] = fill_zero(shr[:mn0], shr[:d0]);
shr[:rpc] = shr[:d0]
shr[:rpc][!,:value] .= shr[:d0][:,:value] ./ (shr[:mn0][:,:value] + shr[:d0][:,:value])

# ii_zero = shr[:mn0] + shr[:d0] .== 0.0

# df = copy(shr[:cfs])

# first(df,3)