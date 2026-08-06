#!/bin/bash
#-----------------------------------------------------------------------------#
#BOP
#
# !SCRIPT: 3_merge_nicas
#
# !DESCRIPTION:
#
# !CALLING SEQUENCE:
#     
#        ./3_merge_nicas.bash ${EXPDIR}/proc  ${NNODES}  ${NTASKSPN}
#
#           o EXPDIR=${RUNDIR}/${EXP}/GB
#           o NNODES    : Número de nós computacionais utilizados na execução
#           o NTASKSPN  : Número de tarefas MPI por nó
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

module load nco-5.0.1-gcc-11.2.0-u37c3hb

if [ $# -ne 3 ]; then
   usage
   exit 1
fi

RUNDIR=${1}
NNODES=${2}
NTASKSPN=${3}

nicasDir=${RUNDIR}/NICAS.split
nicasMergeDir=${nicasDir}/merge

(( nlocal = NNODES * NTASKSPN ))           #User's configuration
cores_per_node=128  #Derecho

list_vars="uReconstructZonal uReconstructMeridional temperature spechum surface_pressure qc qi qr qs qg"

workdir=${nicasMergeDir}

mkdir -p ${workdir}
cd ${workdir}

# First merging the "local" NICAS files.
# Number of local files
ntotpad=$(printf "%.6d" "${nlocal}")

for itot in $(seq 1 ${nlocal}); do
   itotpad=$(printf "%.6d" "${itot}")

   # Local full files names
   filename_full=mpas_nicas_local_${ntotpad}-${itotpad}.nc
   filename_grids_full=mpas_nicas_grids_local_${ntotpad}-${itotpad}.nc

   # Remove existing local full files
   rm -f ${filename_full}
   rm -f ${filename_grids_full}

   # Create scripts to merge local files
   echo "#!/bin/bash" > merge_nicas_${itotpad}.bash
   for variable in ${list_vars}; do
      filename="../${variable}/${filename_full}"
      echo -e "ncks -A ${filename} ${filename_full}" >> merge_nicas_${itotpad}.bash
      echo -e "ncatted -O -a eulaVlliF_,global,d,, ${filename_full}" >> merge_nicas_${itotpad}.bash
      filename_grids="../${variable}/${filename_grids_full}"
      echo -e "ncks -A ${filename_grids} ${filename_grids_full}" >> merge_nicas_${itotpad}.bash
      echo -e "ncatted -O -a eulaVlliF_,global,d,, ${filename_grids_full}" >> merge_nicas_${itotpad}.bash
   done
   chmod +x merge_nicas_${itotpad}.bash
done


# Second: merging the "global" NICAS files.
# Global full files names
filename_full=mpas_nicas.nc

# Remove existing global full files.
rm -f ${filename_full}

# Create script to merge global files
nlocalp1=$((nlocal+1))
itotpad=$(printf "%.6d" "${nlocalp1}")
echo "#!/bin/bash" > merge_nicas_${itotpad}.bash
for variable in ${list_vars}; do
   filename="../${variable}/${filename_full}"
   echo -e "ncks -A ${filename} ${filename_full}" >> merge_nicas_${itotpad}.bash
   echo -e "ncatted -O -a eulaVlliF_,global,d,, ${filename_full}" >> merge_nicas_${itotpad}.bash
done
chmod +x merge_nicas_${itotpad}.bash
./merge_nicas_${itotpad}.bash

#Other diagnostics:  nicas_norm, dirac_nicas
for variable in ${list_vars}; do
  ncks -A -v ${variable} ../${variable}/mpas.nicas_norm.nc   mpas.nicas_norm.nc
  ncks -A -v ${variable} ../${variable}/mpas.dirac_nicas.nc  mpas.dirac_nicas.nc
done

(( NTASKS = NTASKSPN * NNODES ))
JNAME=JEDI_MNICAS
QUEUE=PESQ1
cat > jedi_mnicas.bash <<EOF
#!/bin/bash

#SBATCH --output=mpas_nicas.log
#SBATCH --ntasks-per-node=${NTASKSPN}
#SBATCH --cpus-per-task=1
#SBATCH --ntasks=1
#SBATCH --array=1-${NTASKS}
#SBATCH --time=00:30:00
#SBATCH --job-name=${JNAME}
#SBATCH --partition=${QUEUE}

export OMP_NUM_THREADS=1

ulimit -s unlimited
export GFORTRAN_CONVERT_UNIT='big_endian:101-200'

SCRIPT_NUM=\$(printf "%06d" \${SLURM_ARRAY_TASK_ID})
SCRIPT=merge_nicas_\${SCRIPT_NUM}.bash

bash "\${SCRIPT}"

EOF

sbatch --wait jedi_mnicas.bash

#-----------------------------------------------------------------------------#
#EOC
