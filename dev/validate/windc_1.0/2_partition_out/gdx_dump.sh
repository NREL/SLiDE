# dumping all data from the national_cgeparm_raw and windc_base gdx files
# that is to be used in the calibration exercise
#
# these operations will be replaced when datastream is replicated
# export PATH=$PATH:"/Applications/GAMS30.3/GAMS Terminal.app/Contents/MacOS"

#exporting data from windc_base.gdx
#following are all sets
# gdxdump windc_base.gdx format=csv symb=yr > set_yr.csv
# gdxdump windc_base.gdx format=csv symb=i > set_i.csv
# gdxdump windc_base.gdx format=csv symb=va > set_va.csv
# gdxdump windc_base.gdx format=csv symb=fd > set_fd.csv
# gdxdump windc_base.gdx format=csv symb=ts > set_ts.csv


#exporting data from national_cgeparm_raw.gdx
#single set 
gdxdump national_cgeparm_raw.gdx format=csv symb=m > set_m.csv

#data
gdxdump national_cgeparm_raw.gdx format=csv symb=y0 > y0.csv
gdxdump national_cgeparm_raw.gdx format=csv symb=ys0 > ys0.csv
gdxdump national_cgeparm_raw.gdx format=csv symb=fs0 > fs0.csv
gdxdump national_cgeparm_raw.gdx format=csv symb=id0 > id0.csv
gdxdump national_cgeparm_raw.gdx format=csv symb=fd0 > fd0.csv
gdxdump national_cgeparm_raw.gdx format=csv symb=va0 > va0.csv
gdxdump national_cgeparm_raw.gdx format=csv symb=m0 > m0.csv
gdxdump national_cgeparm_raw.gdx format=csv symb=x0 > x0.csv
gdxdump national_cgeparm_raw.gdx format=csv symb=ms0 > ms0.csv
gdxdump national_cgeparm_raw.gdx format=csv symb=md0 > md0.csv
gdxdump national_cgeparm_raw.gdx format=csv symb=a0 > a0.csv
gdxdump national_cgeparm_raw.gdx format=csv symb=ta0 > ta0.csv
gdxdump national_cgeparm_raw.gdx format=csv symb=tm0 > tm0.csv

