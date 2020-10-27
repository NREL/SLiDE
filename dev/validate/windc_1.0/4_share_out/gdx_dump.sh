# dumping all data from the nationaldata and windc_base gdx files
# that is to be used in the calibration exercise
#
# these operations will be replaced when datastream is replicated
# export PATH=$PATH:"/Applications/GAMS30.3/GAMS Terminal.app/Contents/MacOS"

# Exporting data from shares_cfs
gdxdump cfs_rpcs.gdx format=csv symb=rpc > rpc.csv
# d0, mrt0, xn0, mn0, ng, temp_d0, temp_xn0, temp_mn0
# gdxdump cfs_rpcs.gdx format=csv symb=rpc > rpc.csv
# gdxdump cfs_rpcs.gdx format=csv symb=d0 > d0.csv
# gdxdump cfs_rpcs.gdx format=csv symb=mrt0 > mrt0.csv
# gdxdump cfs_rpcs.gdx format=csv symb=xn0 > xn0.csv
# gdxdump cfs_rpcs.gdx format=csv symb=mn0 > mn0.csv
# gdxdump cfs_rpcs.gdx format=csv symb=ng > ng.csv
# gdxdump cfs_rpcs.gdx format=csv symb=temp_d0 > temp_d0.csv
# gdxdump cfs_rpcs.gdx format=csv symb=temp_xn0 > temp_xn0.csv
# gdxdump cfs_rpcs.gdx format=csv symb=temp_mn0 > temp_mn0.csv

# Exporting data from shares_gsp
gdxdump shares_gsp.gdx format=csv symb=labor_shr > labor_shr.csv
gdxdump shares_gsp.gdx format=csv symb=region_shr > region_shr.csv
# gdxdump shares_gsp.gdx format=csv symb=netva > netva.csv
# gdxdump shares_gsp.gdx format=csv symb=hw > hw.csv
# gdxdump shares_gsp.gdx format=csv symb=wg > wg.csv
# gdxdump shares_gsp.gdx format=csv symb=seclaborshr > seclaborshr.csv
# gdxdump shares_gsp.gdx format=csv symb=avgwgshr > avgwgshr.csv
# gdxdump shares_gsp.gdx format=csv symb=gsp0 > gsp0.csv
# gdxdump shares_gsp.gdx format=csv symb=gspcat0 > gspcat0.csv
# gdxdump shares_gsp.gdx format=csv symb=lshr_0 > lshr0.csv
# gdxdump shares_gsp.gdx format=csv symb=temp_labor_shr > temp_labor_shr.csv

# Exporting data from shares_pce
gdxdump shares_pce.gdx format=csv symb=pce_shr > pce_shr.csv

# Exporting data from shares_sgf
gdxdump shares_sgf.gdx format=csv symb=sgf_shr > sgf_shr.csv
# sgf_raw_units, sgf_map
# gdxdump shares_sgf.gdx format=csv symb=sgf_raw_units > sgf_raw.csv
# gdxdump shares_sgf.gdx format=csv symb=sgf_map > sgf_map.csv
# gdxdump shares_sgf.gdx format=csv symb=temp_sgf_shr > temp_sgf_shr.csv

# Exporting data from shares_usatrd
gdxdump shares_usatrd.gdx format=csv symb=notinc > notinc.csv
gdxdump shares_usatrd.gdx format=csv symb=usatrd_shr > usatrd_shr.csv