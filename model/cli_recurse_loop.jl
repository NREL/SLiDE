# Command Line - Recursive Loop update and solve

using SLiDE
using CSV
using JuMP
using Complementarity
using DataFrames

using JLD2, FileIO

# Parse command line arguments and assign
loopyr = convert_type(Int,ARGS[1]) # Loop Year
#loopyr = 2017
prevyr = convert_type(Int,ARGS[2]) # Previous year
#prevyr = 2016
bmkyr = 2016 # Benchmark year (2016)
tint = loopyr - prevyr # Time interval


# include some model functions
include(joinpath(SLIDE_DIR,"model","modelfunc.jl"))

# load/build SLiDE
#SLiDE data needs to be built or point to pre-existing build directory
#can pass a name (d, set) = build_data("name_of_build_directory")
!(@isdefined(d_in) && @isdefined(set_in)) && ((d_in, set_in) = build_data("state_model"))
d = copy(d_in)
set = copy(set_in)

#Load slide data and time horizon to produce model data and appropriate time-indexed subsets
(sld, set, idx) = _model_input(bmkyr, d, set)

# read data from previous solve -- csv files from folder
#@load "data_$prevyr.jld2" rep
@load joinpath(SLIDE_DIR,"model","data_$prevyr.jld2") vrep prep


# update parameters from previous solve for current solve


# include the model from model_recurse_loop.jl
## model_recurse_loop.jl will assign parameters/variables according to updated values
include(joinpath(SLIDE_DIR,"model","model_recurse_loop.jl"))

# solve model

####################
# -- Model Solve --
####################

#set up the options for the path solver
PATHSolver.options(convergence_tolerance=1e-6, output=:yes, time_limit=3600, cumulative_iteration_limit=0)

# solve the model
status = solveMCP(cge)

#exit()

# save output to new directory for loop year
include(joinpath(SLIDE_DIR,"model","cli_loop_rep.jl"))
