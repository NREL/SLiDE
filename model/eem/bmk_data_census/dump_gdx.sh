# dumping all data from the windcdatabase.gdx file
# that is to be used in the JuMP model 
#
# these operations will be replaced when datastream 
# and calibration are fully replicated in SLiDE
# exports sets

gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=s > set_s.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=r > set_r.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=m > set_m.csv

# defined in model from nm0+dm0 or md0
# gm(g) = yes$(sum((r,m), nm0(r,g,m) + dm0(r,g,m)) or sum((r,m), md0(r,m,g)));
# gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=gm > set_gm.csv

gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=h > set_h.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=trn > set_trn.csv

# CORE
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=ys0 > ys0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=id0 > id0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=ld0 > ld0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=kd0 > kd0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=ty0 > ty0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=m0 > m0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=x0 > x0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=rx0 > rx0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=md0 > md0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=nm0 > nm0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=dm0 > dm0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=s0 > s0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=a0 > a0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=ta0 > ta0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=tm0 > tm0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=cd0 > cd0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=c0 > c0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=yh0 > yh0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=bopdef0 > bopdef0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=hhadj > hhadj.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=g0 > g0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=i0 > i0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=xn0 > xn0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=xd0 > xd0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=dd0 > dd0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=nd0 > nd0.csv

# HH
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=pop > pop.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=le0 > le0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=ke0 > ke0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=tk0 > tk0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=tl0 > tl0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=cd0_h > cd0_h.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=c0_h > c0_h.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=sav0 > sav0.csv
# fsav0 dimensionless, fails to export value to csv properly
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=fsav0 > fsav0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=trn0 > trn0.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=hhtrn0 > hhtrn0.csv

# EEM
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=resco2 > resco2.csv
gdxdump WiNDC_bluenote_cps_census_2017.gdx format=csv symb=secco2 > secco2.csv
