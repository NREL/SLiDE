###########
# Is there a way to condense the NL expression? Is there a better way to do this?
# These NL expressions enter complementarity @mapping() conditions for mixed/nonlinear complementarity problem.
#
# I had hoped using get() would work for this but the following throws error:
# @NLexpression(cge,KD4[r in set[:r],s in set[:s]],
#               k0[r,s]*get(RK,(r,s),1.0)
# );
#
###########

using JuMP
using Complementarity

function combvec(set_a...)
    return vec(collect(Iterators.product(set_a...)))
end



set = Dict()
set[:r] = ["CO","CA"]
set[:s] = ["ele","oil"]
set[:ss] = ["ele"]

k0 = Dict((r,s) => 0.5 for r in set[:r],s in set[:ss])

for r in set[:r], s in set[:s]
    get!(k0,(r,s),0.0)
end

sset = Dict()
sset[:RK] = filter(x -> k0[x] != 0.0, combvec(set[:r],set[:s]));

cge = MCPModel();

@variable(cge,RK[(r,s) in sset[:RK]],start=1.0)

# Works with all JuMP versions
@NLexpression(cge,KD1[r in set[:r],s in set[:s]],
              k0[r,s]*1/(isempty([k.I[1] for k in keys(RK) if k.I[1]==(r,s)]) ? 1.0 : RK[(r,s)])
);

# Works with all JuMP versions
@NLexpression(cge,KD2[r in set[:r],s in set[:s]],
              k0[r,s]*1/(isempty([k.I[1] for k in keys(RK) if k.I[1]==(r,s)]) ? 1.0 : getindex(RK,(r,s)))
);

# Throws error with JuMP > v0.21.4
@NLexpression(cge,KD3[r in set[:r],s in set[:s]],
              k0[r,s]*1/(haskey(RK.lookup[1],(r,s)) ? RK[(r,s)] : 1.0)
);

# !!!! I had hoped get() would work, but throws error
@NLexpression(cge,KD4[r in set[:r],s in set[:s]],
              k0[r,s]*1/get(RK,(r,s),1.0)
);

# Throws error
get(RK,("CO","ele"),1.0)

