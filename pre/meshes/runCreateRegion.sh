#!/bin/bash
#-----------------------------------------------------------------------------#
#BOP
#
# !SCRIPT: runCreateRegion
#
# !DESCRIPTION:
#   Script para geração do domínio regional no MPAS-JEDI Regional. Ele verifica
#   a existência do arquivo estático global, executa o create_region
#   e realiza a partição usando o METIS.
#
# !CALLING SEQUENCE:
#   ./runCreateRegion.sh <RES> <AREA>
#
#     o RES   : Resolução quase uniforme (ex.: 163842 para 60 km)
#     o AREA  : Nome da área  (ex.: SaoPaulo)
#
# !EXAMPLE:
#     ./runCreateRegion.sh 163842 SaoPaulo
#
# !REVISION HISTORY:
#   - Por Amanda para automatizar a criação do domínio regional e arquivos de partição.
#   - Última atualização 24 Mar 2026
#
# !REMARKS:
#   - O script deve ser executado dentro de um ambiente com módulos disponíveis
#   (na minha área, eu carrego os módulos com o alias envj).
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

set -e

#
# Argumentos
#

RES=$1
AREA=$2

if [ -z "$RES" ] || [ -z "$AREA" ]; then
  echo "Uso: $0 <RESOLUCAO> <AREA>"
  exit 1
fi

#
# Set paths
#

DIR="/mnt/beegfs/amanda.queiroz/reg/pre/meshes"
MESH_DIR="/mnt/beegfs/amanda.queiroz/reg/pre/meshes/${AREA}"
GRID_FILE="/mnt/beegfs/amanda.queiroz/reg/pre/meshes/x1.${RES}.grid.nc"
PTS_FILE="${DIR}/pts/${AREA}.ellipse.pts"

cd "$DIR"

# Check files
if [ ! -f "${MESH_DIR}/${AREA}.grid.nc" ]; then
  echo "Criando grade regional..."

# Check static file
  if [ ! -f "$GRID_FILE" ]; then
    echo "Erro: Arquivo de grade não encontrado: $GRID_FILE"
    exit 1
  fi

   # Check pts file
  if [ ! -f "$PTS_FILE" ]; then
    echo "Erro: Arquivo .pts da área não encontrado: $PTS_FILE"
    exit 1
  fi
  
  chmod +x create_region
  ./create_region "${PTS_FILE}" "$GRID_FILE"
  mv ${AREA}.* "${MESH_DIR}"
else
  echo "Arquivo ${PTS_FILE} já existe."
fi

# Rodar METIS apenas se partições não existirem
if [ ! -f "${MESH_DIR}/${AREA}.graph.info.part.128" ]; then
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
  gpmetis -minconn -contig -niter=1000 "${MESH_DIR}/${AREA}.graph.info" 512
  
else
  echo "Partições já existem."
fi

echo "Processo finalizado com sucesso."

#EOC
