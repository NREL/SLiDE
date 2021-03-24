using SLiDE
using DataFrames

include(joinpath(SLIDE_DIR,"dev","ee_module","calibrate","setup.jl"))


# ------------------------------------------------------------------------------------------
function calibrate_fix_set_nest(d, set)
    R = copy(set[:r])
    G = copy(set[:g])
    S = copy(set[:s])
    M = copy(set[:m])
    SNAT = setdiff(S,set[:eneg])

    calib = Model(optimizer_with_attributes(Ipopt.Optimizer, "max_cpu_time" => 60.0))

    # ----- INITIALIZE VARIABLES -----
    @variables(calib, begin
        YS[r in R, s in S, g in G], (start=d[:ys0][r,s,g], lower_bound=lb*d[:ys0][r,s,g])
        ID[r in R, s in G, g in S], (start=d[:id0][r,g,s], lower_bound=lb*d[:id0][r,g,s])
        LD[r in R, s in S],  (start=d[:ld0][r,s], lower_bound=0)
        KD[r in R, s in S],  (start=d[:kd0][r,s], lower_bound=0)
        ARM[r in R, g in G], (start=d[:a0 ][r,g], lower_bound=lb*d[:a0 ][r,g])
        ND[r in R, g in G],  (start=d[:nd0][r,g], lower_bound=lb*d[:nd0][r,g])
        DD[r in R, g in G],  (start=d[:dd0][r,g], lower_bound=lb*d[:dd0][r,g])
        IMP[r in R, g in G], (start=d[:m0 ][r,g], lower_bound=lb*d[:m0 ][r,g])
        SUP[r in R, g in G], (start=d[:s0 ][r,g], lower_bound=lb*d[:s0 ][r,g])
        XD[r in R, g in G],  (start=d[:xd0][r,g], lower_bound=lb*d[:xd0][r,g])
        XN[r in R, g in G],  (start=d[:xn0][r,g], lower_bound=lb*d[:xn0][r,g])
        XPT[r in R, g in G], (start=d[:x0 ][r,g], lower_bound=lb*d[:x0 ][r,g])
        RX[r in R, g in G],  (start=d[:rx0][r,g], lower_bound=lb*d[:rx0][r,g])
        YH[r in R, g in G],  (start=d[:yh0][r,g], lower_bound=0)
        CD[r in R, g in G],  (start=d[:cd0][r,g], lower_bound=0)
        INV[r in R, g in G], (start=d[:i0 ][r,g], lower_bound=lb*d[:i0 ][r,g], upper_bound=ub*d[:i0][r,g])
        GD[r in R, g in G] , (start=d[:g0 ][r,g], lower_bound=lb*d[:g0 ][r,g])
        NM[r in R, g in G, m in M],   (start=d[:nm0][r,g,m], lower_bound=lb*d[:nm0][r,g,m])
        DM[r in R, g in G, m in M],   (start=d[:dm0][r,g,m], lower_bound=lb*d[:dm0][r,g,m])
        MARD[r in R, m in M, g in G], (start=d[:md0][r,m,g], lower_bound=lb*d[:md0][r,m,g])
        BOP[r in R] >= 0, (start=d[:bopdef0][r])
    end)

    for r in set[:r]
        # Fix international electricity imports/exports to zero (subject to SEDS data).
        if d[:x0][r,"ele"]>0;       set_lower_bound(XPT[r,"ele"], lb_seds*d[:x0][r,"ele"])
        elseif d[:x0][r,"ele"]==0;  fix(XPT[r,"ele"], 0, force=true)
        end

        if d[:m0][r,"ele"]>0;       set_lower_bound(IMP[r,"ele"], lb_seds*d[:m0][r,"ele"])
        elseif d[:m0][r,"ele"]==0;  fix(IMP[r,"ele"], 0, force=true)
        end

        # Specify a range over which SEDS data can shift.
        for e in set[:e]        
            set_lower_bound(CD[r,e], lb_seds*d[:cd0][r,e])
            set_upper_bound(CD[r,e], ub_seds*d[:cd0][r,e])

            set_lower_bound(YS[r,e,e], lb_seds*d[:ys0][r,e,e])
            set_upper_bound(YS[r,e,e], ub_seds*d[:ys0][r,e,e])
            
            for s in S   # (g -> e)
                d[:id0][r,e,s]>0 && set_lower_bound(ID[r,e,s], lb_seds*d[:id0][r,e,s])
                d[:id0][r,e,s]>0 && set_upper_bound(ID[r,e,s], ub_seds*d[:id0][r,e,s])
            end

            for g in G   # (s -> e)
                d[:ys0][r,e,g]==0 && fix(YS[r,e,g], 0, force=true)
                d[:id0][r,g,e]==0 && fix(ID[r,g,e], 0, force=true)
            end

            for m in M
                set_lower_bound(MARD[r,m,e], lb_seds*d[:md0][r,m,e])
                set_upper_bound(MARD[r,m,e], ub_seds*d[:md0][r,m,e])
            end
        end

        # Restrict some parameters to zero.
        for g in set[:g]
            d[:rx0][r,g]==0 && fix(RX[r,g], 0, force=true)
            d[:yh0][r,g]==0 && fix(YH[r,g], 0, force=true)

            for m in M
                d[:nm0][r,g,m]==0 && fix(NM[r,g,m], 0, force=true)
                d[:dm0][r,g,m]==0 && fix(DM[r,g,m], 0, force=true)
                d[:md0][r,m,g]==0 && fix(MARD[r,m,g], 0, force=true)
            end
        end
    end

    # Set electricity imports from the national market to Alaska and Hawaii to zero.
    for r in ["ak","hi"]
        fix(ND[r,"ele"], 0, force=true)
        fix(XN[r,"ele"], 0, force=true)
    end

    return calib
end




# ------------------------------------------------------------------------------------------

function calibrate_fix_set_comp(d, set)
    R = copy(set[:r])
    G = copy(set[:g])
    S = copy(set[:s])
    M = copy(set[:m])
    SNAT = setdiff(S,set[:eneg])

    calib = Model(optimizer_with_attributes(Ipopt.Optimizer, "max_cpu_time" => 60.0))

    # ----- INITIALIZE VARIABLES -----
    @variables(calib, begin
        YS[r in R, s in S, g in G], (start=d[:ys0][r,s,g], lower_bound=lb*d[:ys0][r,s,g])
        ID[r in R, s in G, g in S], (start=d[:id0][r,g,s], lower_bound=lb*d[:id0][r,g,s])
        LD[r in R, s in S],  (start=d[:ld0][r,s], lower_bound=0)
        KD[r in R, s in S],  (start=d[:kd0][r,s], lower_bound=0)
        ARM[r in R, g in G], (start=d[:a0 ][r,g], lower_bound=lb*d[:a0 ][r,g])
        ND[r in R, g in G],  (start=d[:nd0][r,g], lower_bound=lb*d[:nd0][r,g])
        DD[r in R, g in G],  (start=d[:dd0][r,g], lower_bound=lb*d[:dd0][r,g])
        IMP[r in R, g in G], (start=d[:m0 ][r,g], lower_bound=lb*d[:m0 ][r,g])
        SUP[r in R, g in G], (start=d[:s0 ][r,g], lower_bound=lb*d[:s0 ][r,g])
        XD[r in R, g in G],  (start=d[:xd0][r,g], lower_bound=lb*d[:xd0][r,g])
        XN[r in R, g in G],  (start=d[:xn0][r,g], lower_bound=lb*d[:xn0][r,g])
        XPT[r in R, g in G], (start=d[:x0 ][r,g], lower_bound=lb*d[:x0 ][r,g])
        RX[r in R, g in G],  (start=d[:rx0][r,g], lower_bound=lb*d[:rx0][r,g])
        YH[r in R, g in G],  (start=d[:yh0][r,g], lower_bound=0)
        CD[r in R, g in G],  (start=d[:cd0][r,g], lower_bound=0)
        INV[r in R, g in G], (start=d[:i0 ][r,g], lower_bound=lb*d[:i0 ][r,g], upper_bound=ub*d[:i0][r,g])
        GD[r in R, g in G] , (start=d[:g0 ][r,g], lower_bound=lb*d[:g0 ][r,g])
        NM[r in R, g in G, m in M],   (start=d[:nm0][r,g,m], lower_bound=lb*d[:nm0][r,g,m])
        DM[r in R, g in G, m in M],   (start=d[:dm0][r,g,m], lower_bound=lb*d[:dm0][r,g,m])
        MARD[r in R, m in M, g in G], (start=d[:md0][r,m,g], lower_bound=lb*d[:md0][r,m,g])
        BOP[r in R] >= 0, (start=d[:bopdef0][r])
    end)

    # Fix international electricity imports/exports to zero (subject to SEDS data).
    [d[:x0][r,"ele"]>0 ? set_lower_bound(XPT[r,"ele"], lb_seds*d[:x0][r,"ele"]) : fix(XPT[r,"ele"],0,force=true) for r in R]
    [d[:m0][r,"ele"]>0 ? set_lower_bound(IMP[r,"ele"], lb_seds*d[:m0][r,"ele"]) : fix(IMP[r,"ele"],0,force=true) for r in R]
    
    [set_lower_bound(CD[r,e], lb_seds*d[:cd0][r,e]) for (r,e) in set[:r,:e]]
    [set_upper_bound(CD[r,e], ub_seds*d[:cd0][r,e]) for (r,e) in set[:r,:e]]

    [set_lower_bound(YS[r,e,e], lb_seds*d[:ys0][r,e,e]) for (r,e) in set[:r,:e]]
    [set_upper_bound(YS[r,e,e], ub_seds*d[:ys0][r,e,e]) for (r,e) in set[:r,:e]]

    [set_lower_bound(ID[r,e,s], lb_seds*d[:id0][r,e,s]) for (r,e,s) in set[:r,:e,:s]]
    [set_upper_bound(ID[r,e,s], ub_seds*d[:id0][r,e,s]) for (r,e,s) in set[:r,:e,:s]]

    [set_lower_bound(MARD[r,m,e], lb_seds*d[:md0][r,m,e]) for (r,m,e) in set[:r,:m,:e]]
    [set_upper_bound(MARD[r,m,e], ub_seds*d[:md0][r,m,e]) for (r,m,e) in set[:r,:m,:e]]

    # Restrict some parameters to zero.
    [fix(YS[r,e,g], 0, force=true) for (r,e,g) in set[:r,:e,:g] if d[:ys0][r,e,g]==0]
    [fix(ID[r,g,e], 0, force=true) for (r,g,e) in set[:r,:g,:e] if d[:id0][r,g,e]==0]

    [fix(RX[r,g], 0, force=true) for (r,g) in set[:r,:g] if d[:rx0][r,g]==0]
    [fix(YH[r,g], 0, force=true) for (r,g) in set[:r,:g] if d[:yh0][r,g]==0]
    [fix(NM[r,g,m], 0, force=true) for (r,g,m) in set[:r,:g,:m] if d[:nm0][r,g,m]==0]
    [fix(DM[r,g,m], 0, force=true) for (r,g,m) in set[:r,:g,:m] if d[:dm0][r,g,m]==0]
    [fix(MARD[r,m,g], 0, force=true) for (r,m,g) in set[:r,:m,:g] if d[:md0][r,m,g]==0]

    # Set electricity imports from the national market to Alaska and Hawaii to zero.
    [fix(ND[r,"ele"], 0, force=true) for r in ["ak","hi"]]
    [fix(XN[r,"ele"], 0, force=true) for r in ["ak","hi"]]

    return calib
end

# function add_y!(model)
#     @variable(model, y, start = 1)
#     return y
# end

# macro sayhello(name)
#     return :( println("Hello, ", $name) )
# end

# @sayhello "leo"


# function math_expr(op, op1, op2)
#     expr = Expr(:call, op, op1, op2)
#     return expr
# end


# make_range(idx) = Symbol("$idx in set[:$idx], ")
# make_range(idx) = Symbol("$idx, ")


# "$(make_range(a)"

# make_array(idx) = 
# :( for idx in idxs )

# macro lst_idx(idxs)
#     :( println() )
# end