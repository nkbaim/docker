# docker build --no-cache -t openswath/develop:latest .
# docker push openswath/develop

FROM ubuntu:16.04

WORKDIR /code

#########################################
# Computational proteomics dependencies #
#########################################

# install base dependencies
RUN apt-get -y update
RUN apt-get install -y cmake g++ autoconf qt5-default libqt5svg5-dev patch libtool make git software-properties-common python3 wget default-jdk unzip bzip2 perl gnuplot xsltproc libgd-dev libpng12-dev zlib1g-dev libsvm-dev libglpk-dev libzip-dev zlib1g-dev libxerces-c-dev libbz2-dev libboost-all-dev libsqlite3-dev libexpat1-dev 

# patch Python
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# build TPP
WORKDIR /code
RUN wget https://sourceforge.net/projects/sashimi/files/Trans-Proteomic%20Pipeline%20%28TPP%29/TPP%20v5.1%20%28Syzygy%29%20rev%200/TPP_5.1.0-src.tgz
RUN tar xvf TPP_5.1.0-src.tgz
RUN rm TPP_5.1.0-src.tgz
WORKDIR TPP_5.1.0-src
RUN apt-get install -y libgsl-dev
RUN make extern 
RUN make spectrast PeptideProphetParser InterProphetParser ProteinProphet InteractParser RefreshParser PTMProphetParser xinteract
ENV PATH=$PATH:/code/TPP_5.1.0-src/build/gnu-x86_64/bin
WORKDIR /

# build Percolator
WORKDIR /code
RUN git clone https://github.com/percolator/percolator.git
WORKDIR /code/percolator
RUN cmake -DCMAKE_PREFIX_PATH="/usr/;/usr/local" .
RUN make -j4 && make install
WORKDIR /

# build mapDIA
WORKDIR /code
RUN wget https://sourceforge.net/projects/mapdia/files/mapDIA_v3.1.0.tar.gz
RUN tar xvf mapDIA_v3.1.0.tar.gz
RUN rm mapDIA_v3.1.0.tar.gz
WORKDIR mapDIA
RUN make -j4
ENV PATH=$PATH:/code/mapDIA/
WORKDIR /

# install DIA-Umpire
WORKDIR /code
RUN wget https://github.com/guoci/DIA-Umpire/releases/download/v2.1.3/v2.1.3.zip
RUN unzip v2.1.3.zip -d DIAU
RUN rm v2.1.3.zip
RUN chmod -R 755 /code/DIAU/v2.1.3/DIA_Umpire_SE.jar /code/DIAU/v2.1.3/DIA_Umpire_Quant.jar
ENV PATH=$PATH:/code/DIAU/v2.1.3
WORKDIR /

# install ProteoWizard
WORKDIR /code
RUN wget -O pwiz.tar.bz2 http://teamcity.labkey.org/guestAuth/app/rest/builds/id:614661/artifacts/content/pwiz-bin-linux-x86_64-gcc48-release-3_0_18225_42cece9.tar.bz2
RUN mkdir pwiz
RUN tar xvjf pwiz.tar.bz2 -C pwiz
RUN rm pwiz.tar.bz2
ENV PATH=$PATH:/code/pwiz/
WORKDIR /

# install R
WORKDIR /code
RUN apt-get install apt-transport-https
RUN printf "deb https://cloud.r-project.org/bin/linux/ubuntu xenial/" > /etc/apt/sources.list.d/backports.list
RUN apt-get update
RUN apt-get install -y --allow-unauthenticated r-base r-base-dev libcurl4-openssl-dev libssl-dev

RUN R -e "install.packages(c('RSQLite'), repos = 'http://cran.us.r-project.org')"
RUN R -e "install.packages(c('plyr'), repos = 'http://cran.us.r-project.org')"
RUN R -e "install.packages(c('devtools'), repos = 'http://cran.us.r-project.org')"
RUN R -e "install.packages(c('spData'), repos = 'http://cran.us.r-project.org')"
RUN R -e "install.packages(c('classInt'), repos = 'http://cran.us.r-project.org')"
RUN R -e "library(devtools); install_github('IFIproteomics/LFQbench')"

#############
# OpenSWATH #
#############

# build contrib
WORKDIR /code
RUN git clone https://github.com/OpenMS/contrib.git
RUN mkdir contrib_build

WORKDIR /code/contrib_build

RUN cmake -DBUILD_TYPE=COINOR ../contrib
RUN cmake -DBUILD_TYPE=SEQAN ../contrib
RUN cmake -DBUILD_TYPE=WILDMAGIC ../contrib
RUN cmake -DBUILD_TYPE=EIGEN ../contrib
RUN cmake -DBUILD_TYPE=KISSFFT ../contrib

# build OpenMS
WORKDIR /code
RUN git clone https://github.com/grosenberger/OpenMS.git --branch feature/osw_vartrans
RUN mkdir openms_build

WORKDIR /code/openms_build

RUN cmake -DOPENMS_CONTRIB_LIBS="/code/contrib_build/" -DCMAKE_PREFIX_PATH="/usr/;/usr/local" -DBOOST_USE_STATIC=OFF ../OpenMS
RUN make -j4
ENV PATH=$PATH:/code/openms_build/bin/

# build PyProphet
WORKDIR /code
RUN apt-get install -y python3-pip
RUN pip3 install pip --upgrade
RUN pip3 install numpy --upgrade
RUN pip3 install scipy --upgrade
RUN pip3 install cython --upgrade
RUN pip3 install git+https://github.com/grosenberger/pyprophet.git@feature/classifiers

# build msproteomicstools dependencies
WORKDIR /code
RUN apt-get install -y libxml2 libxml2-dev libxslt1-dev 
RUN git clone https://github.com/carljv/Will_it_Python.git
WORKDIR Will_it_Python/MLFH/CH2/lowess\ work/
RUN python3 setup.py build
RUN python3 setup.py install

RUN pip3 install jsonschema

# build msproteomicstools
WORKDIR /code
RUN git clone https://github.com/msproteomicstools/msproteomicstools.git
WORKDIR msproteomicstools
RUN python3 setup.py build --with_cython
RUN python3 setup.py install

# install Snakemake
WORKDIR /code
RUN pip3 install snakemake

WORKDIR /data/

# install pyOpenMS
WORKDIR /code
RUN pip3 install pyopenms

WORKDIR /data/
