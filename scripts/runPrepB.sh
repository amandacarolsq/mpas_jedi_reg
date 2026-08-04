#!/bin/bash
#-----------------------------------------------------------------------------#
#BOP
#
# !SCRIPT: runPrepB
#
# !DESCRIPTION:
#   Script para execução automática do fluxo completo de preparação e
#   integração do MPAS regional para uma sequência de datas de análise
#   para geração da matriz B.
#
#   O script executa as seguintes etapas para cada data:
#     - Calcula automaticamente a data final (+48 h);
#     - Cria a malha regional (apenas na primeira execução);
#     - Gera os arquivos estáticos (apenas na primeira execução);
#     - Gera os arquivos invariantes;
#     - Processa as condições iniciais (IC) a partir do GFS;
#     - Gera as condições iniciais do MPAS;
#     - Processa as condições de contorno (LBC);
#     - Gera as condições de contorno do MPAS;
#     - Executa a integração do modelo regional.
#
# !CALLING SEQUENCE:
#   ./runPrepB.sh <EXP> <RES> <AREA> <LABELI> <LABELF> [INTERVAL]
#
#     o EXP       : Nome do experimento
#     o RES       : Resolução da malha
#     o AREA      : Nome da área regional
#     o LABELI    : Data inicial (YYYYMMDDHH)
#     o LABELF    : Data final   (YYYYMMDDHH)
#     o INTERVAL  : Intervalo entre ciclos em horas (opcional, padrão = 12)

# !EXAMPLE:
#   ./runPrepB.sh matrix 163842 Centrossul 2026051500 2026052000 12
#
# !REVISION HISTORY:
#   - Adaptado por Amanda.
#   - Última atualização: 4 Ago 2026
#
# !REMARKS:
#   - A malha regional (runCreateRegion.sh) e os arquivos estáticos
#     (runStatic.sh) são executados apenas para a primeira data da lista.
#   - O período de integração é fixado em 48 horas para cada execução.
#
#EOP
#-----------------------------------------------------------------------------#
#BOC

if [[ $# -lt 5 ]]; then
    echo "Uso:"
    echo "  ./runALL.sh <EXP> <RES> <AREA> <LABELI> <LABELF> [INTERVAL]"
    exit 1
fi

EXP=${1}
RES=${2}
AREA=${3}
LABELI=${4}
LABELF=${5}
INTERVAL=${6:-12}    # Se não foi informado, use 12.

data_ini=$LABELI

BASEDIR=${HOMEBE}/mpas_jedi_reg

# Loop nas datas
while [[ "$data_ini" -le "$LABELF" ]]; do

    # Calcula data final (+48 h)
    data_fim=$(date -d "${data_ini:0:8} ${data_ini:8:2} +48 hours" +"%Y%m%d%H")

    echo "=============================================================="
    echo "Rodando: $data_ini -> $data_fim"
    echo "=============================================================="

    # Cria a malha apenas na primeira data
    if [[ "$data_ini" == "$LABELI" ]]; then
        cd ${BASEDIR}/pre/meshes
        ./runCreateRegion.sh ${RES} ${AREA}
    fi

    cd ${BASEDIR}/pre/run

    # Gera os arquivos estáticos apenas na primeira data
    if [[ "$data_ini" == "$LABELI" ]]; then
        ./runStatic.sh ${EXP} ${RES} ${AREA}
    fi

    ./runInvariant.sh     "$EXP" "$RES" "$AREA" "$data_ini"
    ./runUngrib_IC.sh     "$EXP" "$RES" "$AREA" "$data_ini" "$data_fim"
    ./runInitAtmos_IC.sh  "$EXP" "$RES" "$AREA" "$data_ini" "$data_fim"
    ./runUngrib_LBC.sh    "$EXP" "$RES" "$AREA" "$data_ini" "$data_fim"
    ./runInitAtmos_LBC.sh "$EXP" "$RES" "$AREA" "$data_ini" "$data_fim"

    cd ${BASEDIR}/scripts

    ./runModel.sh "$EXP" "$RES" "$AREA" "$data_ini" "$data_fim" 48 0

    # Próxima data
    data_ini=$(date -d "${data_ini:0:8} ${data_ini:8:2} +${INTERVAL} hours" +"%Y%m%d%H")

done
