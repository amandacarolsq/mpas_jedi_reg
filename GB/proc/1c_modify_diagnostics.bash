#!/bin/bash
#-----------------------------------------------------------------------------#
#BOP
#
# !SCRIPT: 1b_run_hdiag_var
#
# !DESCRIPTION:
#
# !CALLING SEQUENCE:
#     
#        ./1b_run_hdiag_var.bash ${EXPDIR}/proc ${BASEDIR}/GB/proc
#
#           o EXPDIR=${RUNDIR}/${EXP}/GB
#           o GBDIR=${BASEDIR}/GB/proc
# 
# !REVISION HISTORY:
#   - Adaptado por Amanda - versão inicial baseada nos scripts do Tutorial do UCAR/NCAR
#   - Última atualização: 14 Jun 2026
# 
# !REMARKS:
#
#EOP
#-----------------------------------------------------------------------------#
#BOC

module load nco-5.0.1-gcc-11.2.0-u37c3hb

RUNDIR=${1}
GBDIR=${2}

hdiagVarDir=${RUNDIR}/HDIAG_VAR
hdiagVarMergeDir=${hdiagVarDir}/merge

include_hydrometeor=1  #1: yes, 2: no
isTuneHdiag=1          #1: yes
isTuneVar=1            #1: yes

workdir=${hdiagVarMergeDir}

mkdir -p ${workdir}
cd ${workdir}

# copy corr-length diagnostic & variance files
cp ${hdiagVarDir}/vargroup1/mpas.cor_rh.nc   ./
cp ${hdiagVarDir}/vargroup1/mpas.cor_rv.nc   ./
cp ${hdiagVarDir}/vargroup1/mpas.stddev.nc   ./

# merge multiple files if necessary
if [ ${include_hydrometeor} -eq 1 ]; then
  echo "include_hydrometeor = "${include_hydrometeor}
 
  ncks -A -v qc,qi,qr,qs,qg ${hdiagVarDir}/vargroup2/mpas.cor_rh.nc  ./mpas.cor_rh.nc
  ncks -A -v qc,qi,qr,qs,qg ${hdiagVarDir}/vargroup2/mpas.cor_rv.nc  ./mpas.cor_rv.nc
  ncks -A -v qc,qi,qr,qs,qg ${hdiagVarDir}/vargroup2/mpas.stddev.nc  ./mpas.stddev.nc
fi

# remove the missing values for hydro diagnostics
if [ ${include_hydrometeor} -eq 1 ]; then
  echo "include_hydrometeor = "${include_hydrometeor}
  cp ${GBDIR}/etc_modify_missing.bash   ./
  bash etc_modify_missing.bash
fi

# modify the corr-length if necessary
if [ ${isTuneHdiag} -eq 1 ]; then
  echo "isTuneHdiag = "${isTuneHdiag}
  cp ${GBDIR}/etc_modify_cor.bash   ./
  bash etc_modify_cor.bash
fi

# modify the variance if necessary
if [ ${isTuneVar} -eq 1 ]; then
  echo "isTuneVar = "${isTuneVar}
  cp ${GBDIR}/etc_modify_var.bash     ./
  bash etc_modify_var.bash
fi

