####################################
#
# Recursive dynamic extension of SLiDE model
#
####################################


using SLiDE
using CSV
using JuMP
using Complementarity
using DataFrames


############
# LOAD DATA
############

#SLiDE data needs to be built or point to pre-existing build directory
#can pass a name: d, set = build(Dataset("name_of_build_directory"))
dataset = Dataset("state_model_eem"; eem=true)
d, set = build(dataset)

#Specify benchmark year - this is the first solve year where the benchmark replicated
bmkyr = 2016

#Load slide data and time horizon to produce model data and appropriate time-indexed subsets
sld, set = SLiDE._model_input(d, set, bmkyr, Dict)

##############
# SETS
##############

# Set description
#set[:s] -> sectors
#set[:g] -> goods
#set[:r] -> regions
#set[:m] -> margins
#set[:gm] -> goods_margins

# reassign sets for concision - !!!! leaning towards original for clarity and namespace
S, G, M, GM, R = set[:s], set[:g], set[:m], set[:gm], set[:r]

# More subsets
set[:fe] = ["col","gas","oil","cru"]    # fossil energy goods
set[:pfe] = ["col","gas","oil"]         # fossil energy pinned fuels
set[:xe] = ["col","gas","cru"]          # extractive resources
set[:ele] = ["ele"]                     # electricity
set[:oil] = ["oil"]                     # refined oil
set[:cru] = ["cru"]                     # crude oil
set[:gas] = ["gas"]                     # natural gas
set[:col] = ["col"]                     # coal
set[:en] = append!(set[:fe], set[:ele]) # energy goods
set[:nfe] = setdiff(set[:g],set[:fe])   # non-fossil energy goods
set[:nxe] = setdiff(set[:g],set[:xe])   # non-extractive goods
set[:nele] = setdiff(set[:g],set[:ele]) # non-electricity goods
set[:nne] = setdiff(set[:g],set[:en])   # non-energy goods


##############
# SWITCHES
##############

swfr = 0
swunemp = 0
swcarb = 0

########## Model ##########
cge = MCPModel();

##############
# PARAMETERS
##############

#benchmark values
@NLparameter(cge, ys0[r in set[:r], s in set[:s], g in set[:g]] == sld[:ys0][r,s,g]); # Sectoral supply
@NLparameter(cge, id0[r in set[:r], s in set[:s], g in set[:g]] == sld[:id0][r,s,g]); # Intermediate demand
@NLparameter(cge, ld0[r in set[:r], s in set[:s]] == sld[:ld0][r,s]); # Labor demand
@NLparameter(cge, kd0[r in set[:r], s in set[:s]] == sld[:kd0][r,s]); # Capital demand
@NLparameter(cge, ty0[r in set[:r], s in set[:s]] == sld[:ty0][r,s]); # Production tax (benchmark)
@NLparameter(cge, m0[r in set[:r], g in set[:g]] == sld[:m0][r,g]); # Imports
@NLparameter(cge, x0[r in set[:r], g in set[:g]] == sld[:x0][r,g]); # Exports of goods and services
@NLparameter(cge, rx0[r in set[:r], g in set[:g]] == sld[:rx0][r,g]); # Re-exports of goods and services
@NLparameter(cge, md0[r in set[:r], m in set[:m], g in set[:g]] == sld[:md0][r,m,g]); # Total margin demand
@NLparameter(cge, nm0[r in set[:r], g in set[:g], m in set[:m]] == sld[:nm0][r,g,m]); # Margin demand from national market
@NLparameter(cge, dm0[r in set[:r], g in set[:g], m in set[:m]] == sld[:dm0][r,g,m]); # Margin supply from local market
@NLparameter(cge, s0[r in set[:r], g in set[:g]] == sld[:s0][r,g]); # Aggregate supply
@NLparameter(cge, a0[r in set[:r], g in set[:g]] == sld[:a0][r,g]); # Armington supply
@NLparameter(cge, ta0[r in set[:r], g in set[:g]] == sld[:ta0][r,g]); # Tax net of subsidy rate on intermediate demand
@NLparameter(cge, tm0[r in set[:r], g in set[:g]] == sld[:tm0][r,g]); # Import tariff
@NLparameter(cge, cd0[r in set[:r], g in set[:g]] == sld[:cd0][r,g]); # Final demand
#@NLparameter(cge, c0[r in set[:r]] == sum(sld[:cd0][r,g] for g in set[:g])); # Aggregate final demand
@NLparameter(cge, c0[r in set[:r]] == sld[:c0][r]); # Aggregate final demand
@NLparameter(cge, yh0[r in set[:r], g in set[:g]] == sld[:yh0][r,g]); #Household production
@NLparameter(cge, bopdef0[r in set[:r]] == sld[:bopdef0][r]); #Balance of payments
@NLparameter(cge, hhadj[r in set[:r]] == sld[:hhadj][r]); # Household adjustment
@NLparameter(cge, g0[r in set[:r], g in set[:g]] == sld[:g0][r,g]); # Government demand
@NLparameter(cge, i0[r in set[:r], g in set[:g]] == sld[:i0][r,g]); # Investment demand
@NLparameter(cge, xn0[r in set[:r], g in set[:g]] == sld[:xn0][r,g]); # Regional supply to national market
@NLparameter(cge, xd0[r in set[:r], g in set[:g]] == sld[:xd0][r,g]); # Regional supply to local market
@NLparameter(cge, dd0[r in set[:r], g in set[:g]] == sld[:dd0][r,g]); # Regional demand to local market
@NLparameter(cge, nd0[r in set[:r], g in set[:g]] == sld[:nd0][r,g]); # Regional demand to national market

#counterfactual taxes
@NLparameter(cge, ty[r in set[:r], s in set[:s]] == sld[:ty0][r,s]); # output tax
@NLparameter(cge, ta[r in set[:r], g in set[:g]] == sld[:ta0][r,g]); # Armington tax
@NLparameter(cge, tm[r in set[:r], g in set[:g]] == sld[:tm0][r,g]); # import tariff

#co2 emissions --- Converted to billion tonnes of co2
#so that model carbon prices interpreted in $/tonnes
@NLparameter(cge, idcb0[r in set[:r], g in set[:g], s in set[:s]] == sld[:secco2][r,g,s,"million metric tons of carbon dioxide"]*1e-3); # industrial/sectoral demand for co2
@NLparameter(cge, cdcb0[r in set[:r], g in set[:g]] == sld[:resco2][r,g,"million metric tons of carbon dioxide"]*1e-3);  # final demand for co2
@NLparameter(cge, cb0[r in set[:r]] == sum((sum(value(idcb0[r,g,s]) for s in set[:s]) + value(cdcb0[r,g])) for g in set[:g]));  # supply of co2
@NLparameter(cge, carb0[r in set[:r]] == value(cb0[r]));  # co2 endowment
@NLparameter(cge, idcco2[r in set[:r], g in set[:g], s in set[:s]] == ensurefinite(value(idcb0[r,g,s])/value(id0[r,g,s])));
@NLparameter(cge, cdcco2[r in set[:r], g in set[:g], s in set[:s]] == ensurefinite(value(cdcb0[r,g])/value(cd0[r,g])));

# natural resources and extraction benchmark updates
# calibration to supply elasticity in later step
# source: EPA SAGE model documentation
@NLparameter(cge, fr_shr0[r in set[:r], s in set[:s]] == 0);
@NLparameter(cge, fr0[r in set[:r],s in set[:s]] == 0);

# if switching resource factor/supply curves on
if swfr == 1
    # set fixed resource shares of capital for disaggregation
    for r in set[:r]
        set_value(fr_shr0[r,"col"], 0.4);
        set_value(fr_shr0[r,"gas"], 0.25);
        set_value(fr_shr0[r,"cru"], 0.25);
    end
    # update fixed resource and adjust capital
    for r in set[:r], s in set[:s]
        set_value(fr0[r,s], value(fr_shr0[r,s])*value(kd0[r,s]));
        set_value(kd0[r,s], value(kd0[r,s])-value(fr0[r,s]));
    end
end

# store values for overwrite if needed
@NLparameter(cge, ymid[r in set[:r], g in set[:g], s in set[:s]] == value(id0[r,g,s]));
@NLparameter(cge, yxid[r in set[:r], g in set[:g], s in set[:s]] == value(id0[r,g,s]));
@NLparameter(cge, cid[r in set[:r], g in set[:g]] == value(cd0[r,g]));

# Capital and investment benchmarks
@NLparameter(cge, dr == 0.05); # capital depreciation rate
@NLparameter(cge, thetax == 0.3); # extant production share

# !!!! Sector-specific for now - issues with more flexibility
@NLparameter(cge, ks_m0[r in set[:r], s in set[:s]] == value(kd0[r,s]) * (1-value(thetax)));    # Mutable total capital endowment - Non-extant capital base year
@NLparameter(cge, ks_m[r in set[:r], s in set[:s]] == value(kd0[r,s]) * (1-value(thetax)));

@NLparameter(cge, ks_x0[r in set[:r], s in set[:s]] == value(kd0[r, s]) * value(thetax));   # Extant capital endowment base year
@NLparameter(cge, ks_x[r in set[:r], s in set[:s]] == value(kd0[r, s]) * value(thetax));

@NLparameter(cge, tks0[r in set[:r], s in set[:s]] == value(ks_x0[r,s]) + value(ks_m0[r,s]));   # total capital stock in base year
@NLparameter(cge, tks[r in set[:r], s in set[:s]] == value(ks_x0[r,s]) + value(ks_m0[r,s]));

@NLparameter(cge, inv0[r in set[:r]] == sum(value(i0[r,g]) for g in set[:g]));  # Benchmark investment supply

# split fixed resource between extant and mutable
@NLparameter(cge, frx0[r in set[:r], s in set[:s]] == value(fr0[r,s])*value(thetax));
@NLparameter(cge, frx[r in set[:r], s in set[:s]] == value(fr0[r,s])*value(thetax));
@NLparameter(cge, frm0[r in set[:r], s in set[:s]] == value(fr0[r,s])*(1-value(thetax)));
@NLparameter(cge, frm[r in set[:r], s in set[:s]] == value(fr0[r,s])*(1-value(thetax)));
@NLparameter(cge, frb0[r in set[:r], s in set[:s]] == value(fr0[r,s]));  # base year resource

# Labor-Leisure benchmarks
@NLparameter(cge, lab_e0[r in set[:r]] == sum(value(ld0[r,s]) for s in set[:s]));   # benchmark year Labor endowment/supply
@NLparameter(cge, lab_e[r in set[:r]] == sum(value(ld0[r,s]) for s in set[:s]));   # duplicate/overwritable Labor endowment/supply
@NLparameter(cge, lte0_shr[r in set[:r]] == 0.4);   # extra time to calibrate time endowment (leisure share of time endowment)
@NLparameter(cge, lte0[r in set[:r]] == value(lab_e0[r])/(1-value(lte0_shr[r])));   # time endowment
@NLparameter(cge, leis_e0[r in set[:r]] == value(lte0[r]) - value(lab_e0[r]));  # benchmark year leisure time endowment/supply
@NLparameter(cge, leis_e[r in set[:r]] == value(lte0[r]) - value(lab_e0[r]));  # duplicate/overwritable leisure time endowment/supply
@NLparameter(cge, z0[r in set[:r]] == value(c0[r]) + value(leis_e0[r]));    # benchmark full consumption
@NLparameter(cge, leis_shr[r in set[:r]] == value(leis_e0[r]) / (value(c0[r]) + value(leis_e0[r])));  # leisure share of full consumption

@NLparameter(cge, es_z[r in set[:r]] == 0); #substitution elasticity between leisure and consumption in prod Z
@NLparameter(cge, theta_l == 0.05); # uncompensated labor supply elasticity

# Unemployment and labor frictions (Balistreri 2002)
# Calibration point established (Hafstead, Williams, Chen 2019)
@NLparameter(cge, u0[r in set[:r]] == 0);    # benchmark unemployment rate

# if unemployment switched on, set unemployment rate (placeholder value)
if swunemp == 1
    for r in set[:r]
        set_value(u0[r], 0.05);
    end
end

@NLparameter(cge, wref[r in set[:r]] == 1/(1-value(u0[r])));    # benchmark reservation wage
@NLparameter(cge, sig == 0.9);  # Exponent on labor supply (LS) externality
@NLparameter(cge, uta == 1-value(sig));  # Exponent on Unemployment (U) externality

# !!!! Benchmark welfare index --- Don't forget to update with new model
#@NLparameter(cge, w0[r in set[:r]] == value(inv0[r])+value(z0[r]));
@NLparameter(cge, w0[r in set[:r]] == value(inv0[r])+value(c0[r]));

# Energy-Nesting Benchmark parameters
@NLparameter(cge, va_bar[r in set[:r], s in set[:s]] == value(ld0[r,s]) + value(kd0[r,s])); # bmk value-added
@NLparameter(cge, fe_bar[r in set[:r], s in set[:s]] == sum(value(id0[r,g,s]) for g in set[:fe])); # bmk fossil-energy FE
@NLparameter(cge, en_bar[r in set[:r], s in set[:s]] == sum(value(id0[r,g,s]) for g in set[:en])); # bmk energy EN
@NLparameter(cge, ne_bar[r in set[:r], s in set[:s]] == sum(value(id0[r,g,s]) for g in set[:nne])); # bmk non-energy NNE
@NLparameter(cge, vaen_bar[r in set[:r], s in set[:s]] == value(va_bar[r,s]) + value(en_bar[r,s])); # bmk value-added-energy vaen
@NLparameter(cge, klem_bar[r in set[:r], s in set[:s]] == value(vaen_bar[r,s]) + value(ne_bar[r,s])); # bmk value-added-energy vaen


# benchmark value share parameters
# capital-labor (value added nest)
@NLparameter(cge, alpha_kl[r in set[:r], s in set[:s]] == ensurefinite(value(ld0[r,s]) / (value(ld0[r,s]) + value(kd0[r,s]))));

# disposition / Export
@NLparameter(cge, cs0[r in set[:r], g in set[:g]] == value(x0[r,g])-value(rx0[r,g]) + value(xd0[r,g]) + value(xn0[r,g])); #sum total of outputs in unit revenue/transformation
@NLparameter(cge, alpha_x[r in set[:r], g in set[:g]] == ensurefinite((value(x0[r,g]) - value(rx0[r,g])) / value(cs0[r,g])));
@NLparameter(cge, alpha_d[r in set[:r], g in set[:g]] == ensurefinite(value(xd0[r,g]) / value(cs0[r,g])));
@NLparameter(cge, alpha_n[r in set[:r], g in set[:g]] == ensurefinite(value(xn0[r,g]) / value(cs0[r,g])));

# absorption / Armington
@NLparameter(cge, theta_n[r in set[:r], g in set[:g]] == ensurefinite(value(nd0[r,g]) / (value(nd0[r,g]) - value(dd0[r,g]))));
@NLparameter(cge, theta_m[r in set[:r], g in set[:g]] == ensurefinite((1+value(tm0[r,g])) * value(m0[r,g]) / (value(nd0[r,g]) + value(dd0[r,g]) + (1 + value(tm0[r,g])) * value(m0[r,g]))));

# Investment
@NLparameter(cge, theta_inv[r in set[:r], g in set[:g]] == value(i0[r,g]) / value(inv0[r])); # Intermediate input share of investment output

# Final Consumption
@NLparameter(cge, theta_cd[r in set[:r], g in set[:g]] == value(cd0[r,g]) / sum(value(cd0[r,g]) for g in set[:g]));

# Energy-nesting
@NLparameter(cge, theta_fe[r in set[:r], g in set[:fe], s in set[:s]] == ensurefinite(value(id0[r,g,s])/value(fe_bar[r,s])));
@NLparameter(cge, theta_en[r in set[:r], g in set[:en], s in set[:s]] == ensurefinite(value(id0[r,g,s])/value(en_bar[r,s])));
@NLparameter(cge, theta_ele[r in set[:r], s in set[:s]] == ensurefinite(sum(value(id0[r,g,s]) for g in set[:ele])/value(fe_bar[r,s])));
@NLparameter(cge, theta_ne[r in set[:r], g in set[:nne], s in set[:s]] == ensurefinite(value(id0[r,g,s])/value(ne_bar[r,s])));
@NLparameter(cge, theta_va[r in set[:r], s in set[:s]] == ensurefinite(value(va_bar[r,s])/value(vaen_bar[r,s])));
@NLparameter(cge, theta_kle[r in set[:r], s in set[:s]] == ensurefinite(value(vaen_bar[r,s])/value(klem_bar[r,s])));

# fixed factor (top-level)
@NLparameter(cge, theta_fr[r in set[:r], s in set[:s]] == 0);

# !!!! could remove if-statement and just declare - would default to zero due to fr0=0 above
if swfr == 1
    for r in set[:r], s in set[:s]
        set_value(theta_fr[r,s], ensurefinite(value(fr0[r,s])/(value(klem_bar[r,s])+value(fr0[r,s]))));
    end
end



#Substitution and transformation elasticities
@NLparameter(cge, es_va[r in set[:r], s in set[:s]] == SUB_ELAST[:va]); # value-added nest - substitution elasticity
@NLparameter(cge, es_y[r in set[:r], s in set[:s]]  == SUB_ELAST[:y]); # Top-level Y nest (VA,M) - substitution elasticity
@NLparameter(cge, es_m[r in set[:r], s in set[:s]]  == SUB_ELAST[:m]); # Materials nest - substitution elasticity
@NLparameter(cge, et_x[r in set[:r], g in set[:g]]    == TRANS_ELAST[:x]); # Disposition, distribute regional supply to local, national, export - transformation elasticity
@NLparameter(cge, es_a[r in set[:r], g in set[:g]]    == SUB_ELAST[:a]); # Top-level A nest for aggregate demand (set[:m], set[:g]) - substitution elasticity
@NLparameter(cge, es_mar[r in set[:r], g in set[:g]]  == SUB_ELAST[:mar]); # Margin supply - substitution elasticity
@NLparameter(cge, es_d[r in set[:r], g in set[:g]]    == SUB_ELAST[:d]); # Domestic demand aggregation nest (intranational) - substitution elasticity
@NLparameter(cge, es_f[r in set[:r], g in set[:g]]    == SUB_ELAST[:f]); # Domestic and foreign demand aggregation nest (international) - substitution elasticity

@NLparameter(cge, es_inv[r in set[:r]] == 5); # Investment production - substitution elasticity

@NLparameter(cge, es_cd[r in set[:r]] == 0.99); # Final consumption - substitution elasticity

#Energy nesting substitution elasticities
@NLparameter(cge, es_fe[s in set[:s]] == 0); #FE nest
@NLparameter(cge, es_ele[s in set[:s]] == 0); # EN nest
@NLparameter(cge, es_ve[s in set[:s]] == 0); # VAEN/KLE nest
@NLparameter(cge, es_ne[s in set[:s]] == 0); # NE nest
@NLparameter(cge, es_klem[s in set[:s]] == 0); # KLEM nest

# Calibrate resource supply elasticities (Rutherford 2002)
@NLparameter(cge, esup_xe[s in set[:s]] == 0);  # resource supply elasticities
@NLparameter(cge, es_fr[r in set[:r], s in set[:s]] == 0); # substitution elasticity top nest

# Calibration point informed by EPA SAGE Model Documentation
set_value(esup_xe["col"], 2.4);
set_value(esup_xe["gas"], 0.5);
set_value(esup_xe["cru"], 0.15);

# calculate implied substitution elasticitiy from share and supply elasticity (Rutherford 2002)
for r in set[:r], s in set[:xe]
    set_value(es_fr[r,s], value(esup_xe[s]) * value(theta_fr[r,s]) / (1-value(theta_fr[r,s])));
end

# Autonomous energy efficiency improvement (aeei) - used to pin energy demands
# initialized to 1
@NLparameter(cge, idaeei[r in set[:r], g in set[:g], s in set[:s]] == 1);   # aeei for good g in sector s
@NLparameter(cge, cdaeei[r in set[:r], g in set[:g]] == 1); # aeei for final demand


################
# VARIABLES
################

# specify lower bound
lo = 0.0
low = 0.0

# sectors
@variables(cge, begin
    YX[(r,s) in set[:Y]] >= lo, (start = value(thetax)) # Extant output
    YM[(r,s) in set[:Y]] >= lo, (start = (1-value(thetax))) # Mutable output
    # YYM[(r,s) in set[:Y]] >= lo, (start = (1-value(thetax))) # pre-fixed resource Mutable output
    # E[(r,s) in set[:Y]] >= lo, (start = (1-value(thetax))) # Energy index
    # VA[(r,s) in set[:Y]] >= lo, (start = (1-value(thetax))) # Value-added index
    X[(r,g) in set[:X]] >= lo, (start = 1)  # Disposition / Exports
    A[(r,g) in set[:A]] >= lo, (start = 1)  # Absorption / Armington
    MS[r in set[:r], m in set[:m]] >= lo, (start = 1)   # Margin supply
    # LS[r in set[:r]] >= lo, (start = (1-value(u0[r]))) # Labor supply
    C[r in set[:r]] >= lo, (start = 1) # Final Consumption
    INV[r in set[:r]] >= lo, (start = 1) # Investment
    # Z[r in set[:r]] >= lo, (start = 1) # Full consumption
    W[r in set[:r]] >= lo, (start = 1) # Welfare index
    # CO2[r in set[:r]] >= lo, (start = value(cb0[r])) # CO2 emissions supply
end);

# commodities
@variables(cge, begin
    PA[(r,g) in set[:PA]] >= lo, (start = 1) # Regional market (input) price
    PY[(r,g) in set[:PY]] >= lo, (start = 1) # Regional market (output) price
    PD[(r,g) in set[:PD]] >= lo, (start = 1) # Local market price
    PN[g in set[:g]] >= lo, (start = 1) # National market price
    # PYM[(r,s) in set[:Y]] >= lo, (start = 1) # pre-fixed resource mutable composite price
    # PE[(r,s) in set[:Y]] >= lo, (start = 1) # Energy composite price
    # PVA[(r,s) in set[:Y]] >= lo, (start = 1) # Value-added composite price
    RK[(r,s) in set[:PK]] >= lo, (start = 1) # Capital rental - mutable
    RKX[(r,s) in set[:PK]] >= lo, (start = 1) # Capital rental - extant
    # PFR[(r,s) in set[:PK]] >= low, (start = 1) # Fixed resource - mutable
    # PFRX[(r,s) in set[:PK]] >= low, (start = 1) # Fixed resource - extant
    PM[r in set[:r], m in set[:m]] >= lo, (start = 1) # Margin price
    PFX >= lo, (start = 1) # Foreign exchange price
    # PLS[r in set[:r]] >= low, (start = value(wref[r])) # Labor supply price
    PL[r in set[:r]] >= lo, (start = 1) # Leisure / Time price
    PC[r in set[:r]] >= lo, (start = 1) # Final consumption price
    PINV[r in set[:r]] >= lo, (start = 1) # Investment price
    # PZ[r in set[:r]] >= lo, (start = 1) # Full consumption price
    PW[r in set[:r]] >= lo, (start = 1) # Welfare price
    # PCO2 >= lo, (start = 1) # CO2 factor price
    # PDCO2[r in set[:r]] >= lo, (start = 1) # Effective CO2 price
end);

# Demand
#@variable(cge, RA[r in set[:r]] >= lo, start = (value(z0[r])+value(inv0[r])));
@variable(cge, RA[r in set[:r]]>=lo,start = value(w0[r])) ;

# Definitionals
# !!!! new subsets and start values needed (placeholders for now)
@variables(cge, begin
    RX[(r,g) in set[:X]] >= lo, (start = 1) # Unit revenue function disposition
    DKM[(r,s) in set[:PK]] >= lo, (start = start_value(YM[(r,s)])*value(kd0[r,s])) # Mutable capital demand
# !!!! remaining variables unused -- for some reason unused variables will throw bounds error if declared prior to used variable
    U[r in set[:r]] >= lo, (start = 1) # Unemployment rate index
    DKX[(r,s) in set[:PK]] >= lo, (start = start_value(YX[(r,s)])*value(kd0[r,s])) # Extant capital demand
    DCD[r in set[:r], g in set[:g]] >= lo, (start = start_value(C[r])*value(cd0[r,g])) # Final consumption demand
    DIDM[r in set[:r], g in set[:g], s in set[:s]] >= lo, (start = 1) # Intermediate demand - mutable
    DIDX[r in set[:r], g in set[:g], s in set[:s]] >= lo, (start = 1) # Intermediate demand - extant
    DND[r in set[:r], g in set[:g]] >= lo, (start = 1) # Import demand from national market
    DMF[r in set[:r], g in set[:g]] >= lo, (start = 1) # Import demand from foreign market
    DLS[r in set[:r]] >= lo, (start = 1) # Leisure demand
    DLDM[r in set[:r], s in set[:s]] >= lo, (start = 1) # Labor demand - mutable
    DLDX[r in set[:r], s in set[:s]] >= lo, (start = 1) # Labor demand - extant
    SX[(r,g) in set[:X]] >= lo, (start = 1) # Commodity supply
    SXN[r in set[:r], g in set[:g]] >= lo, (start = 1) # Exports supplied to national (domestic) market
    SXF[r in set[:r], g in set[:g]] >= lo, (start = 1) # Exports supplied to foreign (international) market
    SLS[r in set[:r]] >= lo, (start = 1) # Labor supply
    SCO2[r in set[:r]] >= lo, (start = 1) # CO2 emissions supply
end);

@variables(cge, begin
    PCO2 >= lo, (start = 1) # CO2 factor price
    PDCO2[r in set[:r]] >= lo, (start = 1) # Effective CO2 price
    PZ[r in set[:r]] >= lo, (start = 1) # Full consumption price
    PLS[r in set[:r]] >= low, (start = value(wref[r])) # Labor supply price
    PFR[(r,s) in set[:PK]] >= low, (start = 1) # Fixed resource - mutable
    PFRX[(r,s) in set[:PK]] >= low, (start = 1) # Fixed resource - extant
    PYM[(r,s) in set[:Y]] >= lo, (start = 1) # pre-fixed resource mutable composite price
    PE[(r,s) in set[:Y]] >= lo, (start = 1) # Energy composite price
    PVA[(r,s) in set[:Y]] >= lo, (start = 1) # Value-added composite price
    CO2[r in set[:r]] >= lo, (start = value(cb0[r])) # CO2 emissions supply
    Z[r in set[:r]] >= lo, (start = 1) # Full consumption
    YYM[(r,s) in set[:Y]] >= lo, (start = (1-value(thetax))) # pre-fixed resource Mutable output
    E[(r,s) in set[:Y]] >= lo, (start = (1-value(thetax))) # Energy index
    VA[(r,s) in set[:Y]] >= lo, (start = (1-value(thetax))) # Value-added index
end);


###############################
# -- PLACEHOLDER VARIABLES --
###############################

#---------- Value-added
#Cobb-douglas for mutable/new
@NLexpression(cge, CVA[r in set[:r], s in set[:s]],
    PL[r]^alpha_kl[r,s] * (haskey(RK.lookup[1], (r,s)) ? RK[(r,s)] : 1.0)^(1-alpha_kl[r,s])
);

# #CES for mutable/new
# @NLexpression(cge, CVA[r in set[:r], s in set[:s]],
#     (alpha_kl[r,s]*PL[r]^(1-es_va[r,s]) + (1-alpha_kl[r,s])*(haskey(RK.lookup[1], (r,s)) ? RK[(r,s)] : 1.0)^(1-es_va[r,s]))^(1/(1-es_va[r,s]));

#demand for labor in VA
@NLexpression(cge,AL[r in set[:r], s in set[:s]],
    ld0[r,s] * (CVA[r,s] / PL[r])^es_va[r,s]
);

#demand for capital in VA
@NLexpression(cge,AK[r in set[:r],s in set[:s]],
    kd0[r,s] * (CVA[r,s] / (haskey(RK.lookup[1], (r,s)) ? RK[(r,s)] : 1.0))^es_va[r,s]
);

# # !!!! test this
# #Cobb-douglas for mutable/new
# @NLexpression(cge, CVAcd[r in set[:r], s in set[:s]],
#     PL[r]^alpha_kl[r,s] * (haskey(RK.lookup[1], (r,s)) ? RK[(r,s)] : 1.0)^(1-alpha_kl[r,s]));

# #CES for mutable/new
# @NLexpression(cge, CVAces[r in set[:r], s in set[:s]],
#     (alpha_kl[r,s]*PL[r]^(1-es_va[r,s]) + (1-alpha_kl[r,s])*(haskey(RK.lookup[1], (r,s)) ? RK[(r,s)] : 1.0)^(1-es_va[r,s]))^(1/(1-es_va[r,s]));

# @NLexpression(cge,AL[r in set[:r], s in set[:s]],
#     ld0[r,s] * ((es_va[r,s]==1) ? CVAcd[r,s] : CVAces[r,s]) / PL[r])^es_va[r,s]);

# #CES demand for capital in VA
# @NLexpression(cge,AK[r in set[:r],s in set[:s]],
#     kd0[r,s] * ((es_va[r,s]==1) ? CVAcd[r,s] : CVAces[r,s]) / (haskey(RK.lookup[1], (r,s)) ? RK[(r,s)] : 1.0))^es_va[r,s]);


# ---------- Disposition / Export
#CES function for output demand - including
# exports (absent of re-exports) times the price for foreign exchange,
# region's supply to national market times the national market price
# regional supply to local market times domestic price
# @NLexpression(cge,RX[r in set[:r],g in set[:g]],
#   (alpha_x[r,g]*PFX^5+alpha_n[r,g]*PN[g]^5+alpha_d[r,g]*(haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0)^5)^(1/5) );

#demand for exports via demand function
@NLexpression(cge,AX[r in set[:r],g in set[:g]],
    (x0[r,g] - rx0[r,g])*(PFX/(haskey(RX.lookup[1], (r,g)) ? RX[(r,g)] : 1.0))^et_x[r,g]
);

#demand for contribution to national market
@NLexpression(cge,AN[r in set[:r],g in set[:g]],
    xn0[r,g]*(PN[g]/(haskey(RX.lookup[1], (r,g)) ? RX[(r,g)] : 1.0))^et_x[r,g]
);

#demand for regionals supply to local market
@NLexpression(cge,AD[r in set[:r],g in set[:g]],
    xd0[r,g] * ((haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0) / (haskey(RX.lookup[1], (r,g)) ? RX[(r,g)] : 1.0))^et_x[r,g]
);

  ###

# ---------- Absorption / Armington / Import
# CES function for tradeoff between national and domestic market
@NLexpression(cge,CDN[r in set[:r],g in set[:g]],
    (theta_n[r,g]*PN[g]^(1-es_d[r,g])+(1-theta_n[r,g])*(haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0)^(1-es_d[r,g]))^(1/(1-es_d[r,g]))
);

# CES function for tradeoff between domestic consumption and foreign exports
# recall tm in the import tariff thus tm / tm0 is the relative change in import tariff rates
@NLexpression(cge,CDM[r in set[:r],g in set[:g]],
    ((1-theta_m[r,g])*CDN[r,g]^(1-es_f[r,g])+theta_m[r,g]*(PFX*(1+tm[r,g])/(1+tm0[r,g]))^(1-es_f[r,g]))^(1/(1-es_f[r,g]))
);

# set[:r] demand from the national market <- note nesting of CDN in CDM
@NLexpression(cge,DN[r in set[:r],g in set[:g]],
    nd0[r,g]*(CDN[r,g]/PN[g])^es_d[r,g]*(CDM[r,g]/CDN[r,g])^es_f[r,g]
);

# region demand from local market <- note nesting of CDN in CDM
@NLexpression(cge,DD[r in set[:r],g in set[:g]],
    dd0[r,g]*(CDN[r,g]/(haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0))^es_d[r,g]*(CDM[r,g]/CDN[r,g])^es_f[r,g]
);

# Foreign import demand
@NLexpression(cge,MD[r in set[:r],g in set[:g]],
    m0[r,g]*(CDM[r,g]/(PFX*(1+tm[r,g])/(1+tm0[r,g])))^es_f[r,g]
);

#---------- Final Consumption
# Unit cost function for final consumption
@NLexpression(cge,CC[r in set[:r]],
    sum(theta_cd[r,g]*(haskey(PA.lookup[1], (r, g)) ? PA[(r,g)] : 1.0)^(1-es_cd[r]) for g in set[:g])^(1/(1-es_cd[r]))
);

# final demand for goods in consumption
@NLexpression(cge,CD[r in set[:r],g in set[:g]],
    cd0[r,g]*CC[r] / (haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0)^es_cd[r]
);

# #alternate
# @NLexpression(cge,CD[r in set[:r],g in set[:g]],
#   cd0[r,g]*PC[r] / (haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0)
# );

#---------- Investment
# demand for goods in investment
@NLexpression(cge,DINV[r in set[:r], g in set[:g]],
    (i0[r,g] * (PINV[r]/(haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0)^es_inv[r]))
);

#---------- Full consumption and leisure
# unit cost for full consumption
@NLexpression(cge,CZ[r in set[:r]],
    (leis_shr[r]*PL[r]^(1-es_z[r]) + (1-leis_shr[r])*PC[r]^(1-es_z[r]))^(1/(1-es_z[r]))
);

# Leisure demand
@NLexpression(cge,DLEIS[r in set[:r]],
    leis_e0[r] * (CZ[r] / PC[r])^(es_z[r])
);

# Consumption demand
@NLexpression(cge,DCONS[r in set[:r]],
    c0[r] * (CZ[r] / PC[r])^(es_z[r])
);


###############################
# -- Zero Profit Conditions --
###############################

#----------
#Recursive  --- update to Y
@mapping(cge,profit_ym[(r, s) in set[:Y]],
# cost of intermediate demand
    sum((haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * id0[r,g,s] for g in set[:g])
# cost of labor inputs
    + PL[r] * AL[r,s]
# cost of capital inputs
    + (haskey(RK.lookup[1], (r,s)) ? RK[(r,s)] : 1.0) * AK[r,s]
    -
# revenue from sectoral supply (take note of r/s/g indices on ys0)
    sum((haskey(PY.lookup[1], (r, g)) ? PY[(r, g)] : 1.0)  * ys0[r,s,g] for g in set[:g]) * (1-ty[r,s])
);

@mapping(cge,profit_yx[(r, s) in set[:Y]],
# cost of intermediate demand
    sum((haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * id0[r,g,s] for g in set[:g])
# cost of labor inputs
    + PL[r] * ld0[r,s]
# cost of capital inputs
    + (haskey(RKX.lookup[1], (r, s)) ? RKX[(r,s)] : 1.0) * kd0[r,s]
    -
# revenue from sectoral supply (take note of r/s/g indices on ys0)
    sum((haskey(PY.lookup[1], (r, g)) ? PY[(r, g)] : 1.0)  * ys0[r,s,g] for g in set[:g]) * (1-ty[r,s])
);

#----------

@mapping(cge,profit_x[(r, g) in set[:X]],
# output 'cost' from aggregate supply
    (haskey(PY.lookup[1], (r, g)) ? PY[(r, g)] : 1.0) * s0[r,g]
    - (
# revenues from foreign exchange
        PFX * AX[r,g]
# revenues from national market
        + PN[g] * AN[r,g]
# revenues from domestic market
        + (haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0) * AD[r,g]
    )
);


@mapping(cge,profit_a[(r, g) in set[:A]],
# costs from national market
    PN[g] * DN[r,g]
# costs from domestic market
    + (haskey(PD.lookup[1], (r, g)) ? PD[(r, g)] : 1.0) * DD[r,g]
# costs from imports, including import tariff
    + PFX * (1+tm[r,g]) * MD[r,g]
# costs of margin demand
    + sum(PM[r,m] * md0[r,m,g] for m in set[:m])
    - (
# revenues from regional market based on armington supply
       (haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * (1-ta[r,g]) * a0[r,g]
# revenues from re-exports
        + PFX * rx0[r,g]
    )
);

@mapping(cge, profit_c[r in set[:r]],
# costs of inputs - computed as final demand times regional market prices
    sum((haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * CD[r,g] for g in set[:g])
    -
# revenues/benefit computed as CPI * reference consumption
    PC[r] * c0[r]
);

@mapping(cge, profit_inv[r in set[:r]],
# inputs to investment
    sum((haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * DINV[r,g] for g in set[:g])
    -
# Investment
    PINV[r] * inv0[r]
);

@mapping(cge, profit_w[r in set[:r]],
# inputs to welfare index
    PINV[r]*inv0[r] + PC[r]*c0[r]
    -
# Welfare
    PW[r]*w0[r]
);

@mapping(cge,profit_ms[r in set[:r], m in set[:m]],
# provision of set[:m] to national market
    sum(PN[gm]   * nm0[r,gm,m] for gm in set[:gm])
# provision of set[:m] to domestic market
    + sum((haskey(PD.lookup[1], (r, gm)) ? PD[(r, gm)] : 1.0) * dm0[r,gm,m] for gm in set[:gm])
    -
# total margin demand
    PM[r,m] * sum(md0[r,m,gm] for gm in set[:gm])
);


###################################
# -- Market Clearing Conditions --
###################################

#----------
#Recursive dynamics mkt clearance

@mapping(cge,market_rk[(r, s) in set[:PK]],
# mutable capital supply
    ks_m[r,s]
    -
# mutable capital demand
    (haskey(YM.lookup[1], (r, s)) ? YM[(r, s)] : 1.0) * AK[r,s]
);

@mapping(cge,market_rkx[(r, s) in set[:PK]],
# extant capital supply
    (ks_x[r,s])
    -
# extant capital demand
    (haskey(YX.lookup[1], (r, s)) ? YX[(r, s)] : 1.) * kd0[r,s]
);

@mapping(cge,market_pa[(r, g) in set[:PA]],
# absorption or supply
    (haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.) * a0[r,g]
    - (
# government demand (exogenous)
        g0[r,g]
# demand for investment
        + INV[r]*DINV[r,g]
# final demand
        + C[r] * CD[r,g]
# intermediate demand
        + sum((haskey(YM.lookup[1], (r, s)) ? YM[(r, s)] : 1) * id0[r,g,s] for s in set[:s] if (r,s) in set[:Y])
        + sum((haskey(YX.lookup[1], (r, s)) ? YX[(r, s)] : 1) * id0[r,g,s] for s in set[:s] if (r,s) in set[:Y])
    )
);

@mapping(cge,market_py[(r, g) in set[:PY]],
# sectoral supply
    sum((haskey(YM.lookup[1], (r, s)) ? YM[(r, s)] : 0.0) *ys0[r,s,g] for s in set[:s])
    + sum((haskey(YX.lookup[1], (r, s)) ? YX[(r, s)] : 0.0) *ys0[r,s,g] for s in set[:s])
# household production (exogenous)
    + yh0[r,g]
    -
# aggregate supply (akin to market demand)
    (haskey(X.lookup[1], (r, g)) ? X[(r, g)] : 1) * s0[r,g]
);

@mapping(cge,market_pl[r in set[:r]],
# supply of labor
    lab_e0[r]
    -
# demand for labor in all set[:s]
    (
        sum((haskey(YM.lookup[1], (r, s)) ? YM[(r, s)] : 1) * AL[r,s] for s in set[:s])
        + sum((haskey(YX.lookup[1], (r, s)) ? YX[(r, s)] : 1) * ld0[r,s] for s in set[:s])
    )
);
#----------


@mapping(cge,market_pd[(r, g) in set[:PD]],
# aggregate supply
    (haskey(X.lookup[1], (r, g)) ? X[(r, g)] : 1)  * AD[r,g]
    - (
# demand for local market
        (haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.) * DD[r,g]
# margin formulation from local market
        + sum(MS[r,m] * dm0[r,g,m] for m in set[:m] if (g in set[:gm] ) )
    )
);

@mapping(cge,market_pn[g in set[:g]],
# supply to the national market
    sum((haskey(X.lookup[1], (r, g)) ? X[(r, g)] : 1)  * AN[r,g] for r in set[:r])
    - (
# demand from the national market
        sum((haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.) * DN[r,g] for r in set[:r])
# margin formulation from the national market
        + sum(MS[r,m] * nm0[r,g,m] for r in set[:r] for m in set[:m] if (g in set[:gm]) )
    )
);


@mapping(cge,market_pm[r in set[:r], m in set[:m]],
# margin supply
    MS[r,m] * sum(md0[r,m,gm] for gm in set[:gm])
    -
# margin demand
    sum((haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.0) * md0[r,m,g] for g in set[:g])
);

@mapping(cge,market_pc[r in set[:r]],
# Consumption supply
    C[r] * c0[r]
    -
# Consumption demand
    W[r] * c0[r]
);

@mapping(cge, market_pinv[r in set[:r]],
# investment supply
    INV[r]*inv0[r]
    -
# investment demanded
    W[r]*inv0[r]
);

@mapping(cge, market_pw[r in set[:r]],
# welfare supply
    W[r]*w0[r]
    -
# full consumption welfare / utility
    RA[r] / PW[r]
);

@mapping(cge,market_pfx,
# balance of payments (exogenous)
    sum((bopdef0[r] + hhadj[r]) for r in set[:r])
# supply of exports
    + sum((haskey(X.lookup[1], (r, g)) ? X[(r, g)] : 1.0)  * AX[r,g] for r in set[:r] for g in set[:g])
# supply of re-exports
    + sum((haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.0) * rx0[r,g] for r in set[:r] for g in set[:g] if (r,g) in set[:A])
    -
# import demand
    sum((haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.0) * MD[r,g] for r in set[:r] for g in set[:g] if (r,g) in set[:A])
);


#----------
#Income balance update for recursive dynamics
@mapping(cge,income_ra[r in set[:r]],
# consumption/utility
    RA[r]
    -
    (
# labor income
        PL[r] * lab_e0[r]
# capital income
        + sum((haskey(RK.lookup[1], (r,s)) ? RK[(r,s)] : 1.0) * ks_m[r,s] for s in set[:s])
        + sum((haskey(RKX.lookup[1], (r, s)) ? RKX[(r,s)] : 1.0) * ks_x[r,s] for s in set[:s])
# provision of household supply
        + sum( (haskey(PY.lookup[1], (r, g)) ? PY[(r, g)] : 1.0) * yh0[r,g] for g in set[:g])
# revenue or costs of foreign exchange including household adjustment
        + PFX * (bopdef0[r] + hhadj[r])
# government provision
        - sum((haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0) * (g0[r,g]) for g in set[:g])
# import taxes - assumes lumpsum recycling
        + sum((haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.) * MD[r,g] * PFX * tm[r,g] for g in set[:g] if (r,g) in set[:A])
# taxes on intermediate demand - assumes lumpsum recycling
        + sum((haskey(A.lookup[1], (r, g)) ? A[(r, g)] : 1.) * a0[r,g]*(haskey(PA.lookup[1], (r, g)) ? PA[(r, g)] : 1.0)*ta[r,g] for g in set[:g] if (r,g) in set[:A])
# production taxes - assumes lumpsum recycling
        + sum( (haskey(YM.lookup[1], (r, s)) ? YM[(r, s)] : 1) * ys0[r,s,g] * ty[r,s] for s in set[:s], g in set[:g])
        + sum( (haskey(YX.lookup[1], (r, s)) ? YX[(r, s)] : 1) * ys0[r,s,g] * ty[r,s] for s in set[:s], g in set[:g])
    )
);

#----------
# Definitional/Reporting
@mapping(cge, DKMdef[(r,s) in set[:PK]],
    DKM[(r,s)]
    -
    YM[(r,s)]*AK[r,s]
);

@mapping(cge,def_RX[(r,g) in set[:X]],
    (haskey(RX.lookup[1], (r,g)) ? RX[(r,g)] : 1.0)
    -
    (alpha_x[r,g]*PFX^(1 + et_x[r,g])+alpha_n[r,g]*PN[g]^(1 + et_x[r,g])+alpha_d[r,g]*(haskey(PD.lookup[1], (r,g)) ? PD[(r,g)] : 1.0)^(1 + et_x[r,g]))^(1/(1 + et_x[r,g]))
    # -
    # (haskey(RX.lookup[1], (r,g)) ? RX[(r,g)] : 1.0)
);

# @mapping(cge,deflo_RX[(r,g) in set[:X]],
#     # (haskey(RX.lookup[1], (r,g)) ? RX[(r,g)] : 1.0)
#     # -
#     (alpha_x[r,g]*PFX^(1 + et_x[r,g])+alpha_n[r,g]*PN[g]^(1 + et_x[r,g])+alpha_d[r,g]*(haskey(PD.lookup[1], (r,g)) ? PD[(r,g)] : 1.0)^(1 + et_x[r,g]))^(1/(1 + et_x[r,g]))
#     -
#     (haskey(RX.lookup[1], (r,g)) ? RX[(r,g)] : 1.0)
# );


####################################
# -- Complementarity Conditions --
####################################

# define complementarity conditions
# note the pattern of ZPC -> primal variable  &  MCC -> dual variable (price)
#@complementarity(cge,profit_y,Y);
@complementarity(cge,profit_ym,YM);
@complementarity(cge,profit_yx,YX);
@complementarity(cge,profit_x,X);
@complementarity(cge,profit_a,A);
@complementarity(cge,profit_c,C);
@complementarity(cge,profit_ms,MS);
@complementarity(cge,market_pa,PA);
@complementarity(cge,market_py,PY);
@complementarity(cge,market_pd,PD);
@complementarity(cge,market_pn,PN);
@complementarity(cge,market_pl,PL);
#@complementarity(cge,market_pk,PK);
@complementarity(cge,market_rk,RK);
@complementarity(cge,market_rkx,RKX);
@complementarity(cge,market_pm,PM);
@complementarity(cge,market_pc,PC);
@complementarity(cge,market_pfx,PFX);
@complementarity(cge,income_ra,RA);

#----------
#Recursive Dynamics
@complementarity(cge,profit_inv,INV);
@complementarity(cge,profit_w,W);
@complementarity(cge,market_pinv,PINV);
@complementarity(cge,market_pw,PW);

#Reporting
@complementarity(cge,DKMdef,DKM);
@complementarity(cge,def_RX,RX);

####################
# -- Model Solve --
####################

#set up the options for the path solver
PATHSolver.options(convergence_tolerance=1e-6, output=:yes, time_limit=3600, cumulative_iteration_limit=0)

# solve the model
status = solveMCP(cge)

#= !!!! SECTOR SPECIFIC CAPITAL UPDATES NEEDED
# Pre-loop calculations
ktot_mx = Dict((r,bmkyr) => value(ks_m[r]) + sum(value(ks_x[r,s]) for s in set[:s])
    for r in set[:r])

srv = 1-value(dr)

# Begin loop
# !!!! consider defining empty dictionaries outside of the loop to store values for postproc
# Been tested from 2017 to 2050 in 1 year increments
for t in 2017:2020
    @info("Begin loop prior to $t Solve.")

    # !!!! Should growth rate be in here? Benchmark cannot replicate if not here.
    # new mutable capital
    newkm = Dict((r,t) => (ktot_mx[r,bmkyr]*(1+value(gr)) - ktot_mx[r,bmkyr]*srv) * result_value(INV[r])
        for r in set[:r]);

    # mutable capital demand from previous solve
    dkml = Dict((r,s) => (haskey(DKM.lookup[1], (r,s)) ? result_value(DKM[(r,s)]) : 0.0)
        for r in set[:r], s in set[:s]);

    # Total mutable/putty capital
    # !!!! Should old putty be frozen?
    # ktot_m = Dict((r,t) => newkm[r,t] + value(ks_m[r])*srv - sum(value(thetax)*dkml[r,s]*srv for s in set[:s])
    #     for r in set[:r]);
    ktot_m = Dict((r,t) => newkm[r,t] + value(ks_m[r])*srv
        for r in set[:r]);

    for r in set[:r]
        set_value(ks_m[r], ktot_m[r,t]);
    end

    yxl = Dict((r,s) => (haskey(YX.lookup[1], (r,s)) ? result_value(YX[(r,s)]) : 0.0)
        for r in set[:r], s in set[:s]);

    # Total extant/clay capital
    # !!!! Should old clay increase by frozen putty each period?
    # ktot_x = Dict((r,s,t) => srv*yxl[r,s]*value(kd0[r,s]) + value(thetax)*dkml[r,s]*srv
    #     for r in set[:r], s in set[:s]);
    ktot_x = Dict((r,s,t) => srv*yxl[r,s]*value(kd0[r,s])
        for r in set[:r], s in set[:s]);

    for r in set[:r], s in set[:s]
        set_value(ks_x[r,s], ktot_x[r,s,t]);
    end

    for r in set[:r], s in set[:s]
    #update labor endowments --- separate parameters for labor endowments versus demand
        set_value(le0[r,s], (1 + value(gr)) * value(le0[r,s]));
    end

    #update balance of payments and household adjustment
    for r in set[:r]
        set_value(bopdef0[r], (1 + value(gr)) * value(bopdef0[r]));
        set_value(hhadj[r], (1 + value(gr)) * value(hhadj[r]));
    end

    #update government and household production
    for r in set[:r], g in set[:g]
        set_value(g0[r,g], (1 + value(gr)) * value(g0[r,g]));
        set_value(yh0[r,g], (1 + value(gr)) * value(yh0[r,g]));
    end

    #update all model variable start values to previous period solution value
    set_start_value.(all_variables(cge), result_value.(all_variables(cge)));

    #update consumption start value
    for r in set[:r]
        set_start_value(C[r], result_value(C[r])*(1+value(gr)));
        set_start_value(INV[r], result_value(INV[r])*(1+value(gr)));
        set_start_value(W[r], result_value(W[r])*(1+value(gr)));
        set_start_value(RA[r], start_value(W[r])*value(w0[r]));
    end

    #update exports start value
    for (r,g) in set[:X]
        set_start_value(X[(r,g)], result_value(X[(r,g)])*(1+value(gr)));
#        set_start_value(RX[(r,g)], result_value(RX[(r,g)])*(1+value(gr))); # price so shouldn't be adjusted
    end

    #update armington start value
    for (r,g) in set[:A]
        set_start_value(A[(r,g)], result_value(A[(r,g)])*(1+value(gr)));
    end

    #update margin supply start value
    for r in set[:r], m in set[:m]
        set_start_value(MS[r,m], result_value(MS[r,m])*(1+value(gr)));
    end

    #update output variable start values
    # !!!! Eventually you could get so much clay, that YM level value is negative (Divide by kd0?)
    for (r,s) in set[:Y]
        set_start_value(YX[(r,s)], value(ks_x[r,s])/value(kd0[r,s])); # !!!! divide by kd0? Sensitive to thetax and dr
        set_start_value(YM[(r,s)], (start_value(C[r]) - start_value(YX[(r,s)])));
        set_start_value(DKM[(r,s)], start_value(YM[(r,s)])*value(kd0[r,s]));
    end

    #update value shares
    for r in set[:r], s in set[:s]
        set_value(alpha_kl[r,s], ensurefinite(value(ld0[r,s])/(value(ld0[r,s]) + value(kd0[r,s]))));
    end

    #update value shares
    for r in set[:r], g in set[:g]
        set_value(alpha_x[r,g], ensurefinite((value(x0[r, g]) - value(rx0[r, g])) / value(cs0[r, g])));
        set_value(alpha_d[r,g], ensurefinite((value(xd0[r,g])) / value(cs0[r, g])));
        set_value(alpha_n[r,g], ensurefinite(value(xn0[r,g]) / (value(cs0[r, g]))));
        set_value(theta_n[r,g], ensurefinite(value(nd0[r, g]) / (value(nd0[r, g]) + value(dd0[r, g]))));
        set_value(theta_m[r,g], ensurefinite((1+value(tm0[r, g])) * value(m0[r, g]) / (value(nd0[r, g]) + value(dd0[r, g]) + (1 + value(tm0[r, g])) * value(m0[r, g]))));
    end

    #set up the options for the path solver
    #PATHSolver.options(convergence_tolerance=1e-6, output=:yes, time_limit=3600, cumulative_iteration_limit=10000)
    PATHSolver.options(convergence_tolerance=1e-6, output=:yes, time_limit=3600, cumulative_iteration_limit=0)

    # solve next period
    status = solveMCP(cge)
end
=#
