#!/bin/bash
#-----------------------------------------------------------------------------#
#BOP
#
# !SCRIPT: runStatic
#
# !DESCRIPTION:
#   Script para geração do arquivo estático (static.nc) do MPAS regional.
#   O script prepara o ambiente, configura os parâmetros necessários
#   e executa o mpas_init_atmosphere para criar o arquivo estático
#   correspondente à área e resolução especificadas.
#
#   Essa etapa é responsável apenas pela geração do domínio estático,
#   não realizando processamento de dados GRIB nem execução do ungrib.
#
# !CALLING SEQUENCE:
#   ./runStatic.sh <EXP> <RES> <AREA>
#
#     o EXP    : Nome do experimento (ex.: EXP1)
#     o LABELI : Data inicial no formato YYYYMMDDHH
#     o LABELF : Data final   no formato YYYYMMDDHH
#     o AREA   : Nome da área/região (ex.: SaoPaulo)
#     o RES    : Resolução do MPAS
#
# !EXAMPLE:
#   ./runStatic.sh EXP1 163842 SaoPaulo
#
# !REVISION HISTORY:
#   - Adaptado por Amanda para rodar o mpas_init_atmosphere 
#     e gerar o arquivo estático regional (static.nc).
#   - Última modificação 12 Mai 2026
#
#
#EOP
#-----------------------------------------------------------------------------#
#BOC

function usage(){
   sed -n '/^#BOP/,/^#EOP/{/^#BOP/d;/^#EOP/d;p}' ${BASH_SOURCE}
}

if [ $# -ne 3 ]; then
   usage
   exit 1
fi

#
# Argumentos
#

EXP=${1}
RES=${2}
AREA=${3}

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
STATICDIR=${RUNDIR}/${EXP}/static

if [ ! -d ${STATICDIR} ]; then
  mkdir -p ${STATICDIR}/logs
fi

#

cd ${STATICDIR}

ln -sf ${TBLDIR}/* .
ln -s ${MESH_DIR}/${AREA}.grid.nc .

cp -f ${EXEDIR}/mpas_init_atmosphere .

#
# Namelist
#

sed -e "s,#GEODAT#,${GEODATA},g;s,#RES#,${RES},g;s,#AREA#,${AREA},g" \
	${NMLDIR}/namelist.init_atmosphere.STATIC.${EXP} \
       > ${STATICDIR}/namelist.init_atmosphere

sed -e "s,#RES#,${RES},g;s,#AREA#,${AREA},g" \
       	${NMLDIR}/streams.init_atmosphere.STATIC.${EXP} \
	> ${STATICDIR}/streams.init_atmosphere

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

NNODES=1
NTASKSPN=${cores_stat}
(( NTASKS = NTASKSPN * NNODES ))
ln -sf ${MESH_DIR}/${AREA}.graph.info.part.${NTASKS}     .
JNAME=staticdata
QUEUE=PESQ1
cat > static.slurm <<EOF0
#!/bin/bash

#SBATCH --output=${STATICDIR}/logs/log.static
#SBATCH --nodes=${NNODES}
#SBATCH --ntasks-per-node=${NTASKSPN}
#SBATCH --cpus-per-task=1
#SBATCH --ntasks=${NTASKS}
#SBATCH --exclusive
#SBATCH --time=01:00:00
#SBATCH --job-name=${JNAME}
#SBATCH --partition=${QUEUE}

export OMP_NUM_THREADS=1

ulimit -s unlimited
ulimit -c unlimited
ulimit -v unlimited

cd ${STATICDIR}

echo  "STARTING AT \`date\` "
Start=\`date +%s.%N\`
echo \$Start >  ${STATICDIR}/logs/Timing.static

date

time mpirun -np ${NTASKS} ${EXEDIR}/mpas_init_atmosphere &> ${STATICDIR}/logs/log.static
wait

End=\`date +%s.%N\`
echo  "FINISHED AT \`date\` "
echo \$End   >> ${STATICDIR}/logs/Timing.static
echo \$Start \$End | awk '{print \$2 - \$1" sec"}' >>  ${STATICDIR}/logs/Timing.static

mv ${STATICDIR}/log.init_atmosphere.* ${STATICDIR}/logs

date
exit 0
EOF0

chmod +x static.slurm

sbatch --wait ./static.slurm

#EOC
