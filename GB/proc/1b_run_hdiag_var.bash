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
#        ./1b_run_hdiag_var.bash ${EXPDIR}/proc ${NMLDIR} ${TBLDIR} ${EXEDIR} ${WRFBIN} ${LABELI} ${LABELF} ${EXP} ${RES} ${NNODES} ${NTASKSPN} ${AREA} ${MESH_DIR}
#
#           o EXPDIR=${RUNDIR}/${EXP}/GB
#           o NMLDIR=${BASEDIR}/namelist
#           o TBLDIR=${BASEDIR}/pre/tables
#           o EXEDIR=${BASEDIR}/bin
#           o WRFBIN=${BASEDIR}/GB/prep
#           o LABELI    : Data inicial no formato YYYYMMDDHH
#           o LABELF    : Data final   no formato YYYYMMDDHH
#           o EXP       : Nome do experimento (ex.: EXP1)
#           o RES       : Resolução do experimento (ex.: 163842 para 60 km)
#           o NNODES    : Número de nós computacionais utilizados na execução (ex.: 1)
#           o NTASKSPN  : Número de tarefas MPI por nó (ou seja, total de cores por nó, como, por ex.: 64 ou 128)
#           o AREA      : Nome da área (ex.: SaoPaulo)
#           o MESH_DIR=${BASEDIR}/pre/meshes/${AREA}
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

function usage(){
   sed -n '/^#BOP/,/^#EOP/{/^#BOP/d;/^#EOP/d;p}' ${BASH_SOURCE}
}

if [ $# -ne 13 ]; then
   usage
   exit 1
fi

RUNDIR=${1}
NMLDIR=${2}
TBLDIR=${3}
EXEDIR=${4}
WRFBIN=${5}
LABELI=${6}
LABELF=${7}
EXP=${8}
RES=${9}
NNODES=${10}
NTASKSPN=${11}
AREA=${12}
MESH_DIR=${13}

hdiagVarDir=${RUNDIR}/HDIAG_VAR                   # working Dir
samplesDir=${RUNDIR}/samples                      # input Dir

workdir=${hdiagVarDir}/vargroup2

mkdir -p ${workdir}
cd ${workdir}

start_date=${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}_${LABELI:8:2}:00:00
start_dateT=${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}T${LABELI:8:2}:00:00
start_dateP=${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}T${LABELI:8:2}.00.00

diffdate $LABELI'0000' $LABELF'0000' 
run_duration=${dddias}_${ddhoras}:${ddminutos}:${ddsegundos}

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

FROMCICL=.false.

inputfile=templateFields.${AREA}.nc
sed -e "s,#AREA#,${AREA},g; \
        s,#INPUTFILE#,${inputfile},g" \
    ${NMLDIR}/streams.atmosphere.MODEL.${EXP} >                                                         ${workdir}/streams.atmosphere
sed -e "s,#STEPMODEL#,${dt_step},g; \
	s,#LEN_DISP#,${len_disp},g; \
        s,#RUN_DURATION#,${run_duration},g; \
        s,#AREA#,${AREA},g; \
	s,#FROMCICL#,${FROMCICL},g; \
        s,#LABELI#,${start_date},g" \
    ${NMLDIR}/namelist.atmosphere.MODEL.${EXP} >                                                         ${workdir}/namelist.atmosphere

ln -sf $(dirname $(dirname ${RUNDIR}))/invariant/${AREA}.invariant.nc                       ${workdir}/${AREA}.invariant.nc
ln -sf $(dirname $(dirname ${RUNDIR}))/runmoc/${LABELI:0:10}/mpasout.${start_dateP}.nc      ${workdir}/bg.${start_dateP}.nc
ln -sf $(dirname $(dirname ${RUNDIR}))/runmoc/${LABELI:0:10}/mpasout.${start_dateP}.nc      ${workdir}/templateFields.${AREA}.nc

cat > run_hdiag_var.yaml << EOF
_member config: &memberConfig
  state variables: &vars
  - qc
  - qi
  - qr
  - qs
  - qg
  date: &date '${start_dateT}Z'
  stream name: control
  transform model to analysis: false
geometry:
  nml_file: "./namelist.atmosphere"
  streams_file: "./streams.atmosphere"
  bump vunit: "avgheight"
background:
  state variables: *vars
  filename: "./bg.${start_dateP}.nc"
  date: *date
  stream name: control
  transform model to analysis: false

background error:
  covariance model: SABER

  iterative ensemble loading: true

  ensemble:
    members from template:
      template:
        <<: *memberConfig
        filename: ${samplesDir}/PTB_f48mf24_%iMember%.nc
      pattern: %iMember%
      start: 1
      zero padding: 3
      nmembers: 9

  saber central block:
    saber block name: BUMP_NICAS
    calibration:
      io:
        files prefix: mpas
      drivers:
        compute covariance: true
        compute correlation: true
        multivariate strategy: univariate
        write global sampling: true
        compute variance: true
        compute moments: true
        write diagnostics: true
      sampling:
        computation grid size: 24000
        diagnostic grid size: 1000
        distance classes: 20
        distance class width: 200.0e3
        reduced levels: 10
        local diagnostic: true
        averaging length-scale: 3000.0e3
      variance:
        objective filtering: true
        filtering iterations: 1
        initial length-scale:
        - variables:
          - qc
          - qi
          - qr
          - qs
          - qg
          value: 3000.0e3
      fit:
        horizontal filtering length-scale: 3000.0e3

      output model files:
      - parameter: stddev
        file:
          filename: ./mpas.stddev.nc
          date: *date
          stream name: control
      - parameter: cor_rh
        file:
          filename: ./mpas.cor_rh.nc
          date: *date
          stream name: control
      - parameter: cor_rv
        file:
          filename: ./mpas.cor_rv.nc
          date: *date
          stream name: control
EOF

(( NTASKS = NTASKSPN * NNODES ))
ln -sf ${MESH_DIR}/${AREA}.graph.info.part.${NTASKS}     ${workdir}
JNAME=JEDI_HDIAG
QUEUE=PESQ1
cat > jedi_hdiag.bash <<EOF
#!/bin/bash

#SBATCH --nodes=${NNODES}
#SBATCH --ntasks-per-node=${NTASKSPN}
#SBATCH --cpus-per-task=1
#SBATCH --ntasks=${NTASKS}
#SBATCH --exclusive
#SBATCH --time=00:30:00
#SBATCH --job-name=${JNAME}
#SBATCH --partition=${QUEUE}

export OMP_NUM_THREADS=1

ulimit -s unlimited
export GFORTRAN_CONVERT_UNIT='big_endian:101-200'

ln -fs ${TBLDIR}/*           ${workdir}
ln -fs ${NMLDIR}/stream_list*          ${workdir}
ln -fs ${NMLDIR}/geovars.yaml          ${workdir}
ln -fs ${NMLDIR}/keptvars.yaml         ${workdir}

mpirun -np ${NTASKS} ${EXEDIR}/mpasjedi_error_covariance_toolbox.x  ./run_hdiag_var.yaml  ./run_hdiag_var.runlog

EOF

sbatch --wait jedi_hdiag.bash

#-----------------------------------------------------------------------------#
#EOC
