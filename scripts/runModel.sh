#!/bin/bash
#-----------------------------------------------------------------------------#
#BOP
#
# !SCRIPT: runModel
#
# !DESCRIPTION:
#   Script para rodar o MPAS regional utilizando os dados do GFS.
#
#   O script executa as seguintes etapas:
#     - Verifica a existência da condição inicial (${AREA}.init.nc);
#     - Cria a estrutura de diretórios da rodada e organiza os arquivos de entrada;
#     - Copia os arquivos de condição inicial e o ${AREA}.invariant.nc;
#     - Define os parâmetros da integração de acordo com a resolução da malha;
#     - Gera os arquivos namelist.atmosphere e streams.atmosphere a partir
#       dos templates do experimento;
#     - Cria o script de submissão SLURM para execução do
#       mpas_atmosphere;
#     - Executa o modelo atmosférico, utilizando as condições iniciais
#       provenientes do init_atmosphere ou da assimilação;
#     - Organiza os produtos gerados (históricos, diagnósticos e logs)
#       ao término da simulação.
#
# !CALLING SEQUENCE:
#   ./runModel.sh <EXP> <RES> <AREA> <LABELI> <LABELF> 
#
#     o EXP     : Nome do experimento (ex.: EXP1)
#     o RES     : Resolução do experimento (ex.: 163842 para 60 km)
#     o AREA    : Nome da área (ex.: SaoPaulo)
#     o LABELI  : Data inicial no formato YYYYMMDDHH
#     o LABELF  : Data final   no formato YYYYMMDDHH
#     o FCST    : Tempo de previsao, em horas (ex. 24 [horas])
#     o FROMDA  : Se condição inicial vem do Init = 0, se vem da 
#                         assimilação de dados = 1
#
# !EXAMPLE:
#   ./runModel.sh EXP1 163842 SaoPaulo 2025010100 2025010200 96 0 0
#
# !REVISION HISTORY:
#   - Adaptado por Amanda.
#   - Última atualização: 3 Ago 2026
#
# !REMARKS:
#   - Espera encontrar as tables em ${MODELDIR};
#   - Requer o arquivo ${AREA}.init.nc em ${MODELDIR};
#   - Requer o executável na pasta, assim como as lbcs.
#
#EOP
#-----------------------------------------------------------------------------#
#BOC

function usage(){
   sed -n '/^#BOP/,/^#EOP/{/^#BOP/d;/^#EOP/d;p}' ${BASH_SOURCE}
}

function diffdate(){

 di=${1}
 df=${2}

 si=$(date --date "${di:0:8} ${di:8:2}:${di:10:2}:${di:12:2}" +%s)
 sf=$(date --date "${df:0:8} ${df:8:2}:${df:10:2}:${df:12:2}" +%s)

 (( dddias =     (  sf - si )/86400 ))
 (( ddhoras =    ( (sf - si ) - dddias*86400 )/3600))
 (( ddminutos =  ( (sf - si ) - dddias*86400 - ddhoras*3600 )/60 ))
 (( ddsegundos = (  sf - si ) - dddias*86400 - ddhoras*3600 - ddminutos*60 ))

 dddias=$(printf "%0*d" 2 $dddias)
 ddhoras=$(printf "%0*d" 2 $ddhoras)
 ddminutos=$(printf "%0*d" 2 $ddminutos)
 ddsegundos=$(printf "%0*d" 2 $ddsegundos)
 
}

if [ $# -ne 7 ]; then
   usage
   exit 1
fi

#
# Argumentos
#

EXP=${1}
RES=${2}
AREA=${3}
LABELI=${4}; start_date=${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}_${LABELI:8:2}:00:00
LABELF=${5}; end_date=${LABELF:0:4}-${LABELF:4:2}-${LABELF:6:2}_${LABELF:8:2}:00:00

echo ${LABELF}

FCST=${6}
FROMDA=${7}

#
if [ ${FROMDA} -eq 1 ]; then FROMCICL="true" ; else FROMCICL="false" ; fi

#
# Caminhos
#

BASEDIR=${HOMEBE}/mpas_jedi_reg
MESHES=${BASEDIR}/pre/meshes
MESH_DIR=${BASEDIR}/pre/meshes/${AREA}
GFSDIR=${BASEDIR}/gfsdata
SSTDIR=${BASEDIR}/sstdata
EXEDIR=${BASEDIR}/bin
PRERUNDIR=${BASEDIR}/pre/run
TBLDIR=${BASEDIR}/pre/tables
NMLDIR=${BASEDIR}/namelist
RUNDIR=${BASEDIR}/run
EXPDIR=${RUNDIR}/${EXP}
STATICDIR=${RUNDIR}/${EXP}/static
GEODATA=${BASEDIR}/pre/databcs/WPS_GEOG
RUNINIT=${RUNDIR}/${EXP}/runinit/${LABELI:0:4}${LABELI:4:2}${LABELI:6:2}${LABELI:8:2}

BNDDIR=${RUNINIT}/${AREA}.init.nc

echo $BNDDIR

if [ ! -f ${BNDDIR} ]; then
     echo "Condicao de contorno inexistente!"
     echo "Verifique a data da rodada."
     echo "$0 ${LABELI}"
     exit 1                     # close for running only the model
fi

#

MODELDIR=${EXPDIR}/runmoc/${LABELI:0:4}${LABELI:4:2}${LABELI:6:2}${LABELI:8:2}
if [ ${FROMDA} -eq 1 ]; then
	MODELDIR=${RUNDIR}/${EXP}/runmod/${LABELI:0:4}${LABELI:4:2}${LABELI:6:2}${LABELI:8:2}
fi

#
# Criando diretórios da rodada
#

if [ ! -e ${MODELDIR} ]; then
   mkdir -p ${MODELDIR}
   mkdir -p ${MODELDIR}/logs
   mkdir -p ${MODELDIR}/mpasprd
   cp -u ${RUNINIT}/${AREA}.init.nc               ${MODELDIR}
   cp -u ${EXPDIR}/invariant/${AREA}.invariant.nc ${MODELDIR} 
else
   mkdir -p ${MODELDIR}/logs
   mkdir -p ${MODELDIR}/mpasprd
   cp -u ${RUNINIT}/${AREA}.init.nc               ${MODELDIR}
   cp -u ${EXPDIR}/invariant/${AREA}.invariant.nc ${MODELDIR}
fi

#

if [ $FROMDA -eq 1 ]; then
  inputfile=mpasin.${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}T${LABELI:8:2}.00.00.nc
 else
  inputfile=${AREA}.init.nc
fi

# 

case "`echo ${RES} | gawk '{print $1/1 }'`" in
65536002)dt_step=12  ;RES_KM='003_km';frac=1;len_disp=3000   ;;
 2621442)dt_step=90  ;RES_KM='015_km';frac=1;len_disp=15000  ;; 
 1024002)dt_step=150 ;RES_KM='024_km';frac=1;len_disp=24000  ;; 
  655362)dt_step=240 ;RES_KM='030_km';frac=1;len_disp=30000  ;; 
  256002)dt_step=300 ;RES_KM='048_km';frac=1;len_disp=48000  ;; 
  163842)dt_step=360 ;RES_KM='060_km';frac=1;len_disp=60000  ;; 
   40962)dt_step=300 ;RES_KM='120_km';frac=1;len_disp=120000 ;; 
   10242)dt_step=900 ;RES_KM='240_km';frac=1;len_disp=240000 ;; 
    4002)dt_step=1800;RES_KM='384_km';frac=1;len_disp=384000 ;; 
    2562)dt_step=1800;RES_KM='480_km';frac=1;len_disp=480000 ;; 
esac

# Os tamanhos dos intervalos de tempo geralmente
# recebem o valor de 6x do espaçamento da grade em km.

echo

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


#

cd ${MODELDIR}
ln -sf ${TBLDIR}/* .

#

LABELF=$(date --date "${LABELI:0:8} ${LABELI:8:4} ${FCST} hours" +%Y%m%d%H%M%S)
diffdate $LABELI'0000' $LABELF 
run_duration=${dddias}_${ddhoras}:${ddminutos}:${ddsegundos}

#
# Namelist
#

sed -e "s,#LEN_DISP#,${len_disp},g; s,#LABELI#,${start_date},g;s,#LABELF#,${end_date},g;s,#STEPMODEL#,${dt_step},g;s,#AREA#,${AREA},g; s,#RUN_DURATION#,${run_duration},g;s,#FROMCICL#,${FROMCICL},g" \
         ${NMLDIR}/namelist.atmosphere.MODEL.${EXP} > ${MODELDIR}/namelist.atmosphere

sed -e "s,#INPUTFILE#,${inputfile},g;s,#AREA#,${AREA},g" \
	 ${NMLDIR}/streams.atmosphere.MODEL.${EXP} > ${MODELDIR}/streams.atmosphere

echo "${inputfile}"
cp -u ${NMLDIR}/stream_list.atmosphere.* .

#
# Script
#

cd ${MODELDIR}

NNODES=1
NTASKSPN=32
(( NTASKS = NTASKSPN * NNODES ))
ln -sf ${MESH_DIR}/${AREA}.graph.info.part.${NTASKS}     ${MODELDIR}
JNAME=mpas_exe
QUEUE=PESQ1

#NNODES=${nodes_model}
#NTASKSPN=${cores_model}
#(( NTASKS = NTASKSPN * NNODES ))
#ln -sf ${MESHES}/${AREA}.graph.info.part.${cores_model}     ${MODELDIR}
#JNAME=mpas_exe
#QUEUE=PESQ1

cat > ${MODELDIR}/model.slurm <<EOF0
#!/bin/bash
#SBATCH --nodes=${NNODES}
#SBATCH --ntasks=${NTASKS}
#SBATCH --ntasks-per-node=${NTASKSPN}
#SBATCH --partition=${QUEUE}
#SBATCH --job-name=${JNAME}
#SBATCH --time=12:00:00       
#SBATCH --output=${MODELDIR}/logs/log.model  

export executable=${EXEDIR}/mpas_atmosphere
cp -u ${EXEDIR}/mpas_atmosphere ${MODELDIR}

# generic
ulimit -c unlimited
ulimit -v unlimited
ulimit -s unlimited

cd ${MODELDIR}
ln -fs ${RUNINIT}/lbc.*.nc              ${MODELDIR}          

if [ $FROMDA -eq 1 ]; then
  cp $(dirname ${EXPDIR})/runda/an.${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}T${LABELI:8:2}.00.00.nc   ${MODELDIR}/mpasin.${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}T${LABELI:8:2}.00.00.nc
  cp ${EXPDIR}/invariant/${AREA}.invariant.nc                                                ${MODELDIR}  
  inputfile=mpasin.${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}T${LABELI:8:2}.00.00.nc
 else
  cp $(dirname ${RUNINIT})/${AREA}.init.nc                                                   ${MODELDIR}
  cp ${EXPDIR}/invariant/${AREA}.invariant.nc                                                ${MODELDIR}
  inputfile=${AREA}.init.nc
fi
                          

echo  "STARTING AT \`date\` "
Start=\`date +%s.%N\`
echo \$Start >  ${MODELDIR}/logs/Timing.model

date

export LD_LIBRARY_PATH="/home/amanda.queiroz/jedi-bundle/build-jedi/lib:$LD_LIBRARY_PATH"

time mpirun -np ${NTASKS} ${EXEDIR}/mpas_atmosphere &> ${MODELDIR}/logs/log.model
wait

End=\`date +%s.%N\`
echo  "FINISHED AT \`date\` "
echo \$End   >> ${MODELDIR}/logs/Timing.model
echo \$Start \$End | awk '{print \$2 - \$1" sec"}' >>  ${MODELDIR}/logs/Timing.model

date

if test -s log.atmosphere.0000.out; then errorcode=\$(cat log.atmosphere.0000.out | tail -4 | head -1 | awk '{print \$4}'); fi

if [ \$errorcode -eq 0 ]; then
 echo "Model Run Successfully"
 mv diag.*.nc history.*.nc mpasprd
 mv log.atmosphere.0000.out logs
 #mv model.slurm scripts
 #rm x1.10242.init.nc x1.10242.sfc_update.nc x1.10242.invariant.nc
else
 echo ">>>>> Error in Model Run <<<<<"
 
fi

exit 0
EOF0

chmod +x model.slurm

if [ 'x'$pid == 'x' ]; then
  sbatch ./model.slurm
 else
  sbatch --dependency=afterok:${pid} ./model.slurm
fi

#EOC

