#!/bin/bash
#-----------------------------------------------------------------------------#
#BOP
#
# !SCRIPT: runInvariant
#
# !DESCRIPTION:
#   Script para geração do arquivo invariant (invariant.nc) do MPAS-JEDI regional.
#   O script prepara o ambiente, configura os parâmetros necessários
#   e executa o mpas_init_atmosphere para criar o arquivo invariant
#   correspondente à área e resolução especificadas.
#
#
# !CALLING SEQUENCE:
#   ./runInvariant.sh <EXP> <RES> <AREA> <LABELI>
#
#     o EXP    : Nome do experimento (ex.: EXP1)
#     o RES    : Resolução do experimento (ex.: 163842 para 60 km)
#     o AREA   : Nome da área/região (ex.: SaoPaulo)
#     o LABELI : Data inicial no formato YYYYMMDDHH
#
# !EXAMPLE:
#   ./runInvariant.sh EXP1 163842 SaoPaulo 2026051500
#
# !REVISION HISTORY:
#   - Adaptado por Amanda para rodar o mpas_init_atmosphere 
#     e gerar o arquivo invariante regional (invariant.nc).
#   - Última atualização: 9 Jun 2026
#
#
#EOP
#-----------------------------------------------------------------------------#
#BOC

function usage(){
   sed -n '/^#BOP/,/^#EOP/{/^#BOP/d;/^#EOP/d;p}' ${BASH_SOURCE}
}

if [ $# -ne 4 ]; then
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

#
# Set paths
#

export LD_LIBRARY_PATH=$NETCDF/lib:$HDF5/lib:$GRIB2/lib:$LD_LIBRARY_PATH

BASEDIR=${HOMEBE}/mpas_jedi_reg
GEODATA=${BASEDIR}/pre/databcs/WPS_GEOG/
RUNDIR=${BASEDIR}/run
EXEDIR=${BASEDIR}/pre/exec
TBLDIR=${BASEDIR}/pre/tables
MESH_DIR=${BASEDIR}/pre/meshes/${AREA}
NMLDIR=${BASEDIR}/namelist
EXPDIR=${RUNDIR}/${EXP}
INVDIR=${RUNDIR}/${EXP}/invariant/${LABELI:0:4}${LABELI:4:2}${LABELI:6:2}${LABELI:8:2}

#

if [ ! -d ${INVDIR} ]; then
  mkdir -p ${INVDIR}/logs
fi

cd ${INVDIR}

ln -sf ${TBLDIR}/* .
ln -sf ${MESH_DIR}/${AREA}.grid.nc .
ln -sf ${RUNDIR}/${EXP}/static/${AREA}.static.nc .

cp -f ${EXEDIR}/mpas_init_atmosphere .

#
# Namelist
#

start_date=${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}_${LABELI:8:2}:00:00

sed -e "s,#LABELI#,${start_date},g;s,#GEODAT#,${GEODATA},g;s,#RES#,${RES},g;s,#AREA#,${AREA},g" \
	${NMLDIR}/namelist.init_atmosphere.INVARIANT.${EXP} \
       > ${INVDIR}/namelist.init_atmosphere

sed -e "s,#AREA#,${AREA},g" \
       	${NMLDIR}/streams.init_atmosphere.INVARIANT.${EXP} \
	> ${INVDIR}/streams.init_atmosphere

#
# Seleciona o ncores
#

case "`echo ${RES} | awk '{print $1/1 }'`" in
65536002)cores_model=512 ;nodes_model=4 ;cores=256 ;cores_stat=32  ;nodes=2 ;;
 2621442)cores_model=256 ;nodes_model=2 ;cores=128 ;cores_stat=32  ;nodes=1 ;; 
 1024002)cores_model=128 ;nodes_model=1 ;cores=32  ;cores_stat=32  ;nodes=1 ;;     
  655362)cores_model=48  ;nodes_model=1 ;cores=48  ;cores_stat=32  ;nodes=1 ;; 
  256002)cores_model=20  ;nodes_model=1 ;cores=20  ;cores_stat=32  ;nodes=1 ;; 
  163842)cores_model=16  ;nodes_model=1 ;cores=16  ;cores_stat=32  ;nodes=1 ;; 
   40962)cores_model=128 ;nodes_model=1 ;cores=128 ;cores_stat=32  ;nodes=1 ;; 
   10242)cores_model=8   ;nodes_model=1 ;cores=8   ;cores_stat=32  ;nodes=1 ;; 
    4002)cores_model=6   ;nodes_model=1 ;cores=6   ;cores_stat=32  ;nodes=1 ;; 
    2562)cores_model=2   ;nodes_model=1 ;cores=2   ;cores_stat=32  ;nodes=1 ;; 
esac

echo 

#
# Script
#

NNODES=${nnodes}
NTASKSPN=128
#(( NTASKS = NTASKSPN * NNODES ))
ln -sf ${MESH_DIR}/${AREA}.graph.info.part.${cores_stat}     .
JNAME=invariantdata
QUEUE=PESQ1
cat > invariant.slurm <<EOF0
#!/bin/bash

#SBATCH --output=${INVDIR}/logs/log.invariant
#SBATCH --nodes=${NNODES}
#SBATCH --ntasks-per-node=${NTASKSPN}
#SBATCH --cpus-per-task=1
#SBATCH --ntasks=${cores_stat}
#SBATCH --exclusive
#SBATCH --time=01:00:00
#SBATCH --job-name=${JNAME}
#SBATCH --partition=${QUEUE}

export OMP_NUM_THREADS=1

ulimit -s unlimited
ulimit -c unlimited
ulimit -v unlimited

cd ${INVDIR}

echo  "STARTING AT \`date\` "
Start=\`date +%s.%N\`
echo \$Start >  ${INVDIR}/logs/Timing.invariant

date

time mpirun -np ${cores_stat} ${EXEDIR}/mpas_init_atmosphere &> ${INVDIR}/logs/log.invariant
wait

End=\`date +%s.%N\`
echo  "FINISHED AT \`date\` "
echo \$End   >> ${INVDIR}/logs/Timing.invariant
echo \$Start \$End | awk '{print \$2 - \$1" sec"}' >>  ${INVDIR}/logs/Timing.invariant

mv ${INVDIR}/log.init_atmosphere.* ${INVDIR}/logs

date
exit 0
EOF0

chmod +x invariant.slurm

sbatch --wait ./invariant.slurm

#EOC

