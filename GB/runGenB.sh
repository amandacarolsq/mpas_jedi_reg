#!/bin/bash
#-----------------------------------------------------------------------------#
#BOP
#
# !SCRIPT: runGenB.sh
#
# !DESCRIPTION:
#
#   Script para geração da matriz de covariância de erro de background (B)
#   utilizando o BUMP/JEDI. O fluxo é dividido em etapas de pré-processamento
#   e processamento, permitindo executar apenas etapas específicas por meio
#   do argumento STEPS.
#
# !CALLING SEQUENCE:
#   ./runGenB.sh <EXP> <RES> <AREA> <LABELI> <LABELF> <NNODES> <NTASKSPN> <STEPS>
#
#           o EXP       : Nome do experimento (ex.: EXP1)
#           o RES       : Resolução da malha MPAS
#                         (ex.: 163842 para aproximadamente 60 km)
#           o AREA      : Nome da área (ex.: SaoPaulo)
#           o LABELI    : Data inicial no formato YYYYMMDDHH
#           o LABELF    : Data final no formato YYYYMMDDHH
#           o NNODES    : Número de nós computacionais
#           o NTASKSPN  : Número de tarefas MPI por nó
#                         (ex.: 64 ou 128)
#           o STEPS     : Lista das etapas a serem executadas,
#                         separadas por vírgula.
#
#                         Etapas disponíveis:
#
#                           prep1 - Geração do arquivo template
#                           prep2 - Inclusão das variáveis
#                           prep3 - Cálculo das diferenças (ncdiff)
#
#                           0     - Criação dos links para as amostras
#                           1a    - Execução do HDIAG_VAR (parte A)
#                           1b    - Execução do HDIAG_VAR (parte B)
#                           1c    - Modificação dos diagnósticos
#                           2     - Execução do NICAS Split
#                           3a    - Merge dos arquivos NICAS
#                           3b    - Organização da matriz B final
#
#                         Exemplos:
#
#                           prep1,prep2,prep3
#
#                           prep1,prep2,prep3,0,1a,1b,1c,2,3a,3b
#
#                           1a,2
#
# !EXAMPLE:
#   ./runGenB.sh EXP1 163842 SaoPaulo 2026051500 2026052000 1 128 prep1,prep2,prep3,0,1a,1b,1c,2,3a,3b
#
# !REVISION HISTORY:
#
#   - Adaptado por Amanda a partir dos scripts do Tutorial UCAR/NCAR.
#   - Última atualização: 31 Ago 2026
#
# !REMARKS:
#
#   O argumento STEPS permite reiniciar a execução em qualquer etapa,
#   evitando repetir etapas já concluídas.
#
#EOP
#-----------------------------------------------------------------------------#
#BOC

function usage(){
   sed -n '/^#BOP/,/^#EOP/{/^#BOP/d;/^#EOP/d;p}' ${BASH_SOURCE}
}

if [ $# -ne 8 ]; then
   usage
   exit 1
fi

EXP=${1}
RES=${2}
AREA=${3}
LABELI=${4}
LABELF=${5}
NNODES=${6}
NTASKSPN=${7}
STEPS=${8}

export LD_LIBRARY_PATH=$NETCDF/lib:$HDF5/lib:$GRIB2/lib:$LD_LIBRARY_PATH

BASEDIR=${HOMEBE}/mpas_jedi_reg
RUNDIR=${BASEDIR}/run
GFSDIR=${BASEDIR}/gfsdata
SSTDIR=${BASEDIR}/sstdata
EXEDIR=${BASEDIR}/bin
TBLDIR=${BASEDIR}/pre/tables
MESH_DIR=${BASEDIR}/pre/meshes/${AREA}
NMLDIR=${BASEDIR}/namelist
GBDIR=${BASEDIR}/GB
WRFBIN=${GBDIR}/prep

EXPDIR=${RUNDIR}/${EXP}/GB

fhr0=12
fhr1=24
fhr2=48

#
# Steps
# 

run_step() {
    [[ ",${STEPS}," == *",$1,"* ]]
}

#

if [ -e ${EXPDIR} ]; then
  echo "Folder ${EXPDIR} already exist! Warning: It will not be removed."
  else
   echo "Creating folder ${EXPDIR}/{prep,proc}"
   mkdir -p ${EXPDIR}/{prep,proc}
fi

cd ${EXPDIR}/prep

#PREPROCESSING

#Step 1
ref_file=${RUNDIR}/${EXP}/runinit/${LABELI}/${AREA}.init.nc

if run_step "prep1"; then
   ${GBDIR}/prep/1_generate_template_PTB.bash \
      ${EXPDIR}/prep ${TBLDIR} ${AREA} ${ref_file}
fi

#Step 2
if run_step "prep2"; then
   ${GBDIR}/prep/2_add_variables.bash \
      ${EXPDIR}/prep ${WRFBIN} ${LABELI} ${LABELF} ${fhr0} ${fhr1}

   ${GBDIR}/prep/2_add_variables.bash \
      ${EXPDIR}/prep ${WRFBIN} ${LABELI} ${LABELF} ${fhr0} ${fhr2}
fi

#Step 3
if run_step "prep3"; then
   ${GBDIR}/prep/3_ncdiff.bash \
      ${EXPDIR}/prep ${WRFBIN} ${LABELI} ${LABELF} \
      ${fhr0} ${fhr1} ${fhr2}
fi

#PROCESSING

#Step 0
if run_step "0"; then
   ${GBDIR}/proc/0_link_samples.bash \
      ${EXPDIR} ${WRFBIN} ${LABELI} ${LABELF} \
      ${fhr0} ${fhr1} ${fhr2}
fi

#Step 1a
if run_step "1a"; then
   ${GBDIR}/proc/1a_run_hdiag_var.bash \
      ${EXPDIR}/proc ${NMLDIR} ${TBLDIR} ${EXEDIR} \
      ${WRFBIN} ${LABELI} ${LABELF} ${EXP} ${RES} \
      ${NNODES} ${NTASKSPN} ${AREA} ${MESH_DIR}
fi

# Step 1b
if run_step "1b"; then
   ${GBDIR}/proc/1b_run_hdiag_var.bash \
      ${EXPDIR}/proc ${NMLDIR} ${TBLDIR} ${EXEDIR} \
      ${WRFBIN} ${LABELI} ${LABELF} ${EXP} ${RES} \
      ${NNODES} ${NTASKSPN} ${AREA} ${MESH_DIR}
fi

# Step 1c
if run_step "1c"; then
   ${GBDIR}/proc/1c_modify_diagnostics.bash \
      ${EXPDIR}/proc ${GBDIR}/proc
fi

# Step 2
if run_step "2"; then
   ${GBDIR}/proc/2_run_nicas_split.bash \
      ${EXPDIR}/proc ${NMLDIR} ${TBLDIR} ${EXEDIR} \
      ${WRFBIN} ${LABELI} ${LABELF} ${EXP} ${RES} \
      ${NNODES} ${NTASKSPN} ${AREA} ${MESH_DIR}
fi

# Step 3a
if run_step "3a"; then
   ${GBDIR}/proc/3_merge_nicas.bash \
      ${EXPDIR}/proc ${NNODES} ${NTASKSPN}
fi

# Step 3b
if run_step "3b"; then
   if [ -e ${EXPDIR}/B_Matrix_${EXP} ]; then
      rm -rf ${EXPDIR}/B_Matrix_${EXP}
   fi

   mkdir -p ${EXPDIR}/B_Matrix_${EXP}/{bump_nicas,stddev}

   cp -v ${EXPDIR}/proc/NICAS.split/merge/*nc \
         ${EXPDIR}/B_Matrix_${EXP}/bump_nicas

   cp -v ${EXPDIR}/proc/HDIAG_VAR/merge/*nc \
         ${EXPDIR}/B_Matrix_${EXP}/stddev
   
   ln -sf ${EXPDIR}/B_Matrix_${EXP} ${BASEDIR}/bedata/B_Matrix
fi
