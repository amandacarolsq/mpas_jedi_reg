#!/bin/bash
#-----------------------------------------------------------------------------#
#BOP
#
# !SCRIPT: runPrepObs
#
# !DESCRIPTION:
#   JEDI IODA Buffer and PrepBuf observation data convertion to IODA-HDF5
#
# !CALLING SEQUENCE:
#     
#  ./runPrepObs.sh <LABELI> <LABELF>
#
#     o LABELI  : Data inicial no formato YYYYMMDDHH
#     o LABELF  : Data final   no formato YYYYMMDDHH
#
# !REVISION HISTORY:
# 03 Sept 2024 - Aravequia, J. A. - Initial Version based on part 2 of JEDI Tutorial
#                2 - Converting NCEP BUFR obs into IODA-HDF5 format
# 01 Oct 2024 - Vendrasco, E. P. - Major modification on the structure of the script.
#
#   - Adaptado por Amanda.
#   - Última atualização: 3 Ago 2026
# 
# !REMARKS:
#
#EOP
#-----------------------------------------------------------------------------#
#BOC

subwrd() {
   str=$(echo "${@}" | awk '{ for (i=1; i<=NF-1; i++) printf("%s ",$i)}')
   n=$(echo "${@}" | awk '{ print $NF }')
   echo "${str}" | awk -v var=${n} '{print $var}'
}

usage() {
   echo
   echo "Usage:"
   sed -n '/^#BOP/,/^#EOP/{/^#BOP/d;/^#EOP/d;p}' ${BASH_SOURCE}
}

inth=6

BASEDIR=${HOMEBE}/mpas_jedi_reg
RUNDIR=${BASEDIR}/obsdata
CODEDIR=${HOME}/jedi-bundle/mpas-bundle
BINDIR=${BASEDIR}/bin
TABLEDIR=${BASEDIR}/pre/tables

if [ "${arg}" == '-h' -o "${arg}" == 'help' ]; then usage ; exit 0; fi

if [ ${#} -ne 1 -a ${#} -ne 2 ]; then usage ; exit; fi

labeli=$1
labelf=$1
if [ ${#} -eq 2 ]; then 
  labelf=$2
fi

ymdh=$labeli
echo $ymdh
while [ $ymdh -le $labelf ]; do

echo "Processing "$ymdh

if test ! -s ${RUNDIR}/$ymdh ; then mkdir ${RUNDIR}/$ymdh ; fi
cd ${RUNDIR}/$ymdh

# This is defined in SMG/etc/mach/egeon_paths.conf
# Remove or comment below line after integration
ncep_ext=/oper/dados/dboper/raw/arch/mod/ncep/gdas

yy=${ymdh:0:4}
mm=${ymdh:4:2}
dd=${ymdh:6:2}
hh=${ymdh:8:2}

# for buf in $ncep_ext/$yy/$mm/$dd/gdas.t${hh}z.*;
# do   
#    name=`echo $buf |cut -d "." -f 3 ` 
#    echo ln -sf $buf $name.bufr 
#    ln -sf $buf $name.bufr 
# done

ln -sf $ncep_ext/$yy/$mm/$dd/gdas.t${hh}z.prepbufr.nr prepbufr.bufr
ln -sf $ncep_ext/$yy/$mm/$dd/gdas.t${hh}z.gpsro.tm00.bufr_d.nr gnssro.bufr
ln -sf $ncep_ext/$yy/$mm/$dd/gdas.t${hh}z.gpsipw.tm00.bufr_d.nr gpsipw.bufr  

#Full
#declare -a inpbuf=("1bamua" "1bhrs4" "airsev" "atms" "crisf4" "eshrs3" "esmhs" "gome" "mtiasi" "osbuv8" "satwnd")
#declare -a lnkbuf=("amsua"  "hrs4"   "airs"   "atms" "cris"   "eshrs3" "mhs"   "gome" "iasi"   "osbuv8" "satwnd")

declare -a inpbuf=("1bamua" "1bhrs4" "satwnd")
declare -a lnkbuf=("amsua"  "hrs4"   "satwnd")

# Get length of an array
arraylength=${#inpbuf[@]}

# Use for loop to read all values and indexes
for (( i=0; i<${arraylength}; i++ ));
do
  echo "index: $i, value: ${inpbuf[$i]}"
  inpname=${inpbuf[$i]}
  lnkname=${lnkbuf[$i]}
  echo ln -sf $ncep_ext/$yy/$mm/$dd/gdas.t${hh}z.${inpname}.tm00.bufr_d ./${lnkname}.bufr
  ln -sf $ncep_ext/$yy/$mm/$dd/gdas.t${hh}z.${inpname}.tm00.bufr_d ./${lnkname}.bufr
  if [ ${lnkname} != "satwnd" -a ${lnkname} != "hrs4" ]; then
   ln -sf ${CODEDIR}/test-data-release/crtm/fix_REL-3.1.1.2/fix/SpcCoeff/Little_Endian/*${lnkname}* .
  fi
  if [ ${lnkname} != "hrs4" ]; then
   ln -sf ${CODEDIR}/test-data-release/crtm/fix_REL-3.1.1.2/fix/SpcCoeff/Little_Endian/*hirs* .
  fi 
 
done
ln -fs ${CODEDIR}/ioda/share/ioda/yaml/validation/ObsSpace.yaml .

cp ${TABLEDIR}/obs_errtable .

cp ${BINDIR}/obs2ioda-v2.x .
time ./obs2ioda-v2.x

#  Radiances doesn´t need to convert ioda v1-to-v2
mkdir -p iodav2
mv amsua_*obs*.h5   iodav2
mv gnssro_obs_*.h5  iodav2
#mv iasi* iodav2
#mv cris* iodav2

cp ${BINDIR}/ioda-upgrade-v1-to-v2.x .
cp ${BINDIR}/ioda-upgrade-v2-to-v3.x .

# So, for aircraft/satwind/satwnd/sfc/sondes, we need run upgrade executable ioda-upgrade-v1-to-v2.x

./ioda-upgrade-v1-to-v2.x satwind_obs_${ymdh}.h5  iodav2/satwind_obs_${ymdh}.h5
./ioda-upgrade-v1-to-v2.x satwnd_obs_${ymdh}.h5   iodav2/satwnd_obs_${ymdh}.h5
./ioda-upgrade-v1-to-v2.x sfc_obs_${ymdh}.h5      iodav2/sfc_obs_${ymdh}.h5
./ioda-upgrade-v1-to-v2.x aircraft_obs_${ymdh}.h5 iodav2/aircraft_obs_${ymdh}.h5
./ioda-upgrade-v1-to-v2.x sondes_obs_${ymdh}.h5   iodav2/sondes_obs_${ymdh}.h5
./ioda-upgrade-v1-to-v2.x ascat_obs_${ymdh}.h5    iodav2/ascat_obs_${ymdh}.h5

#
# 2.4 Generate IODAv3
#

rm ./aircraft_obs_${ymdh}.h5 
rm ./ascat_obs_${ymdh}.h5
#rm ./gnssro_obs_${ymdh}.h5 
rm ./satwind_obs_${ymdh}.h5 
rm ./satwnd_obs_${ymdh}.h5 
rm ./sfc_obs_${ymdh}.h5 
rm ./sondes_obs_${ymdh}.h5 
#rm ./amsua_n15_obs_${ymdh}.h5 
#rm ./amsua_n18_obs_${ymdh}.h5 
#rm ./amsua_n19_obs_${ymdh}.h5 
#rm ./amsua_metop-a_obs_${ymdh}.h5 
#rm ./amsua_metop-b_obs_${ymdh}.h5 
#rm ./amsua_metop-c_obs_${ymdh}.h5 
#rm ./cris_n20_obs_${ymdh}.h5 
#rm ./iasi_metop-b_obs_${ymdh}.h5 
#rm ./iasi_metop-c_obs_${ymdh}.h5 

./ioda-upgrade-v2-to-v3.x iodav2/aircraft_obs_${ymdh}.h5 ./aircraft_obs_${ymdh}.h5 ObsSpace.yaml
./ioda-upgrade-v2-to-v3.x iodav2/gnssro_obs_${ymdh}.h5 ./gnssro_obs_${ymdh}.h5 ObsSpace.yaml
./ioda-upgrade-v2-to-v3.x iodav2/satwind_obs_${ymdh}.h5 ./satwind_obs_${ymdh}.h5 ObsSpace.yaml
./ioda-upgrade-v2-to-v3.x iodav2/satwnd_obs_${ymdh}.h5 ./satwnd_obs_${ymdh}.h5 ObsSpace.yaml
./ioda-upgrade-v2-to-v3.x iodav2/sfc_obs_${ymdh}.h5 ./sfc_obs_${ymdh}.h5 ObsSpace.yaml
./ioda-upgrade-v2-to-v3.x iodav2/sondes_obs_${ymdh}.h5 ./sondes_obs_${ymdh}.h5 ObsSpace.yaml
./ioda-upgrade-v2-to-v3.x iodav2/ascat_obs_${ymdh}.h5 ./ascat_obs_${ymdh}.h5 ObsSpace.yaml
#./ioda-upgrade-v2-to-v3.x iodav2/amsua_n15_obs_${ymdh}.h5 ./amsua_n15_obs_${ymdh}.h5 ObsSpace.yaml
#./ioda-upgrade-v2-to-v3.x iodav2/amsua_n18_obs_${ymdh}.h5 ./amsua_n18_obs_${ymdh}.h5 ObsSpace.yaml
#./ioda-upgrade-v2-to-v3.x iodav2/amsua_n19_obs_${ymdh}.h5 ./amsua_n19_obs_${ymdh}.h5 ObsSpace.yaml
#./ioda-upgrade-v2-to-v3.x iodav2/amsua_metop-a_obs_${ymdh}.h5 ./amsua_metop-a_obs_${ymdh}.h5 ObsSpace.yaml
./ioda-upgrade-v2-to-v3.x iodav2/amsua_metop-b_obs_${ymdh}.h5 ./amsua_metop-b_obs_${ymdh}.h5 ObsSpace.yaml
./ioda-upgrade-v2-to-v3.x iodav2/amsua_metop-c_obs_${ymdh}.h5 ./amsua_metop-c_obs_${ymdh}.h5 ObsSpace.yaml
#./ioda-upgrade-v2-to-v3.x iodav2/cris_n20_obs_${ymdh}.h5 ./cris_n20_obs_${ymdh}.h5 ObsSpace.yaml
#./ioda-upgrade-v2-to-v3.x iodav2/iasi_metop-b_obs_${ymdh}.h5 ./iasi_metop-b_obs_${ymdh}.h5 ObsSpace.yaml
#./ioda-upgrade-v2-to-v3.x iodav2/iasi_metop-c_obs_${ymdh}.h5 ./iasi_metop-c_obs_${ymdh}.h5 ObsSpace.yaml

ymdh=$(date --date "${ymdh:0:8} ${ymdh:8:9}00 ${inth} hours" +%Y%m%d%H)

done

#ln -sf ../MPAS_JEDI_yamls_scripts/run_updateSensorScanPosition.csh
#./run_updateSensorScanPosition.csh

#cd graphics/standalone

#conda activate /mnt/beegfs/professor/conda/envs/mpasjedi
#python my_plot_obs_loc.py cycling ${ymdh}

exit

#EOC

