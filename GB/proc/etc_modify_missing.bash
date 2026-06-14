#!/bin/bash

filename1="mpas.cor_rh.nc"
filename2="mpas.cor_rv.nc"
filename3="mpas.stddev.nc"

cp ${filename1} ${filename1}_w_missing_qx
cp ${filename2} ${filename2}_w_missing_qx
cp ${filename3} ${filename3}_w_missing_qx

cat > modify_missing.py << EOF
import numpy as np
from netCDF4 import Dataset  # http://code.google.com/p/netcdf4-python/

var_for_modif_list = ['qc', 'qi', 'qr', 'qs', 'qg']

#! cor_rh file
f = Dataset('${filename1}', "r+", format="NETCDF4") #Dataset is the class behavior to open the file
for var in var_for_modif_list:
   dum=f[var][:]
   idx=np.where(dum <= 0.0)
   dum[idx] = 0.0
   f[var][:]=dum
f.close()

#! cor_rv file
f = Dataset('${filename2}', "r+", format="NETCDF4") #Dataset is the class behavior to open the file
for var in var_for_modif_list:
   dum=f[var][:]
   idx=np.where(dum <= 0.0)
   dum[idx] = 0.0
   f[var][:]=dum
f.close()

#! stddev file
f = Dataset('${filename3}', "r+", format="NETCDF4") #Dataset is the class behavior to open the file
for var in var_for_modif_list:
   dum=f[var][:]
   idx=np.where(dum <= 0.0)
   dum[idx] = 0.0
   f[var][:]=dum
f.close()

quit()
EOF

#execute the script
python modify_missing.py
