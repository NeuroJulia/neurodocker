FROM ubuntu:17.04

ARG DEBIAN_FRONTEND=noninteractive

#----------------------------
# Install common dependencies
#----------------------------
RUN apt-get update -qq && apt-get install -yq --no-install-recommends bzip2 ca-certificates curl unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#-------------------------------------------------
# Install Miniconda, and set up Python environment
#-------------------------------------------------
ENV PATH=/opt/miniconda/envs/default/bin:$PATH
RUN echo "Downloading Miniconda installer ..." \
    && curl -sSL -o miniconda.sh https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && bash miniconda.sh -b -p /opt/miniconda \
    && rm -f miniconda.sh \
    && /opt/miniconda/bin/conda config --add channels conda-forge \
    && /opt/miniconda/bin/conda create -y -q -n default python=3.5.1 \
    	traits \
    && conda clean -y --all \
    && pip install -U -q --no-cache-dir pip \
    && pip install -q --no-cache-dir \
    	https://github.com/nipy/nipype/archive/master.tar.gz \
    && rm -rf /opt/miniconda/[!envs]*

#-------------------
# Install ANTs 2.2.0
#-------------------
RUN echo "Downloading ANTs ..." \
    && curl -sSL --retry 5 https://dl.dropbox.com/s/2f4sui1z6lcgyek/ANTs-Linux-centos5_x86_64-v2.2.0-0740f91.tar.gz \
    | tar zx -C /opt
ENV ANTSPATH=/opt/ants \
    PATH=/opt/ants:$PATH

#--------------------------
# Install FreeSurfer v6.0.0
#--------------------------
RUN apt-get update -qq && apt-get install -yq --no-install-recommends bc libgomp1 libxmu6 libxt6 tcsh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && echo "Downloading FreeSurfer ..." \
    && curl -sSL --retry 5 https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/6.0.0/freesurfer-Linux-centos6_x86_64-stable-pub-v6.0.0.tar.gz \
    | tar xz -C /opt \
    --exclude='freesurfer/trctrain' \
    --exclude='freesurfer/subjects/fsaverage_sym' \
    --exclude='freesurfer/subjects/fsaverage3' \
    --exclude='freesurfer/subjects/fsaverage4' \
    --exclude='freesurfer/subjects/fsaverage5' \
    --exclude='freesurfer/subjects/fsaverage6' \
    --exclude='freesurfer/subjects/cvs_avg35' \
    --exclude='freesurfer/subjects/cvs_avg35_inMNI152' \
    --exclude='freesurfer/subjects/bert' \
    --exclude='freesurfer/subjects/V1_average' \
    --exclude='freesurfer/average/mult-comp-cor' \
    --exclude='freesurfer/lib/cuda' \
    --exclude='freesurfer/lib/qt'
ENV FS_OVERRIDE=0 \
    OS=Linux \
    FSF_OUTPUT_FORMAT=nii.gz \
    FIX_VERTEX_AREA= \
    FREESURFER_HOME=/opt/freesurfer \
    MNI_DIR=/opt/freesurfer/mni \
    SUBJECTS_DIR=/subjects
ENV PERL5LIB=$MNI_DIR/share/perl5 \
    MNI_PERL5LIB=$MNI_DIR/share/perl5 \
    MINC_BIN_DIR=$MNI_DIR/bin \
    MINC_LIB_DIR=$MNI_DIR/lib \
    MNI_DATAPATH=$MNI_DIR/data \
    PATH=$FREESURFER_HOME/bin:$FREESURFER_HOME/tktools:$MNI_DIR/bin:$PATH
# Copy license file into image. Must be relative path within build context.
COPY ["rel/path/license.txt", "/opt/freesurfer/license.txt"]

#-----------------------------------------------
# Install FSL 5.0.10
# Please review FSL's license:
# https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/Licence
#-----------------------------------------------
RUN echo "Downloading FSL ..." \
    && curl -sSL https://fsl.fmrib.ox.ac.uk/fsldownloads/fsl-5.0.10-centos6_64.tar.gz \
    | tar zx -C /opt \
    && FSLPYFILE=/opt/fsl/etc/fslconf/fslpython_install.sh \
    && [ -f $FSLPYFILE ] && $FSLPYFILE -f /opt/fsl -q || true
ENV FSLDIR=/opt/fsl \
    PATH=/opt/fsl/bin:$PATH \
    FSLLOCKDIR= \
    FSLMACHINELIST= \
    FSLMULTIFILEQUIT=TRUE \
    FSLOUTPUTTYPE=NIFTI_GZ \
    FSLTCLSH=/opt/fsl/bin/fsltclsh \
    FSLWISH=/opt/fsl/bin/fslwish \
    LD_LIBRARY_PATH=/opt/fsl/lib/lib:$LD_LIBRARY_PATH \
    POSSUMDIR=/opt/fsl

#----------------
# Install MRtrix3
#----------------
WORKDIR /opt
RUN deps='g++ git libeigen3-dev zlib1g-dev' \
    && apt-get update -qq && apt-get install -yq --no-install-recommends $deps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && git clone https://github.com/MRtrix3/mrtrix3.git \
    && cd mrtrix3 \
    && ./configure -nogui \
    && ./build \
    && rm -rf tmp/* /tmp/* \
    && apt-get purge -y --auto-remove $deps
ENV PATH=/opt/mrtrix3/bin:$PATH

#---------------------------
# Add NeuroDebian repository
#---------------------------
RUN apt-get update -qq && apt-get install -yq --no-install-recommends dirmngr \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && curl -sSL http://neuro.debian.net/lists/zesty.us-nh.libre \
    > /etc/apt/sources.list.d/neurodebian.sources.list \
    && apt-key adv --recv-keys --keyserver hkp://pool.sks-keyservers.net:80 0xA5D32F012649A5A9 \
    && apt-get update \
    && apt-get purge -y --auto-remove dirmngr

# Install NeuroDebian packages
RUN apt-get update -qq && apt-get install -yq --no-install-recommends afni dcm2niix \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#----------------------
# Install MCR and SPM12
#----------------------
# Install required libraries
RUN apt-get update -qq && apt-get install -yq --no-install-recommends libxext6 libxt6 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install MATLAB Compiler Runtime
WORKDIR /opt
RUN echo "Downloading MATLAB Compiler Runtime ..." \
    && curl -sSL -o mcr.zip https://www.mathworks.com/supportfiles/downloads/R2017a/deployment_files/R2017a/installers/glnxa64/MCR_R2017a_glnxa64_installer.zip \
    && unzip -q mcr.zip -d mcrtmp \
    && mcrtmp/install -destinationFolder /opt/mcr -mode silent -agreeToLicense yes \
    && rm -rf mcrtmp mcr.zip /tmp/*

# Install standalone SPM
WORKDIR /opt
RUN echo "Downloading standalone SPM ..." \
    && curl -sSL -o spm.zip http://www.fil.ion.ucl.ac.uk/spm/download/restricted/utopia/dev/spm12_latest_Linux_R2017a.zip \
    && unzip -q spm.zip \
    && rm -rf spm.zip
ENV MATLABCMD=/opt/mcr/v*/toolbox/matlab \
    SPMMCRCMD="/opt/spm*/run_spm*.sh /opt/mcr/v*/ script" \
    FORCE_SPMMCR=1 \
    LD_LIBRARY_PATH=/opt/mcr/v*/runtime/glnxa64:/opt/mcr/v*/bin/glnxa64:/opt/mcr/v*/sys/os/glnxa64:$LD_LIBRARY_PATH


#--------------------------
# User-defined instructions
#--------------------------

RUN echo "Hello, World"

ENTRYPOINT ["run.sh"]
