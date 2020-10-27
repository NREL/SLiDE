# dumping all data from the nationaldata and windc_base gdx files
# that is to be used in the calibration exercise
#
# these operations will be replaced when datastream is replicated
# export PATH=$PATH:"/Applications/GAMS30.3/GAMS Terminal.app/Contents/MacOS"

#exporting data from nationaldata.gdx
#single set 
gdxdump nationaldata.gdx format=csv symb=m > set_m.csv

#data
gdxdump nationaldata.gdx format=csv symb=a_0 > a0.csv
gdxdump nationaldata.gdx format=csv symb=bopdef_0 > bopdef0.csv
gdxdump nationaldata.gdx format=csv symb=duty_0 > duty0.csv
gdxdump nationaldata.gdx format=csv symb=fd_0 > fd0.csv
gdxdump nationaldata.gdx format=csv symb=fs_0 > fs0.csv
gdxdump nationaldata.gdx format=csv symb=id_0 > id0.csv
gdxdump nationaldata.gdx format=csv symb=m_0 > m0.csv
gdxdump nationaldata.gdx format=csv symb=md_0 > md0.csv
gdxdump nationaldata.gdx format=csv symb=mrg_0 > mrg0.csv
gdxdump nationaldata.gdx format=csv symb=ms_0 > ms0.csv
gdxdump nationaldata.gdx format=csv symb=s_0 > s0.csv
gdxdump nationaldata.gdx format=csv symb=sbd_0 > sbd0.csv
gdxdump nationaldata.gdx format=csv symb=ta_0 > ta0.csv
gdxdump nationaldata.gdx format=csv symb=tax_0 > tax0.csv
gdxdump nationaldata.gdx format=csv symb=tm_0 > tm0.csv
gdxdump nationaldata.gdx format=csv symb=trn_0 > trn0.csv
gdxdump nationaldata.gdx format=csv symb=ts_0 > ts0.csv
gdxdump nationaldata.gdx format=csv symb=va_0 > va0.csv
gdxdump nationaldata.gdx format=csv symb=x_0 > x0.csv
gdxdump nationaldata.gdx format=csv symb=y_0 > y0.csv
gdxdump nationaldata.gdx format=csv symb=ys_0 > ys0.csv