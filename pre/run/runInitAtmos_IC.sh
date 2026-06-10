#!/bin/bash
#-----------------------------------------------------------------------------#
#BOP
#
# !SCRIPT: runInitAtmos_IC
#
# !DESCRIPTION:
#   Script para geração das condições iniciais (IC)
#   do MPAS-JEDI regional, utilizando análises do GFS.
#
#   O script executa as seguintes etapas:
#     - Prepara a estrutura de diretórios do experimento para cada data de análise;
#     - Copia e linka o arquivo estático regional (${AREA}.static.nc);
#     - Cria links simbólicos para os arquivos do GFS correspondentes e para o
#       arquivo particionado (${AREA}.graph.info.part.*)
#     - Gera os arquivos namelist e streams do init_atmosphere a partir de templates;
#     - Submete, via SLURM, a execução paralela do mpas_init_atmosphere;
#     - Produz os arquivos de IC necessários para a integração
#       regional do MPAS.
#
# !CALLING SEQUENCE:
#   ./runInitAtmos_IC.sh <EXP> <RES> <AREA> <LABELI> <LABELF> 
#
#     o EXP    : Nome do experimento (ex.: EXP1)
#     o LABELI : Data inicial no formato YYYYMMDDHH
#     o LABELF : Data final   no formato YYYYMMDDHH
#     o AREA   : Nome da área (ex.: SaoPaulo)
#     o RES    : Resolução do experimento (ex.: 163842 para 60 km)
#
# !EXAMPLE:
#   ./runInitAtmos_IC.sh EXP1 163842 SaoPaulo 2026051500 2026052000
#
# !REVISION HISTORY:
#   - Adaptado por Amanda.
#   - Última atualização: 9 Jun 2026
#
# !REMARKS:
#   - Espera encontrar os dados do GFS organizados por YYYY/MM/DD/HH em GFSDIR.
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

BASEDIR=${HOMEBE}/mpas_jedi_reg
MESH_DIR=${BASEDIR}/pre/meshes/${AREA}
GFSDIR=${BASEDIR}/gfsdata
SSTDIR=${BASEDIR}/sstdata
EXEDIR=${BASEDIR}/pre/exec
PRERUNDIR=${BASEDIR}/pre/run
TBLDIR=${BASEDIR}/pre/tables
GEODATA=${BASEDIR}/pre/databcs/WPS_GEOG
NMLDIR=${BASEDIR}/namelist
RUNDIR=${BASEDIR}/run
EXPDIR=${RUNDIR}/${EXP}
STATICDIR=${RUNDIR}/${EXP}/static

GFSRES="0p25"

#
# Seleciona o ncores
#

case "`echo ${RES} | gawk '{print $1/1 }'`" in
65536002)cores_model=514 ;nodes_model=4 ;cores=256 ;cores_stat=32  ;nodes=2 ;;
 2621442)cores_model=256 ;nodes_model=2 ;cores=128 ;cores_stat=32  ;nodes=1 ;; 
 1024002)cores_model=128 ;nodes_model=1 ;cores=32  ;cores_stat=32  ;nodes=1 ;;     
  655362)cores_model=4   ;nodes_model=1 ;cores=4   ;cores_stat=1   ;nodes=1 ;; 
  256002)cores_model=20  ;nodes_model=1 ;cores=20  ;cores_stat=32  ;nodes=1 ;; 
  163842)cores_model=16  ;nodes_model=1 ;cores=16  ;cores_stat=32  ;nodes=1 ;; 
   40962)cores_model=4   ;nodes_model=4 ;cores=4   ;cores_stat=1   ;nodes=1 ;; 
   10242)cores_model=8   ;nodes_model=1 ;cores=8   ;cores_stat=32  ;nodes=1 ;; 
    4002)cores_model=6   ;nodes_model=1 ;cores=6   ;cores_stat=32  ;nodes=1 ;; 
    2562)cores_model=2   ;nodes_model=1 ;cores=2   ;cores_stat=32  ;nodes=1 ;; 
esac

if [[ -z "${cores}" ]]; then
  echo "Erro: cores não foi definido. Verifique RES=${RES}"
  exit 1
fi

echo

#

RUNINIT=${RUNDIR}/${EXP}/runinit/${LABELI:0:4}${LABELI:4:2}${LABELI:6:2}${LABELI:8:2}
LOGDIR=${RUNINIT}/logs

#
# Criando diretórios da rodada
#

if [ ! -e ${RUNINIT} ]; then
   mkdir -p ${RUNINIT}
   mkdir -p ${RUNINIT}/logs   
   mkdir -p ${RUNINIT}/sst
   mkdir -p ${RUNINIT}/wpsprd
   mkdir -p ${RUNINIT}/namelist
fi

if [ -e ${RUNINIT}/FILE3:${start_date:0:13}  ]; then
   echo "File exist."
else
   echo "${RUNINIT}/FILE3:${start_date:0:13}"
   echo "File not exists"
   echo "Condicao de contorno inexistente!"
   echo "Verifique a data da rodada."
   echo "File does not exist."
   exit 44
fi

cd ${RUNINIT}

#
# Script
#

NNODES=${nodes}
NTASKSPN=128
#(( NTASKS = NTASKSPN * NNODES ))
ln -sf ${MESH_DIR}/${AREA}.graph.info.part.${cores_stat} ${RUNINIT}
ln -sf ${STATICDIR}/${AREA}.static.nc ${RUNINIT}
JNAME=init_IC
QUEUE=PESQ1
cat > init.slurm <<EOF0 # ?
#!/bin/bash

#SBATCH --output=${RUNINIT}/logs/log.init
#SBATCH --nodes=${NNODES}
#SBATCH --ntasks-per-node=${NTASKSPN}
#SBATCH --cpus-per-task=1
#SBATCH --ntasks=${cores_stat}
#SBATCH --exclusive
#SBATCH --time=00:30:00
#SBATCH --job-name=${JNAME}
#SBATCH --partition=${QUEUE}

export OMP_NUM_THREADS=1

ulimit -c unlimited
ulimit -v unlimited
ulimit -s unlimited

cd ${RUNINIT}

#
# Namelist
#

sed -e "s,#LABELI#,${start_date},g;s,#GEODAT#,${GEODATA},g;s,#AREA#,${AREA},g" \
	 ${NMLDIR}/namelist.init_atmosphere.TEMPLATE.${EXP} > ./namelist.init_atmosphere

sed -e "s,#AREA#,${AREA},g" \
	 ${NMLDIR}/streams.init_atmosphere.TEMPLATE.${EXP} > ./streams.init_atmosphere

#

rm -f ${AREA}.init.nc

echo  "STARTING AT \`date\` "
Start=\`date +%s.%N\`
echo \$Start >  ${RUNINIT}/logs/Timing.init

date

export LD_LIBRARY_PATH="/home/amanda.queiroz/jedi-bundle/build-jedi/lib:$LD_LIBRARY_PATH"

time mpirun -np ${NTASKS} ${EXEDIR}/mpas_init_atmosphere &> ${RUNINIT}/logs/log.init
wait
# cp ${RUNINIT}/namelist.init_atmosphere_sst ${RUNINIT}/namelist.init_atmosphere 
# time mpirun -np ${NTASKS} ${EXEDIR}/mpas_init_atmosphere &> ${RUNINIT}/logs/log.init
# wait

End=\`date +%s.%N\`
echo  "FINISHED AT \`date\` "
echo \$End   >> ${RUNINIT}/logs/Timing.init
echo \$Start \$End | awk '{print \$2 - \$1" sec"}' >>  ${RUNINIT}/logs/Timing.init

date

if test -s log.init_atmosphere.0000.out ; then errorcode=\$(cat log.init_atmosphere.0000.out | tail -4 | head -1 | awk '{print \$4}') ; fi

# echo "ERRORCODE: \$errorcode"

if [ 'x'\$errorcode == x0 ]; then
 echo "INIT Run Successfully"
 python ${BASEDIR}/scripts/change_xtime.py

 mv ${LOGDIR}/Timing.init ${LOGDIR}/Timing.init.IC
 mv ${LOGDIR}/log.init ${LOGDIR}/log.init.IC
 mv log.init_atmosphere.0000.out ${LOGDIR}/log.init_atmosphere.IC.0000.out
 mv log.init_atmosphere.0000.err ${LOGDIR}/log.init_atmosphere.IC.0000.err
 mv namelist.init_atmosphere ${RUNINIT}/namelist/namelist.init_atmosphere.TEMPLATE
 mv streams.init_atmosphere ${RUNINIT}/namelist/streams.init_atmosphere.TEMPLATE
 
else
 echo ">>>>> Error in Init Run <<<<<"
fi

exit 0
EOF0

chmod +x init.slurm

if [ 'x'$pid == 'x' ]; then
  sbatch --wait ./init.slurm
 else
  sbatch --dependency=afterok:${pid} ./init.slurm
fi

#EOC
