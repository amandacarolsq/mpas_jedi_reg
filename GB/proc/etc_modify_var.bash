#!/bin/bash

filename="mpas.stddev.nc"
include_hydrometeor=1  #1: yes, 2: no


if [ ${include_hydrometeor} -eq 1 ]; then
  var_for_modif_list='["stream_function", "velocity_potential", "temperature", "spechum", "surface_pressure", "qc", "qi", "qr", "qs", "qg"]'
else
  var_for_modif_list='["stream_function", "velocity_potential", "temperature", "spechum", "surface_pressure"]'
fi

cp ${filename} ${filename}_org

#write the python script
cat > modify_var.py << EOF
import numpy as np
from netCDF4 import Dataset  # http://code.google.com/p/netcdf4-python/

# set files to modify
fn = './${filename}'

# open file
f = Dataset(fn, "r+", format="NETCDF4") #Dataset is the class behavior to open the file

# variables to modify
var_for_modif_list = ${var_for_modif_list}

# loop over variables
for var in var_for_modif_list:
   dum=f[var][:]
   dum=dum/3.      #modify
   f[var][:]=dum   #overwrite
   del(dum)

# close file and quit
f.close()
quit()
EOF

#execute the script
python modify_var.py
