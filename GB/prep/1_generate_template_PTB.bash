#!/bin/bash
#-----------------------------------------------------------------------------#
#BOP
#
# !SCRIPT: 1_generate_template_PTB
#
# !DESCRIPTION:
#
# !CALLING SEQUENCE:
#     
#        ./1_generate_template_PTB.bash ${EXPDIR}/prep ${TBLDIR} ${AREA} ${ref_file}
#
#           o EXPDIR=${RUNDIR}/${EXP}/GB
#           o TBLDIR=${BASEDIR}/pre/tables
#           o AREA : Nome da área (ex.: SaoPaulo)
#           o ref_file=${RUNDIR}/${EXP}/runinit/${LABELI}/${AREA}.init.nc
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
TBLDIR=${2}
AREA=${3}
REF_FILE=${4}

f_ref="MPAS_${AREA}.nc"
f_tmp="template_PTB.nc"

cd ${RUNDIR}

if test -s ${f_tmp}; then rm -f ${f_tmp} ; fi
if test -s ${f_tmp}_work; then rm -f ${f_tmp}_work ; fi
if test -s ${f_tmp}_single; then rm -f ${f_tmp}_single ; fi

ln -fs ${REF_FILE}  ./${f_ref}

ncks -v theta ${f_ref} ${f_tmp}_single
ncap2 -A -s "theta=0.0" ${f_tmp}_single

cp ${f_tmp}_single ${f_tmp}_work
ncrename -v theta,uReconstructZonal ${f_tmp}_work
ncatted -a long_name,uReconstructZonal,o,c,"zonal wind" ${f_tmp}_work
ncatted -a units,uReconstructZonal,o,c,"m s^{-1}" ${f_tmp}_work
ncks -A -v uReconstructZonal ${f_tmp}_work ${f_tmp}

cp ${f_tmp}_single ${f_tmp}_work
ncrename -v theta,uReconstructMeridional ${f_tmp}_work
ncatted -a long_name,uReconstructMeridional,o,c,"meridional wind" ${f_tmp}_work
ncatted -a units,uReconstructMeridional,o,c,"m s^{-1}" ${f_tmp}_work
ncks -A -v uReconstructMeridional ${f_tmp}_work ${f_tmp}

#clean up
rm ${f_ref} ${f_tmp}_single ${f_tmp}_work
