#!/bin/bash
#-----------------------------------------------------------------------------#
#BOP
#
# !SCRIPT: 0_link_samples
#
# !DESCRIPTION:
#
# !CALLING SEQUENCE:
#     
#        ./0_link_samples.bash ${EXPDIR} ${WRFBIN} ${LABELI} ${LABELF} ${fhr0} ${fhr1} ${fhr2}
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

RUNDIR=${1}
WRFBIN=${2}
LABELI=${3}
LABELF=${4}
fhr0=${5}
fhr1=${6}
fhr2=${7}

rawSamplesDir=${RUNDIR}/prep/output
samplesDir=${RUNDIR}/proc/samples

#vdate
date=`${WRFBIN}/da_advance_time.exe $LABELI +${fhr2}h`
lastdate=`${WRFBIN}/da_advance_time.exe $LABELF +${fhr1}h`

workdir=${samplesDir}

mkdir -p ${workdir}
cd ${workdir}

imem=1  #sample index

while [ $date -le $lastdate ]
do

  fileTarget=${rawSamplesDir}/${date}/PTB_f48mf24.nc
  if [ -s ${fileTarget} ]; then
    echo "running for "$date
    member=`printf "%03d\n" $imem`  # three digit with zero peddings
    ln -fs ${fileTarget}  ./PTB_f48mf24_${member}.nc
    imem=$((imem+1))
  fi

  date=`${WRFBIN}/da_advance_time.exe $date +${fhr0}h`
done #--- for date

