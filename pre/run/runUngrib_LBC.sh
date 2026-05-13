#!/bin/bash
#-----------------------------------------------------------------------------#
#BOP
#
# !SCRIPT: runUngrib_LBC
#
# !DESCRIPTION:
#   Script para execução do UNGRIB das LBC do GFS no MPAS-JEDI regional.
#   O script prepara o ambiente, cria o link necessário para 
#   o arquivos GRIB do GFS, gera o namelist apropriado
#   e executa o ungrib (unMP.exe).
#
# !CALLING SEQUENCE:
#   ./runUngrib_LBC.sh <EXP> <LABELI> <LABELF> <AREA> <RES>
#
#     o EXP    : Nome do experimento (ex.: EXP1)
#     o LABELI : Data inicial no formato YYYYMMDDHH
#     o LABELF : Data final   no formato YYYYMMDDHH
#     o AREA   : Nome da área/região (ex.: SaoPaulo)
#     o RES    : Resolução do MPAS
#
# !EXAMPLE:
#   ./runUngrib_LBC EXP1 2025010100 2025010200 SaoPaulo 163842
#
# !REVISION HISTORY:
#   - Adaptado por Amanda.
#   - Última modificação 12 Mai 2026
#
# !REMARKS:
#   - Espera encontrar os dados do GFS organizados por YYYY/MM/DD/HH em GFSDIR.
#   - Requer o arquivo estático regional ${AREA}.static.nc já existente.
#   - Gera arquivos como GFS:2025-09-01_00 dentro de 
#   EXPDIR=${RUNDIR}/${EXP}/${LABELI:0:10}
#   - Nessa etapa, o ungrib é realizado para todos os arquivos do período da rodada.
#
#EOP
#-----------------------------------------------------------------------------#
#BOC

function usage(){
   sed -n '/^#BOP/,/^#EOP/{/^#BOP/d;/^#EOP/d;p}' ${BASH_SOURCE}
}

if [ $# -ne 5 ]; then
   usage
   exit 1
fi

#
# Argumentos
#

EXP=${1}
LABELI=${2}
LABELF=${3}
AREA=${4}
RES=${5}

start_date=${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}_${LABELI:8:2}:00:00
end_date=${LABELF:0:4}-${LABELF:4:2}-${LABELF:6:2}_${LABELF:8:2}:00:00

#
# Set paths
#

export LD_LIBRARY_PATH=$NETCDF/lib:$HDF5/lib:$GRIB2/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH="/home/amanda.queiroz/jedi-bundle/build-jedi/lib:$LD_LIBRARY_PATH"

BASEDIR=${HOMEBE}/mpas_jedi_reg
RUNDIR=${BASEDIR}/run
GFSDIR=${BASEDIR}/gfsdata
DATADIR=${BASEDIR}/pre/datain
TBLDIR=${BASEDIR}/pre/tables
NMLDIR=${BASEDIR}/namelist
EXEDIR=${BASEDIR}/pre/exec
BNDDIR=${GFSDIR}/${LABELI:0:4}/${LABELI:4:2}/${LABELI:6:2}/${LABELI:8:2}
EXPDIR=${RUNDIR}/${EXP}
STATICDIR=${RUNDIR}/${EXP}/static
PRERUNDIR=${BASEDIR}/pre/run

#
RUNINIT=${RUNDIR}/${EXP}/runinit/${LABELI:0:4}${LABELI:4:2}${LABELI:6:2}${LABELI:8:2}
LOGDIR=${RUNINIT}/logs

#
# Criando diretórios da rodada
#

if [ ! -e ${RUNINIT} ]; then
   mkdir -p ${RUNINIT}
   mkdir -p ${RUNINIT}/logs   
   mkdir -p ${RUNINIT}/sst
   mkdir -p ${RUNINIT}/wpsprd
   mkdir -p ${RUNINIT}/namelist
fi

#
# Recorte dos dados globais do GFS
#
path_reg="${DATADIR}/regional/${LABELI}"

#
# Verifica se existe diretório global (obrigatório)
#

if [ ! -d "${BNDDIR}" ]; then
    echo "Condicao de contorno inexistente!"
    echo "Verifique a data da rodada."
    echo "$0 ${LABELI}"
    exit 1
fi

#
# Garante que o diretório regional exista
#
mkdir -p "${path_reg}"

cd ${RUNINIT}/wpsprd

#
# Conta arquivos já existentes
#
nfiles=$(ls -A gfs.t${LABELI:8:2}z.pgrb2.0p25.f*.${LABELI}.grib2 2>/dev/null | wc -l)

if [ "${nfiles}" -le 20 ]; then
    echo "Reprocessando dados GFS..."

    rm -f gfs.t${LABELI:8:2}z.pgrb2.0p25.f*.${LABELI}.grib2*

    filelist="${BNDDIR}/gfs.t${LABELI:8:2}z.pgrb2.0p25.f*.${LABELI}.grib2"

    for files in $filelist; do
        [ -e "$files" ] || continue

        filename=$(basename "$files")
        nhour=$(echo "${filename:21:3}" | gawk '{print $1/1}')

        if [ "${nhour}" -le 48 ]; then
            echo "Processing $filename file..."

            if [ ! -e "${path_reg}/${filename}" ]; then
                echo "File ${path_reg}/${filename} does not exist."

                CDI_INVENTORY_MODE=time \
                cdo sellonlatbox,260,350,-70,20 \
                "${BNDDIR}/${filename}" "${path_reg}/${filename}"
            else
                echo "File ${path_reg}/${filename} exists."
            fi

            ln -sf "${path_reg}/${filename}" "${RUNINIT}/wpsprd/${filename}"
        fi
    done

else
    echo "Dados já existentes - apenas linkando..."

    ln -sf "${path_reg}"/* .
fi

#
# Script
#

NNODES=1
JNAME=ungrib_LBC
QUEUE=PESQ1

cd ${RUNINIT}

cat > ${RUNINIT}/ungrib_lbc_exe.sh << EOF0
#!/bin/bash
#SBATCH --job-name=${JNAME}
#SBATCH --partition=${QUEUE}
#SBATCH --exclusive
#SBATCH --nodes=${NNODES}
#SBATCH --tasks-per-node=1                      # ic for benchmark
#SBATCH --time=00:30:00
#SBATCH --output=${LOGDIR}/ungrib.log    # File name for standard output

#
ulimit -s unlimited
ulimit -c unlimited
ulimit -v unlimited

export PMIX_MCA_gds=hash

echo  "STARTING AT \`date\` "
Start=\`date +%s.%N\`
echo \$Start > Timing.ungrib
#
cd ${RUNINIT}
 
ln -sf ${STATICDIR}/${AREA}.static.nc .

cd ${RUNINIT}/wpsprd

#

echo "FORECAST "${LABELI}

cp ${TBLDIR}/Vtable.GFS ${RUNINIT}/wpsprd/Vtable

cp ${PRERUNDIR}/link_grib.csh ${RUNINIT}/wpsprd/link_grib.csh 
chmod 777 ${RUNINIT}/wpsprd/link_grib.csh

cp ${EXEDIR}/unMP.exe ${RUNINIT}/wpsprd/unMP.exe

export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:${HOME}/local/lib64

ldd unMP.exe

cd ${RUNINIT}/wpsprd 

if [ -e namelist.wps ]; then rm -f namelist.wps; fi
#
# Now surface and upper air atmospheric variables
#
rm -f GRIBFILE.* namelist.wps

sed -e "s,#LABELI#,${start_date},g;s,#LABELF#,${end_date},g;s,#PREFIX#,GFS,g" \
	 ${NMLDIR}/namelist.wps.LBC.${EXP} > ./namelist.wps
	 
${RUNINIT}/wpsprd/link_grib.csh gfs.t${LABELI:8:2}z.pgrb2.0p25.f*.${LABELI}.grib2

mpirun -np 1 ./unMP.exe

echo ${start_date:0:13}

rm -f GRIBFILE.*

End=\`date +%s.%N\`
echo  "FINISHED AT \`date\` "
echo \$End   >>Timing.ungrib
echo \$Start \$End | gawk '{print \$2 - \$1" sec"}' >> Timing.ungrib

rm -f ${RUNINIT}/Timing.ungrib

grep "Successful completion of program ungrib.exe" ungrib.log >& /dev/null

if [ \$? -ne 0 ]; then
   echo "  BUMMER: Ungrib generation failed for some yet unknown reason."
   echo " "
   tail -10 ungrib.log
   echo " "
   exit 21
fi
   echo "  ####################################"
   echo "  ### Ungrib completed - \$(date) ####"
   echo "  ####################################"
   echo " " 
#
# clean up and remove links
#
   mv ${RUNINIT}/wpsprd/Timing.ungrib   ${LOGDIR}/Timing.ungrib.LBC
   mv ungrib.log ${LOGDIR}/ungrib.LBC.log
   mv namelist.wps    ${RUNINIT}/namelist/namelist.wps.LBC
   rm -f ${RUNINIT}/wpsprd/link_grib.csh
   cd ..
   ln -sf wpsprd/GFS\:* .
   
   find ${RUNINIT}/wpsprd -maxdepth 1 -type l -exec rm -f {} \;
   
echo "End of ungrib Job"

exit 0
EOF0

chmod +x ${RUNINIT}/ungrib_lbc_exe.sh

echo sbatch --wait ${RUNINIT}/ungrib_lbc_exe.sh
if [ "${SLURM:-NO}" = "NO" ]; then
   ${RUNINIT}/ungrib_lbc_exe.sh
else
   sbatch --wait ${RUNINIT}/ungrib_lbc_exe.sh
fi

#EOC
