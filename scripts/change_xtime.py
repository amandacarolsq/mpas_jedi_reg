import glob
import argparse
from netCDF4 import Dataset
import numpy as np
import os
import sys

def main(ncfile):
    if not os.path.exists(ncfile):
        print(f"Arquivo '{ncfile}' não encontrado.")
        sys.exit(1)

    # Abre o arquivo NetCDF no modo leitura e escrita
    ds = Dataset(ncfile, mode='r+')

    # Verifica se o atributo existe
    if 'config_start_time' not in ds.ncattrs():
        print("Atributo global 'config_start_time' não encontrado.")
        ds.close()
        sys.exit(1)

    # Lê o atributo global
    config_start_time = ds.getncattr('config_start_time')
    print("config_start_time:", config_start_time)

    # Verifica se a variável xtime existe
    if 'xtime' not in ds.variables:
        print("Variável 'xtime' não encontrada no arquivo.")
        ds.close()
        sys.exit(1)

    xtime = ds.variables['xtime']
    print("xtime shape:", xtime.shape)

    # Prepara o novo conteúdo para xtime
    str_len = xtime.shape[1]
    valor_formatado = config_start_time.ljust(str_len)[:str_len]
    novo_xtime = np.array([list(valor_formatado)] * xtime.shape[0], dtype='S1')

    # Atualiza o conteúdo
    xtime[:, :] = novo_xtime

    ds.close()
    print("✅ xtime atualizado com sucesso!")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Atualiza a variável xtime com o valor do atributo global config_start_time."
    )
    parser.add_argument("Arquivo", nargs="?", help="Arquivo NetCDF a ser processado")
    args = parser.parse_args()

    if args.Arquivo:
        arquivo = args.Arquivo
    else:
        arquivos = glob.glob("*init.nc")
        if not arquivos:
            print("Nenhum arquivo '*init.nc' encontrado.")
            sys.exit(1)
        elif len(arquivos) > 1:
            print("Mais de um arquivo '*init.nc' encontrado. Especifique manualmente:")
            for f in arquivos:
                print(" -", f)
            sys.exit(1)
        else:
            arquivo = arquivos[0]
            print(f"Usando arquivo encontrado automaticamente: {arquivo}")

    main(arquivo)

