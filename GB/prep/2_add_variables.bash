#!/bin/bash
#-----------------------------------------------------------------------------#
#BOP
#
# !SCRIPT: 2_add_variables
#
# !DESCRIPTION:
#
# !CALLING SEQUENCE:
#     
#        ./2_add_variables.bash ${EXPDIR}/prep ${WRFBIN} ${LABELI} ${LABELF} ${fhr0} ${fhr1}
#        ./2_add_variables.bash ${EXPDIR}/prep ${WRFBIN} ${LABELI} ${LABELF} ${fhr0} ${fhr2}
#
#           o EXPDIR=${RUNDIR}/${EXP}/GB
#           o WRFBIN=${BASEDIR}/GB/prep
#           o LABELI : Data inicial no formato YYYYMMDDHH
#           o LABELF : Data final   no formato YYYYMMDDHH
#           o fhr0=12
#           o fhr1=24
#           o fhr2=48
# 
# !REVISION HISTORY:
#   - Adaptado por Amanda - versão inicial baseada nos scripts do Tutorial do UCAR/NCAR
#   - Última atualização: 26 Ago 2026
# 
# !REMARKS:
#
#EOP
#-----------------------------------------------------------------------------#
#BOC

module load nco-5.0.1-gcc-11.2.0-u37c3hb

RUNDIR=${1}
WRFBIN=${2}
LABELI=${3}
LABELF=${4}
fhr0=${5}
fhr=${6}

outputDir=output

workdir=${RUNDIR}/${outputDir}
mkdir -p ${workdir}

cd ${workdir}

#range of model initialization time
idate=${LABELI}
lastidate=${LABELF}

#initialize a counter
icnt=0

while [ $idate -le $lastidate ]
do
  if test ! -s $(dirname $(dirname ${RUNDIR}))/runmoc/${idate}/mpasout.${idate:0:4}-${idate:4:2}-${idate:6:2}T${idate:8:2}.00.00.nc ; then
   echo skipping date ${idate}, file not found!
   #next idate
   idate=`${WRFBIN}/da_advance_time.exe $idate +${fhr0}h`
   continue
  fi
  echo "running for model initialization time : "$idate
  vdate=`${WRFBIN}/da_advance_time.exe $idate +${fhr}h`
  echo "                      valid time time : "$vdate
  vyyyy=`echo $vdate | cut -c1-4`
  vmm=`echo $vdate | cut -c5-6`
  vdd=`echo $vdate | cut -c7-8`
  vhh=`echo $vdate | cut -c9-10`

  f_fcst=$(dirname $(dirname ${RUNDIR}))/runmoc/${idate}/mpasout.${vyyyy}-${vmm}-${vdd}T${vhh}.00.00.nc

  #increase counter
  icnt=$((icnt+1))
  icntpad=$(printf "%.6d" "${icnt}")

  #populate simple job script
  cat > add_variables_f${fhr}h_${icntpad}.bash << EOF
#!/bin/bash
  
  mkdir ${vdate}
  cp /mnt/beegfs/amanda.queiroz/reg/run/matrix/GB/prep/template_PTB.nc ${vdate}/FULL_f${fhr}.nc

  #diagnose T & sh and write out into the intermediate file
  ncap2 -s 'temperature=theta*( (pressure_p+pressure_base)/100000.0 )^(2.0/7.0) ; spechum = qv / (1.0 + qv) '  ${f_fcst}  ${vdate}/tmp_file_f${fhr}h.nc

  #add to FULL file
  ncks -A -v temperature,spechum  ${vdate}/tmp_file_f${fhr}h.nc  ${vdate}/FULL_f${fhr}.nc

  #add to FULL file
  ncks -A -v surface_pressure,uReconstructZonal,uReconstructMeridional,relhum  ${f_fcst}  ${vdate}/FULL_f${fhr}.nc

  #add cloud variables to FULL file
  ncks -A -v qc,qi,qr,qs,qg  ${f_fcst}  ${vdate}/FULL_f${fhr}.nc

  #cleanup
  rm ${vdate}/tmp_file_f${fhr}h.nc
EOF

  chmod +x add_variables_f${fhr}h_${icntpad}.bash
  ./add_variables_f${fhr}h_${icntpad}.bash
  #next idate
  idate=`${WRFBIN}/da_advance_time.exe $idate +${fhr0}h`
done #--- for idate


ncnt=${icnt}
echo "total "${ncnt}" scripts are generated"
