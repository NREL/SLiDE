WINDC="$GIT/WiNDC"
MAPS="coremaps"

arr=("windc_build/build_files/maps"
    "windc_build/build_files/user_defined_schemes"
    "windc_datastream/core_maps"
    "windc_datastream/core_maps/gams")
    
for i in "${arr[@]}"
do
    cp $WINDC/$i/* $MAPS/$i/.
done