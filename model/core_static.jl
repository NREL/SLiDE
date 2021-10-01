##################################################
#
# Replication of windc-3.0 core in julia with counterfactual testing
#
##################################################

# update packages in correct order
# - could skip the downgrade of PATHSolver/Complementarity and just do JuMP
# - new complementarity requires changes to way options/solve statement passed

# import Pkg
# Pkg.add(Pkg.PackageSpec(name = "DataFrames", version = v"0.21.8"))
# Pkg.add(Pkg.PackageSpec(name = "PATHSolver", version = v"0.6.2"))
# Pkg.add(Pkg.PackageSpec(name = "JuMP", version = v"0.21.4"))

using SLiDE
using CSV
using JuMP
using Complementarity
using DataFrames

