#!/bin/bash
#-----------------------------------------------------------------------------#
#BOP
#
# !SCRIPT: runUngrib_IC
#
# !DESCRIPTION:
#   Script para execução do ungrib das condições iniciais (IC) do GFS no MPAS-JEDI regional.
#   O script prepara o ambiente, cria o link necessário para 
#   o arquivo GRIB do GFS, gera o namelist apropriado
#   e executa o ungrib (unMP.exe).
#
# !CALLING SEQUENCE:
#   ./runUngrib_IC.sh <EXP> <RES> <AREA> <LABELI> <LABELF> 
#
#     o EXP    : Nome do experimento (ex.: EXP1)
#     o RES    : Resolução do experimento (ex.: 163842 para 60 km)
#     o AREA   : Nome da área (ex.: SaoPaulo)
#     o LABELI : Data inicial no formato YYYYMMDDHH
#     o LABELF : Data final   no formato YYYYMMDDHH
#
# !EXAMPLE:
#   ./runUngrib_IC.sh EXP1 163842 SaoPaulo 2026051500 2026052000
#
# !REVISION HISTORY:
#   - Adaptado por Amanda.
#   - Última atualização: 9 Jun 2026
#
# !REMARKS:
#   - Espera encontrar os dados do GFS organizados por YYYY/MM/DD/HH em GFSDIR.
#   - Requer o arquivo estático regional (${AREA}.static.nc) já existente.
#   - Gera arquivos como GFS:2025-09-01_00 dentro de 
#   EXPDIR=${RUNDIR}/${EXP}/${LABELI:0:10}
#   - Nessa etapa, só precisa realizar o ungrib do arquivo da data inicial. 
#
#EOP
#-----------------------------------------------------------------------------#
#BOC

function usage(){
   sed -n '/^#BOP/,/^#EOP/{/^#BOP/d;/^#EOP/d;p}' ${BASH_SOURCE}
}

if [ $# -ne 5 ]; then
   usage
   exit 1
fi

#
# Argumentos
#

EXP=${1}
RES=${2}
AREA=${3}
LABELI=${4}
LABELF=${5}

start_date=${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}_${LABELI:8:2}:00:00
end_date=${LABELF:0:4}-${LABELF:4:2}-${LABELF:6:2}_${LABELF:8:2}:00:00

#
# Set paths
#

export LD_LIBRARY_PATH=$NETCDF/lib:$HDF5/lib:$GRIB2/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH="/home/amanda.queiroz/jedi-bundle/build-jedi/lib:$LD_LIBRARY_PATH"

BASEDIR=${HOMEBE}/mpas_jedi_reg
RUNDIR=${BASEDIR}/run
GFSDIR=${BASEDIR}/gfsdata
DATADIR=${BASEDIR}/pre/datain
TBLDIR=${BASEDIR}/pre/tables
PRERUNDIR=${BASEDIR}/pre/run
NMLDIR=${BASEDIR}/namelist
EXEDIR=${BASEDIR}/pre/exec
BNDDIR=${GFSDIR}/${LABELI:0:4}/${LABELI:4:2}/${LABELI:6:2}/${LABELI:8:2}
EXPDIR=${RUNDIR}/${EXP}
STATICDIR=${RUNDIR}/${EXP}/static

#

RUNINIT=${RUNDIR}/${EXP}/runinit/${LABELI:0:4}${LABELI:4:2}${LABELI:6:2}${LABELI:8:2}
LOGDIR=${RUNINIT}/logs

#
# Criando diretórios da rodada
#

[ ! -d "${RUNINIT}" ] && mkdir -p "${RUNINIT}"

for dir in logs sst wpsprd namelist; do
    mkdir -p "${RUNINIT}/${dir}"
done

#
# Recorte dos dados globais do GFS
#

path_reg=${DATADIR}/regional/${LABELI}

cd ${RUNINIT}/wpsprd
mkdir -p ${path_reg}
if [ ! -e ${path_reg}/gfs.t${LABELI:8:2}z.pgrb2.0p25.f000.${LABELI}.grib2  ]; then
   echo "File ${path_reg}/gfs.t${LABELI:8:2}z.pgrb2.0p25.f000.${LABELI}.grib2 does not exist."
   cdo sellonlatbox,260,350,-70,20 ${BNDDIR}/gfs.t${LABELI:8:2}z.pgrb2.0p25.f000.${LABELI}.grib2  ${path_reg}/gfs.t${LABELI:8:2}z.pgrb2.0p25.f000.${LABELI}.grib2
   cp -urf ${path_reg}/gfs.t${LABELI:8:2}z.pgrb2.0p25.f000.${LABELI}.grib2 ${RUNINIT}/wpsprd/gfs.t${LABELI:8:2}z.pgrb2.0p25.f000.${LABELI}.grib2
else
   echo "File ${path_reg}/gfs.t${LABELI:8:2}z.pgrb2.0p25.f000.${LABELI}.grib2 exists"
   cp -urf ${path_reg}/gfs.t${LABELI:8:2}z.pgrb2.0p25.f000.${LABELI}.grib2 ${RUNINIT}/wpsprd/gfs.t${LABELI:8:2}z.pgrb2.0p25.f000.${LABELI}.grib2
fi

#
# Script
#

NNODES=1
JNAME=ungrib_IC
QUEUE=PESQ1

cat > ${RUNINIT}/ungrib_ic_exe.sh << EOF0
#!/bin/bash
#SBATCH --job-name=${JNAME}
#SBATCH --partition=${QUEUE}
#SBATCH --exclusive
#SBATCH --nodes=${NNODES}
#SBATCH --tasks-per-node=1                      # ic for benchmark
#SBATCH --time=00:30:00
#SBATCH --output=${LOGDIR}/ungrib.log    # File name for standard output

#
ulimit -s unlimited
ulimit -c unlimited
ulimit -v unlimited

export PMIX_MCA_gds=hash

echo  "STARTING AT \`date\` "
Start=\`date +%s.%N\`
echo \$Start > Timing.ungrib
#
cd ${RUNINIT}
 
ln -sf ${STATICDIR}/${AREA}.static.nc .

cd ${RUNINIT}/wpsprd

#

echo "FORECAST "${LABELI}

cp ${TBLDIR}/Vtable.GFS ${RUNINIT}/wpsprd/Vtable

cp ${PRERUNDIR}/link_grib.csh ${RUNINIT}/wpsprd/link_grib.csh 
chmod 777 ${RUNINIT}/wpsprd/link_grib.csh

cp ${EXEDIR}/unMP.exe ${RUNINIT}/wpsprd/unMP.exe

export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:${HOME}/local/lib64

ldd unMP.exe

#
# Namelist
#

cd ${RUNINIT}/wpsprd 

if [ -e namelist.wps ]; then rm -f namelist.wps; fi

rm -f GRIBFILE.* namelist.wps

sed -e "s,#LABELI#,${start_date},g;s,#PREFIX#,GFS,g" \
	${NMLDIR}/namelist.wps.TEMPLATE.${EXP} > ./namelist.wps

#

${RUNINIT}/wpsprd/link_grib.csh gfs.t${LABELI:8:2}z.pgrb2.0p25.f000.${LABELI}.grib2

mpirun -np 1 ./unMP.exe

echo ${start_date:0:13}

rm -f GRIBFILE.*

End=\`date +%s.%N\`
echo  "FINISHED AT \`date\` "
echo \$End   >>Timing.ungrib
echo \$Start \$End | gawk '{print \$2 - \$1" sec"}' >> Timing.ungrib

grep "Successful completion of program ungrib.exe" ungrib.log >& /dev/null

if [ \$? -ne 0 ]; then
   echo "  BUMMER: Ungrib generation failed for some yet unknown reason."
   echo " "
   tail -10 ungrib.log
   echo " "
   exit 21
fi
   echo "  ####################################"
   echo "  ### Ungrib completed - \$(date) ####"
   echo "  ####################################"
   echo " " 

#
# Clean up and remove links
#
   mv Timing.ungrib   ${LOGDIR}
   mv ungrib.log ${LOGDIR}/ungrib.IC.log
   mv namelist.wps    ${RUNINIT}/namelist
   rm -f ${RUNINIT}/wpsprd/link_grib.csh
   cd ..
   ln -sf wpsprd/GFS\:${start_date:0:13} FILE3\:${start_date:0:13}
   find ${RUNINIT}/wpsprd -maxdepth 1 -type l -exec rm -f {} \;

echo "End of ungrib Job"

exit 0
EOF0

chmod +x ${RUNINIT}/ungrib_ic_exe.sh

echo -e  "${GREEN}==>${NC} Submiting ungrib_ic_exe.sh...\n"
mkdir -p ${HOME}/local/lib64
cp -f /usr/lib64/libjasper.so* ${HOME}/local/lib64
cp -f /usr/lib64/libjpeg.so* ${HOME}/local/lib64

cd ${RUNINIT}/wpsprd/

echo sbatch --wait ${RUNINIT}/ungrib_ic_exe.sh

if [ "${SLURM:-NO}" == "NO" ]; then
  ${RUNINIT}/ungrib_ic_exe.sh
else
  sbatch --wait ${RUNINIT}/ungrib_ic_exe.sh
fi

export start_date=${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}_${LABELI:8:2}:00:00

files_ungrib=("LSM:${start_date:0:13}" "GEO:${start_date:0:13}" "FILE:${start_date:0:13}" "FILE2:${start_date:0:13}" "FILE3:${start_date:0:13}")

#EOC
