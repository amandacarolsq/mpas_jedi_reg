#!/bin/bash
#-----------------------------------------------------------------------------#
#BOP
#
# !SCRIPT: runCreateRegion
#
# !DESCRIPTION:
#   Script para geração do domínio regional no MPAS-JEDI regional. Verifica
#   a existência do arquivo estático global, executa o create_region
#   e realiza a partição usando o METIS.
#
# !CALLING SEQUENCE:
#   ./runCreateRegion.sh <RES> <AREA>
#
#     o RES   : Resolução (ex.: 163842 para 60 km)
#     o AREA  : Nome da área  (ex.: SaoPaulo)
#
# !EXAMPLE:
#     ./runCreateRegion.sh 163842 SaoPaulo
#
# !REVISION HISTORY:
#   - Por Amanda Queiroz. 
#   - Última atualização: 9 Jun 2026
#
# !REMARKS:
#   - O script deve ser executado dentro de um ambiente com módulos disponíveis.
#   - Espera encontrar ${AREA}.pts na pasta meshes/${AREA}.
#   - Saídas geradas: ${AREA}.grid.nc, ${AREA}.graph.info, ${AREA}.graph.info.128, 
#   ${AREA}.graph.info.32, ${AREA}.graph.info.256, ${AREA}.graph.info.512
#
#EOP
#-----------------------------------------------------------------------------#
#BOC

function usage(){
   sed -n '/^#BOP/,/^#EOP/{/^#BOP/d;/^#EOP/d;p}' ${BASH_SOURCE}
}

if [ $# -ne 2 ]; then
   usage
   exit 1
fi

#
# Argumentos
#

RES=${1}
AREA=${2}

#
# Set paths
#

BASEDIR=${HOMEBE}/pre/meshes
MESH_DIR=${BASEDIR}/${AREA}
GRID_FILE=${BASEDIR}/x1.${RES}.grid.nc
PTS_FILE=${BASEDIR}/pts/${AREA}.ellipse.pts

cd ${BASEDIR}

# Check files
if [ ! -f ${MESH_DIR}/${AREA}.grid.nc ]; then
  echo "Criando grade regional..."

# Check static file
  if [ ! -f ${GRID_FILE} ]; then
    echo "Erro: Arquivo de grade não encontrado: $GRID_FILE"
    exit 1
  fi

   # Check pts file
  if [ ! -f ${PTS_FILE} ]; then
    echo "Erro: Arquivo .pts da área não encontrado: $PTS_FILE"
    exit 1
  fi
  
  chmod +x create_region
  ./create_region ${PTS_FILE} ${GRID_FILE}
  mv ${AREA}.* ${MESH_DIR}
else
  echo "Arquivo ${PTS_FILE} já existe."
fi

# Rodar METIS apenas se partições não existirem
if [ ! -f ${MESH_DIR}/${AREA}.graph.info.part.128 ]; then
  echo "Gerando partições com METIS..."
  
  # Load METIS
  module use /opt/ohpc/pub/moduledeps/gnu9
  module spider metis
  module load metis

  # Run gpmetis
  gpmetis -minconn -contig -niter=1000 "${MESH_DIR}/${AREA}.graph.info" 128
  gpmetis -minconn -contig -niter=1000 "${MESH_DIR}/${AREA}.graph.info" 16
  gpmetis -minconn -contig -niter=1000 "${MESH_DIR}/${AREA}.graph.info" 32
  gpmetis -minconn -contig -niter=1000 "${MESH_DIR}/${AREA}.graph.info" 256
  gpmetis -minconn -contig -niter=1000 "${MESH_DIR}/${AREA}.graph.info" 64
  
else
  echo "Partições já existem."
fi

echo "Processo finalizado com sucesso."

#EOC
