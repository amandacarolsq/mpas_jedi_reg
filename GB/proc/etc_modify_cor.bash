#!/bin/bash

filename1="mpas.cor_rh.nc"

cp ${filename1} ${filename1}_org

#write the python script
cat > modify_cor.py << EOF
import numpy as np
from netCDF4 import Dataset  # http://code.google.com/p/netcdf4-python/

# set files to modify
fn1 = './${filename1}'

# open file
f1 = Dataset(fn1, "r+", format="NETCDF4") #Dataset is the class behavior to open the file


#   Reduce rh as half for stream_function and velocity_potential
# variables to modify
var_for_modif_list1 = ["stream_function", "velocity_potential"]
var_for_modif_list2 = ["qc", "qr", "qi", "qg", "qs"]

# loop over variables 1
for var in var_for_modif_list1:
   dum=f1[var][:]
   dum=dum/2.       #modify
   f1[var][:]=dum   #overwrite
   del(dum)

# loop over variables 2
for var in var_for_modif_list2:
   dum=f1[var][:]
   dum=dum*3.       #modify
   f1[var][:]=dum   #overwrite
   del(dum)


# close file and quit
f1.close()
quit()
EOF

#execute the script
python modify_cor.py
