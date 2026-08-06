#!/bin/bash
#-----------------------------------------------------------------------------#
#BOP
#
# !SCRIPT: 2_run_nicas_split
#
# !DESCRIPTION:
#
# !CALLING SEQUENCE:
#     
#        ./2_run_nicas_split.bash ${EXPDIR}/proc ${NMLDIR} ${TBLDIR} ${EXEDIR} ${WRFBIN} ${LABELI} ${LABELF} ${EXP} ${RES} ${NNODES} ${NTASKSPN} ${AREA} ${MESH_DIR}
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

nicasDir=${RUNDIR}/NICAS.split
hdiagVarDir=${RUNDIR}/HDIAG_VAR
list_vars="uReconstructZonal uReconstructMeridional temperature spechum surface_pressure qc qi qr qs qg"

workdir=${nicasDir}

mkdir -p ${workdir}
cd ${workdir}

ln -fs ${hdiagVarDir}/merge/mpas.cor_rh.nc   ./
ln -fs ${hdiagVarDir}/merge/mpas.cor_rv.nc   ./

start_date=${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}_${LABELI:8:2}:00:00
start_dateT=${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}T${LABELI:8:2}:00:00
start_dateP=${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}T${LABELI:8:2}.00.00

diffdate $LABELI'0000' $LABELF'0000' 
run_duration=${dddias}_${ddhoras}:${ddminutos}:${ddsegundos}

#Run NICAS for each variable
for variable in ${list_vars}; do

echo "Processing for ${variable}"

mkdir -p ${variable}
cd ${variable}

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
    ${NMLDIR}/streams.atmosphere.MODEL.${EXP} >                                                  ${workdir}/${variable}/streams.atmosphere
sed -e "s,#STEPMODEL#,${dt_step},g; \
	s,#LEN_DISP#,${len_disp},g; \
        s,#RUN_DURATION#,${run_duration},g; \
        s,#AREA#,${AREA},g; \
	s,#FROMCICL#,${FROMCICL},g; \
        s,#LABELI#,${start_date},g" \
    ${NMLDIR}/namelist.atmosphere.MODEL.${EXP} >                                                         ${workdir}/${variable}/namelist.atmosphere

ln -sf $(dirname $(dirname ${RUNDIR}))/runinit/${LABELI:0:10}/${AREA}.init.nc             ${workdir}/${variable}/${AREA}.invariant.nc
ln -sf $(dirname $(dirname ${RUNDIR}))/runmoc/${LABELI:0:10}/mpasout.${start_dateP}.nc      ${workdir}/${variable}/bg.${start_dateP}.nc
ln -sf $(dirname $(dirname ${RUNDIR}))/runmoc/${LABELI:0:10}/mpasout.${start_dateP}.nc      ${workdir}/${variable}/templateFields.${AREA}.nc

#variable dependent yaml parameter
nc1max=200000 #default
if [ ${variable} == "qc" ] ||
   [ ${variable} == "qi" ] ||
   [ ${variable} == "qr" ] ||
   [ ${variable} == "qs" ] ||
   [ ${variable} == "qg" ]; then
   nc1max=500000
fi

#level of dirac function
if [ ${variable} == "surface_pressure" ]; then
   vert_level_dirac=1
else
   vert_level_dirac=36  # =55-20+1 : Inside BUMP, z is top-to-bottom
fi

cat > run_nicas.yaml << EOF
geometry:
  nml_file: "./namelist.atmosphere"
  streams_file: "./streams.atmosphere"
  deallocate non-da fields: true
  bump vunit: "avgheight"
background:
  state variables: &vars
  - ${variable}
  filename: "./bg.${start_dateP}.nc"
  date: &date '${start_dateT}Z'
  stream name: control
  transform model to analysis: false

background error:
  covariance model: SABER

  saber central block:
    saber block name: BUMP_NICAS

    calibration:
      io:
        files prefix: mpas
      drivers:
        multivariate strategy: univariate
        compute nicas: true
        write local nicas: true
        write global nicas: true
        write nicas grids: true
        internal dirac test: true
      nicas:
        resolution: 4
        max horizontal grid size: ${nc1max}
      dirac:
      - longitude: -45.0
        latitude: 0.0
        level: ${vert_level_dirac}
        variable: ${variable}
      - longitude: -135.0
        latitude: 0.0
        level: ${vert_level_dirac}
        variable: ${variable}
      - longitude: 45.0
        latitude: 0.0
        level: ${vert_level_dirac}
        variable: ${variable}
      - longitude: 135.0
        latitude: 0.0
        level: ${vert_level_dirac}
        variable: ${variable}
      - longitude: -135.0
        latitude: 45.0
        level: ${vert_level_dirac}
        variable: ${variable}
      - longitude: -45.0
        latitude: 45.0
        level: ${vert_level_dirac}
        variable: ${variable}
      - longitude: 45.0
        latitude: 45.0
        level: ${vert_level_dirac}
        variable: ${variable}
      - longitude: 135.0
        latitude: 45.0
        level: ${vert_level_dirac}
        variable: ${variable}
      - longitude: -135.0
        latitude: -45.0
        level: ${vert_level_dirac}
        variable: ${variable}
      - longitude: -45.0
        latitude: -45.0
        level: ${vert_level_dirac}
        variable: ${variable}
      - longitude: 45.0
        latitude: -45.0
        level: ${vert_level_dirac}
        variable: ${variable}
      - longitude: 135.0
        latitude: -45.0
        level: ${vert_level_dirac}
        variable: ${variable}

      input model files:
      - parameter: rh
        file:
          filename: ../mpas.cor_rh.nc
          date: *date
          stream name: control
      - parameter: rv
        file:
          filename: ../mpas.cor_rv.nc
          date: *date
          stream name: control

      output model files:
      - parameter: nicas_norm
        file:
          filename: ./mpas.nicas_norm.nc
          date: *date
          stream name: control
      - parameter: dirac_nicas
        file:
          filename: ./mpas.dirac_nicas.nc
          date: *date
          stream name: control
EOF

(( NTASKS = NTASKSPN * NNODES ))
ln -sf ${MESH_DIR}/${AREA}.graph.info.part.${NTASKS}     ${workdir}/${variable}
JNAME=JEDI_NICAS
QUEUE=PESQ1
cat > jedi_nicas.bash <<EOF
#!/bin/bash

#SBATCH --nodes=${NNODES}
#SBATCH --ntasks-per-node=${NTASKSPN}
#SBATCH --cpus-per-task=1
#SBATCH --ntasks=${NTASKS}
#SBATCH --exclusive
#SBATCH --time=04:00:00
#SBATCH --job-name=${JNAME}
#SBATCH --partition=${QUEUE}

export OMP_NUM_THREADS=1

ulimit -s unlimited
export GFORTRAN_CONVERT_UNIT='big_endian:101-200'

ln -fs ${TBLDIR}/*                     ${workdir}/${variable}
ln -fs ${NMLDIR}/stream_list*          ${workdir}/${variable}
ln -fs ${NMLDIR}/geovars.yaml          ${workdir}/${variable}
ln -fs ${NMLDIR}/keptvars.yaml         ${workdir}/${variable}

mpirun -np ${NTASKS} ${EXEDIR}/mpasjedi_error_covariance_toolbox.x ./run_nicas.yaml  ./run_nicas.runlog

EOF

sbatch --wait jedi_nicas.bash

cd ..

done

#-----------------------------------------------------------------------------#
#EOC
