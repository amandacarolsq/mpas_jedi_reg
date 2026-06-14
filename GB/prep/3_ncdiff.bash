#!/bin/bash
#-----------------------------------------------------------------------------#
#BOP
#
# !SCRIPT: 3_ncdiff
#
# !DESCRIPTION:
#
# !CALLING SEQUENCE:
#     
#        ./3_ncdiff.bash ${EXPDIR}/prep ${WRFBIN} ${LABELI} ${LABELF} ${fhr0} ${fhr1} ${fhr2}
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
#   - Última atualização: 10 Jun 2026
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
fhr1=${6}
fhr2=${7}

outputDir=output

workdir=${RUNDIR}/${outputDir}

cd ${workdir}

#range of "valid" valid time, which be able to define the forecast difference.
vdate=`${WRFBIN}/da_advance_time.exe $LABELI +${fhr2}h`
lastvdate=`${WRFBIN}/da_advance_time.exe $LABELF +${fhr1}h`

#initialize a counter
icnt=0

while [ $vdate -le $lastvdate ]
do

  f_fcst1=${vdate}/FULL_f${fhr1}.nc
  f_fcst2=${vdate}/FULL_f${fhr2}.nc
  f_ptb=${vdate}/PTB_f${fhr2}mf${fhr1}.nc

  if test ! -s "${f_fcst1}" -o ! -s "${f_fcst2}" ; then
   echo skipping valid date ${vdate}, files not found!
   #next idate
   vdate=`${WRFBIN}/da_advance_time.exe $vdate +${fhr0}h`
   continue
  fi
  echo "running for forecast valid fime: "$vdate

  #increase counter
  icnt=$((icnt+1))
  icntpad=$(printf "%.6d" "${icnt}")

  #populate simple job script
  cat > ncdiff_${icntpad}.bash << EOF
#!/bin/bash

ncdiff -O ${f_fcst2} ${f_fcst1} ${f_ptb}

EOF

  chmod +x ncdiff_${icntpad}.bash
  ./ncdiff_${icntpad}.bash
  #next vdate
  vdate=`${WRFBIN}/da_advance_time.exe $vdate +${fhr0}h`
done #--- for vdate


ncnt=${icnt}
echo "total "${ncnt}" scripts are generated"
