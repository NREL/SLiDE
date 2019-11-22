using Complementarity
using CSV
using DataFrames
using JuMP

cge = MCPModel();

smallval = 0.0

@variable(cge,X>=smallval)
@variable(cge,Y>=smallval)
@variable(cge,W>=smallval)
@variable(cge,PX>=smallval)
@variable(cge,PY>=smallval)
@variable(cge,PW>=smallval)
@variable(cge,PL>=smallval)
@variable(cge,PK>=smallval)
@variable(cge,CONS>=smallval)

#parameters for counterfactuals
TX = 0.0
LENDOW = 1.0

#need to be indexed by s
@mapping(cge,PRF_X,100 * PL^0.25 * PK^0.75 * (1+TX) - 100*PX)
@mapping(cge,PRF_Y,100 * PL^0.75* PK^0.25 - 100 * PY)
@mapping(cge,PRF_W,200 * PX^0.5 * PY^0.5 - 200 * PW)

#need to be indexed by m
@mapping(cge,MKT_X, 100 * X - (100 * W * PX^0.5 * PY^0.5) / PX)
@mapping(cge,MKT_Y, 100 * Y - (100 * W * PX^0.5 * PY^0.5) / PY)
@mapping(cge,MKT_W, 200 * W - CONS / PW)
@mapping(cge,MKT_L, 100 * LENDOW - ((25 * X * (PL^0.25) * (PK^0.75)) / PL + (75 * Y * PL^0.75 * PK^0.25) / PL))
@mapping(cge,MKT_K, 100 - (75 * X * PL^0.25 * PK^0.75 / PK + 25 * Y * PL^0.75 * PK^0.25 / PK))

#INCOME Constraint
@mapping(cge,I_CONS, CONS == (100*LENDOW*PL + TX * 100 * X * (PL^0.25) * (PK^0.75) ) )

#@complementarity(d, capcon, pk);

@complementarity(cge,PRF_X,X)
@complementarity(cge,PRF_Y,Y)
@complementarity(cge,PRF_W,W)
@complementarity(cge,MKT_X,PX)
@complementarity(cge,MKT_Y,PY)
@complementarity(cge,MKT_L,PL)
@complementarity(cge,MKT_K,PK)
@complementarity(cge,MKT_W,PW)
@complementarity(cge,I_CONS,CONS)

set_start_value(X,1)
set_start_value(Y,1)
set_start_value(W,1)
set_start_value(PX,1)
set_start_value(PY,1)
set_start_value(PW,1)
set_start_value(PL,1)
set_start_value(PK,1)
set_start_value(CONS,200)

PATHSolver.options(convergence_tolerance=1e-8, output=:yes, time_limit=3600)
status = solveMCP(cge)

#retrieve the values of x
result_value(X)
result_value(Y)
result_value(W)
result_value(P
result_value(PY)
result_value(PW)
result_value(PL)
result_value(PK)
result_value(CONS)




