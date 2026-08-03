#!/bin/bash
#-----------------------------------------------------------------------------#
#BOP
#
# !SCRIPT: runDA
#
# !DESCRIPTION:
#   Script para assimilação dos dados do MPAS-JEDI regional.
#
#   O script executa as seguintes etapas:
#     - Cria e organiza o diretório de execução da assimilação de dados;
#     - Define os parâmetros do experimento e calcula datas, duração da integração
#       e janela de assimilação;
#     - Configura os arquivos namelist, streams e o arquivo de configuração
#       da assimilação (3dvar.yaml) a partir de templates;
#     - Cria links simbólicos para tabelas, arquivos estáticos, condições
#       iniciais, condições de contorno, matriz B, malha particionada e
#       dados observados;
#     - Copia para o diretório de execução os arquivos necessários, incluindo
#       o executável mpasjedi_variational.x;
#     - Gera automaticamente o script de submissão (jedi.slurm), configurando
#       os recursos computacionais e o ambiente de execução;
#     - Submete a assimilação via SLURM, utilizando execução paralela via MPI;
#     - Registra os tempos de execução, organiza os arquivos de saída e verifica
#       se a assimilação foi concluída com sucesso.

# !CALLING SEQUENCE:
#   ./runDA.sh <EXP> <RES> <AREA> <LABELI> <LABELF> <NHCIC> <FCST> <FROMCIC> <WINDOW>
# 
#
#     o EXP     : Nome do experimento (ex.: EXP1)
#     o RES     : Resolução do experimento (ex.: 163842 para 60 km)
#     o AREA    : Nome da área (ex.: SaoPaulo)
#     o LABELI  : Data inicial no formato YYYYMMDDHH
#     o LABELF  : Data final   no formato YYYYMMDDHH
#     o NHCIC   : Número de horas do ciclo (ex. 6 [horas])
#     o FCST    : Tempo de previsao, em horas (ex. 24 [horas])
#     o FROMCIC : O Background vem do ciclo: sim: 1; não: 0
#     o WINDOW  : Janela de assimilação (ex. 180 [minutos])
#
# !EXAMPLE:
#   ./runDA.sh EXP1 163842 SaoPaulo 2026051500 2026052000 6 96 0 180
#
# !REVISION HISTORY:
#   - Adaptado por Amanda.
#   - Última atualização: 3 Ago 2026
# 
# !REMARKS:
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

if [ $# -ne 9 ]; then
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
NHCIC=${6}
FCST=${7}
FROMCIC=${8}
WINDOW=${9}

#

echo ${LABELF}

if [ ${FROMCIC} -eq 1 ]; then FROMCICL="true" ; else FROMCICL="false" ; fi

radaronly="F"

LABELIprev=`date -d "${LABELI:0:8} ${LABELI:8:2} ${NHCIC} hours ago" '+%Y%m%d%H'`

export LD_LIBRARY_PATH=$NETCDF/lib:$HDF5/lib:$GRIB2/lib:$LD_LIBRARY_PATH

BASEDIR=${HOMEBE}/mpas_jedi_reg
RUNDIR=${BASEDIR}/run
EXEDIR=${BASEDIR}/bin
TBLDIR=${BASEDIR}/pre/tables
NMLDIR=${BASEDIR}/namelist
OBSDIR=${BASEDIR}/obsdata
BEMDIR=${BASEDIR}/bedata
EXPDIR=${RUNDIR}/${EXP}
MESH_DIR=${BASEDIR}/pre/meshes/${AREA}
RUNINIT=${EXPDIR}/runinit

DADIR=${EXPDIR}/runda

if [ ! -e ${RUNDIR}/${EXP} ]; then
 mkdir -p ${RUNDIR}/${EXP}/{runmoc/logs,runmod/logs}
fi

if [ -e ${DADIR} ]; then
  rm -rf ${DADIR}
  mkdir -p ${DADIR}/logs
 else
  mkdir -p ${DADIR}/logs
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

#
cd ${DADIR}

start_date=${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}_${LABELI:8:2}:00:00
LABELF=$(date --date "${LABELI:0:8} ${LABELI:8:4} ${FCST} hours" +%Y%m%d%H%M%S)
diffdate $LABELI'0000' $LABELF 
run_duration=${dddias}_${ddhoras}:${ddminutos}:${ddsegundos}

end_date=${LABELF:0:4}-${LABELF:4:2}-${LABELF:6:2}_${LABELF:8:2}:00:00

ANADATE=$(date    --date "${LABELI:0:8} ${LABELI:8:4}         0 minutes     " +%Y-%m-%dT%H:%M:00)
ANADATEp=$(date    --date "${LABELI:0:8} ${LABELI:8:4}        0 minutes     " +%Y-%m-%dT%H.%M.00)
WINDATE=$(date --date "${LABELI:0:8} ${LABELI:8:4} $WINDOW   minutes ago    " +%Y-%m-%dT%H:%M:00)

ln -fs ${TBLDIR}/*                                 ${DADIR}
ln -fs ${NMLDIR}/stream_list.atmosphere.analysis   ${DADIR}
ln -fs ${NMLDIR}/stream_list.atmosphere.background ${DADIR}
ln -fs ${NMLDIR}/stream_list.atmosphere.control    ${DADIR}
ln -fs ${NMLDIR}/stream_list.atmosphere.ensemble   ${DADIR}
ln -fs ${BEMDIR}/B_Matrix_${EXP}                   ${DADIR}/B_Matrix

sed -e "s,#LEN_DISP#,${len_disp},g; s,#LABELI#,${start_date},g;s,#LABELF#,${end_date},g;s,#STEPMODEL#,${dt_step},g;s,#AREA#,${AREA},g; s,#RUN_DURATION#,${run_duration},g;s,#FROMCICL#,${FROMCICL},g" \
         ${NMLDIR}/namelist.atmosphere.TEMPLATE.${EXP} > ${DADIR}/namelist.atmosphere

inputfile=mpasin.${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}T${LABELI:8:2}.00.00.nc   

sed -e "s,#AREA#,${AREA},g; \
        s,#INPUTFILE#,${inputfile},g; \
        /stream_list.atmosphere.output/d; \
        /stream_list.atmosphere.diagnostics/d" \
    ${NMLDIR}/streams.atmosphere.TEMPLATE.${EXP} > ${DADIR}/streams.atmosphere

echo "${inputfile}"

if [ $radaronly == "T" ]; then
  ln -fs ${OBSDIR}/${LABELI}/obs_radar_mrms_${LABELI}00.h5  ${DADIR}/obs_radar_mrms_${ANADATE}00.h5
 else
  ln -fs ${OBSDIR}/${LABELI}/aircraft_obs_${LABELI}.h5       ${DADIR}/aircraft_obs_${ANADATE}.h5
  ln -fs ${OBSDIR}/${LABELI}/gnssro_obs_${LABELI}.h5         ${DADIR}/gnssro_obs_${ANADATE}.h5 
  ln -fs ${OBSDIR}/${LABELI}/satwind_obs_${LABELI}.h5        ${DADIR}/satwind_obs_${ANADATE}.h5
  ln -fs ${OBSDIR}/${LABELI}/sfc_obs_${LABELI}.h5            ${DADIR}/sfc_obs_${ANADATE}.h5
  ln -fs ${OBSDIR}/${LABELI}/sondes_obs_${LABELI}.h5         ${DADIR}/sondes_obs_${ANADATE}.h5 
  #ln -fs ${OBSDIR}/${LABELI}/amsua_n19_obs_${LABELI}.h5      ${EXPDIR}/amsua_n19_obs_${ANADATE}.h5
  #ln -fs ${OBSDIR}/${LABELI}/obs_radar_cptec_${LABELI}00.h5  ${EXPDIR}/obs_radar_cptec_${ANADATE}00.h5
fi

cp -u ${NMLDIR}/obsop_name_map.yaml       ${DADIR}

ln -fs ${NMLDIR}/geovars.yaml          ${DADIR}
ln -fs ${NMLDIR}/keptvars.yaml         ${DADIR}
ln -fs ${NMLDIR}/obsop_name_map.yaml   ${DADIR}
ln -fs ${BASEDIR}/crtm3 ${DADIR}

cp -u ${RUNINIT}/lbc.*.nc                  ${DADIR}
cp -u ${RUNINIT}/${AREA}.init.nc           ${DADIR}
cp -u ${EXPDIR}/invariant/${AREA}.invariant.nc ${DADIR}

if [ $radaronly == "T" ]; then
  sed -e "s,#WINDATE#,${WINDATE},g; \
          s,#ANADATE#,${ANADATE},g; \
          s,#ANADATEp#,${ANADATEp},g" \
        ${NMLDIR}/3dvar_radar.yaml > ${DADIR}/3dvar.yaml
else
  sed -e "s,#WINDATE#,${WINDATE},g; \
          s,#ANADATE#,${ANADATE},g; \
          s,#ANADATEp#,${ANADATEp},g" \
        ${NMLDIR}/3dvar.yaml > ${DADIR}/3dvar.yaml
fi

cp ${EXEDIR}/mpasjedi_variational.x  ${DADIR}

NNODES=2
NTASKSPN=128
(( NTASKS = NTASKSPN * NNODES ))
ln -sf ${MESH_DIR}/${AREA}.graph.info.part.${NTASKS}     ${DADIR}
JNAME=model_JEDI
QUEUE=PESQ1

cat > jedi.slurm <<EOF0
#!/bin/bash

#SBATCH --output=${DADIR}/logs/log.jedi
#SBATCH --nodes=${NNODES}
#SBATCH --ntasks-per-node=${NTASKSPN}
#SBATCH --cpus-per-task=1
#SBATCH --ntasks=${NTASKS}
#SBATCH --mem=480G
#SBATCH --exclusive
#SBATCH --time=02:30:00
#SBATCH --job-name=${JNAME}
#SBATCH --partition=${QUEUE}

export OMP_NUM_THREADS=1

ulimit -s unlimited
export GFORTRAN_CONVERT_UNIT='big_endian:101-200'

cd ${DADIR}

if [ $FROMCIC -eq 1 ]; then
  ln -fs ${RUNDIR}/${EXP}/${LABELIprev:0:10}/runmod/mpasout.${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}T${LABELI:8:2}.00.00.nc ${EXPDIR}/bg.${ANADATEp}.nc
  cp     ${RUNDIR}/${EXP}/${LABELIprev:0:10}/runmod/mpasout.${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}T${LABELI:8:2}.00.00.nc ${EXPDIR}/an.${ANADATEp}.nc
  ln -fs ${RUNDIR}/${EXP}/${LABELIprev:0:10}/runmod/mpasout.${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}T${LABELI:8:2}.00.00.nc ${EXPDIR}/${inputfile}

 else
  ln -fs ${RUNDIR}/${EXP}/runmoc/mpasout.${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}T${LABELI:8:2}.00.00.nc ${DADIR}/bg.${ANADATEp}.nc
  cp     ${RUNDIR}/${EXP}/runmoc/mpasout.${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}T${LABELI:8:2}.00.00.nc ${DADIR}/an.${ANADATEp}.nc
  ln -fs ${RUNDIR}/${EXP}/runmoc/mpasout.${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}T${LABELI:8:2}.00.00.nc ${DADIR}/${inputfile}
fi

echo  "STARTING AT \`date\` "
Start=\`date +%s.%N\`
echo \$Start >  ${DADIR}/logs/Timing.jedi

date

export LD_LIBRARY_PATH="/home/amanda.queiroz/jedi-bundle/build-jedi/lib:$LD_LIBRARY_PATH"

time mpirun -np ${NTASKS} ${DADIR}/mpasjedi_variational.x 3dvar.yaml ${DADIR}/3dvar.log &> ${DADIR}/logs/log.jedi
wait

End=\`date +%s.%N\`
echo  "FINISHED AT \`date\` "
echo \$End   >> ${DADIR}/logs/Timing.jedi
echo \$Start \$End | awk '{print \$2 - \$1" sec"}' >>  ${DADIR}/logs/Timing.jedi

date

if test -s 3dvar.log ; then errorcode=\$(cat 3dvar.log | tail -2 | head -1 | awk '{print \$11}') ; fi

echo "ERRORCODE: \$errorcode"

if [ 'x'\$errorcode == x0 ]; then
 echo "Data Assimilation Run Successfully"
 mkdir 3dvarlog
 mv 3dvar.log* 3dvarlog
 mkdir geovalout
 mv geoval_out_*nc geovalout
 else
 echo ">>>>> Error in Data Assimilation <<<<<"
fi

exit 0
EOF0

chmod +x jedi.slurm

if [ 'x'$pid == 'x' ]; then
  sbatch ./jedi.slurm
 else
  sbatch --dependency=afterok:${pid} ./jedi.slurm
fi

#EOC
