---------- README
---------- Diretório /mnt/beegfs/amanda.queiroz/mpas_jedi_reg/pre/meshes

--- Descrição:
Esta pasta contém os aquivos e utilitários necessários para a seleção e construção do domínio regional utilizado no MPAS-JEDI regional. Aqui definimos a geometria do domínio, selecionamos o arquivo de grade global (x1.${RES}.grid.nc) e geramos os arquivos de grade regionais. A pasta limited_area acompanha o create_region (executável necessário). O README.md vem do MPAS-Limited-Area que também explica sobre o create_region.

O MPAS-Limited-Area foi obtido pelo git:

git clone https://github.com/MPAS-Dev/MPAS-Limited-Area.git

--- Estrutura do diretório:
pre/meshes/

* points-examples/: exemplos de arquivos .pts para definição de regiões
* x1.163842.grid.nc: arquivo de grade global quase uniforme (60 km)
* create_region: executável para gerar o domínio regional
* pts/: arquivos .pts usados na prática

--- Exemplos de domínios:
Na pasta points-examples/ há modelos prontos para dierentes tipos de recorte:

* circular
* elliptical
* channel
* polygon

Esses exemplos servem como referência para criar o aquivo ${AREA}.pts para a sua região.

--- Arquivo estático gobal:
O arquivo x1.163842.static.nc é um estático global quase uniforme de 60 km, utilizado como base para extrair os campos "estáticos" do domínio regional. Ele foi previamente gerado em uma simulação global.

--- Arquivo de grade global: 
O arquivo x1.163842.grid.nc é um arquivo da grade global quase uniforme de 60 km que é a base para gerar o arquivo de grade regional para a área de interesse.

--- Geração do domínio regional:
Utilizamos o executável create_region para criar os arquivos de grade regionais.

./create_region ${AREA}.pts x1.163842.grid.nc

Arquivos gerados:

* ${AREA}.grid.nc
* ${AREA}.graph.info

Por fim, o módulo METIS é carregado e o gpmetis é feito de modo a criar arquivos de partição de malha para um número específico de tarefas. Assim, serão criados arquivos:

* ${AREA}.graph.info.part.128
* ${AREA}.graph.info.part.32
* ${AREA}.graph.info.part.256
* ${AREA}.graph.info.part.512

Esse arquivos estão dentro de /${AREA}

Esses arquivos são necessários para executar o modelo em paralelo.
