#!/bin/bash
#-----------------------------------------------------------------------------#
#BOP
#
# !SCRIPT: runALL_DA
#
# !DESCRIPTION:
#   Script para execução automática do fluxo completo de preparação,
#   integração e assimilação do MPAS regional para uma sequência de
#   datas de análise.
#
#   O script executa as seguintes etapas para cada data:
#     - Gera os arquivos estáticos (apenas se ainda não existirem);
#     - Gera o arquivo invariante (apenas se ainda não existir);
#     - Processa as condições iniciais (IC) a partir do GFS;
#     - Gera as condições iniciais do MPAS;
#     - Processa as condições de contorno (LBC);
#     - Gera as condições de contorno do MPAS;
#     - Prepara as observações para assimilação;
#     - Executa a integração do modelo regional;
#     - Executa a assimilação de dados.
#
# !CALLING SEQUENCE:
#   ./runALL_DA.sh <EXP> <RES> <AREA> <LABELI> <LABELF> <FCST> <FROMDA> <NHCIC> <FROMCIC> <WINDOW> <MATRIX>
#
#     o EXP     : Nome do experimento (ex.: EXP1)
#     o RES     : Resolução do experimento (ex.: 163842 para 60 km)
#     o AREA    : Nome da área (ex.: SaoPaulo)
#     o LABELI  : Data inicial no formato YYYYMMDDHH
#     o LABELF  : Data final   no formato YYYYMMDDHH
#     o FCST    : Tempo de previsao, em horas (ex. 24 [horas])
#     o FROMDA  : Se condição inicial vem do Init = 0, se vem da
#                 assimilação de dados = 1
#     o NHCIC   : Número de horas do ciclo (ex. 6 [horas])
#     o FROMCIC : O Background vem do ciclo: sim: 1; não: 0
#     o WINDOW  : Janela de assimilação (ex. 180 [minutos])
#     o MATRIX  : Nome do diretório com informações da matriz B (ex. matrix)
#
# !EXAMPLE:
#   ./runALL_DA.sh EXP1 163842 SaoPaulo 2026051500 2026052000 96 0 6 0 180 matrix
#
# !REVISION HISTORY:
#   - Por Amanda.
#   - Última atualização: 26 Ago 2026
#
# !REMARKS:
#   - O período de integração é fixado em 48 horas para cada execução.
#   - Os arquivos estáticos e invariantes são gerados apenas quando
#     ainda não existem.
#
#EOP
#-----------------------------------------------------------------------------#
#BOC

function usage(){
   sed -n '/^#BOP/,/^#EOP/{/^#BOP/d;/^#EOP/d;p}' ${BASH_SOURCE}
}


if [ $# -ne 11 ]; then
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
FCST=${6}
FROMDA=${7}
NHCIC=${8}
FROMCIC=${9}
WINDOW=${10}
MATRIX=${11}

#
# Caminhos
#

BASEDIR=${HOMEBE}/mpas_jedi_reg

cd ${BASEDIR}/pre/run

#
# Static file
#

STATIC_FILE="${BASEDIR}/run/${MATRIX}/static/${AREA}.static.nc"
STATIC_DIR="${BASEDIR}/run/${MATRIX}/static"
DEST_DIR="${BASEDIR}/run/${EXP}/static"

if [[ -f "${STATIC_FILE}" ]]; then

    echo "--------------------------------------------------------------"
    echo "Arquivo estático já existe:"
    echo "  ${STATIC_FILE}"
    echo "Copiando diretório static para:"
    echo "  ${DEST_DIR}"
    echo "--------------------------------------------------------------"

    mkdir -p "${DEST_DIR}"
    cp -r "${STATIC_DIR}/." "${DEST_DIR}/"

else

    echo "--------------------------------------------------------------"
    echo "Arquivo estático não encontrado:"
    echo "  ${STATIC_FILE}"
    echo "Gerando arquivo estático..."
    echo "--------------------------------------------------------------"

    ./runStatic.sh "${EXP}" "${RES}" "${AREA}"

fi

#
# Invariant file
#

INVARIANT_FILE="${BASEDIR}/run/${MATRIX}/invariant/${AREA}.invariant.nc"
INVARIANT_DIR="${BASEDIR}/run/${MATRIX}/invariant"
DEST_INVARIANT_DIR="${BASEDIR}/run/${EXP}/invariant"

if [[ -f "${INVARIANT_FILE}" ]]; then

    echo ""
    echo "--------------------------------------------------------------"
    echo "Arquivo invariante já existe:"
    echo "  ${INVARIANT_FILE}"
    echo "Pulando runInvariant.sh."
    echo "--------------------------------------------------------------"
    echo ""

    mkdir -p "${BASEDIR}/run/${EXP}"
    cp -r "${INVARIANT_DIR}" "${BASEDIR}/run/${EXP}/"

else

    echo ""
    echo "--------------------------------------------------------------"
    echo "Arquivo invariante não encontrado."
    echo "Gerando arquivo invariante..."
    echo "--------------------------------------------------------------"
    echo ""

    ./runInvariant.sh "${EXP}" "${RES}" "${AREA}" "${LABELI}"

fi

#
# IC
#

echo ""
echo "--------------------------------------------------------------"
echo "Preparando os dados do GFS para as condições iniciais (IC):"
echo "--------------------------------------------------------------"
echo ""

./runUngrib_IC.sh "${EXP}" "${RES}" "${AREA}" "${LABELI}" "${LABELF}"

echo ""
echo "--------------------------------------------------------------"
echo "Gerando as condições iniciais."
echo "--------------------------------------------------------------"
echo ""

./runInitAtmos_IC.sh "${EXP}" "${RES}" "${AREA}" "${LABELI}" "${LABELF}"

#
# LBC
#

echo ""
echo "--------------------------------------------------------------"
echo "Preparando os dados do GFS para as condições de contorno (LBC):"
echo "--------------------------------------------------------------"
echo ""

./runUngrib_LBC.sh "${EXP}" "${RES}" "${AREA}" "${LABELI}" "${LABELF}" "${FCST}"

echo ""
echo "--------------------------------------------------------------"
echo "Gerando as condições de contorno."
echo "--------------------------------------------------------------"
echo ""

./runInitAtmos_LBC.sh "${EXP}" "${RES}" "${AREA}" "${LABELI}" "${LABELF}"

echo ""
echo "--------------------------------------------------------------"
echo "Preparando as observações:"
echo "--------------------------------------------------------------"
echo ""
    
cd ${BASEDIR}/scripts

./runPrepObs.sh "${LABELI}" "${LABELF}"

echo ""
echo "--------------------------------------------------------------"
echo "Executando o modelo:"
echo "--------------------------------------------------------------"
echo ""

./runModel.sh "${EXP}" "${RES}" "${AREA}" "${LABELI}" "${LABELF}" "${FCST}" "${FROMDA}"

#echo ""
#echo "--------------------------------------------------------------"
#echo "Executando a assimilação:"
#echo "--------------------------------------------------------------"
#echo ""

#./runDA.sh "${EXP}" "${RES}" "${AREA}" "${LABELI}" "${LABELF}" "${NHCIC}" "${FCST}" "${FROMCIC}" "${WINDOW}"

echo "--------------------------------------------------------------"
echo " Processamento finalizado com sucesso!"
echo "--------------------------------------------------------------"

#EOC
