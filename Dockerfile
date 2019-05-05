# nvidia/cuda
# https://hub.docker.com/r/nvidia/cuda
FROM nvidia/cuda:10.0-devel-ubuntu18.04 

LABEL maintainer="Timothy Liu <timothyl@nvidia.com>"

USER root

ENV DEBIAN_FRONTEND noninteractive

# Install all OS dependencies

COPY sources.list /etc/apt/

RUN apt-get update && \
    apt-get install -yq --no-install-recommends --no-upgrade \
    apt-utils && \
    apt-get install -yq --no-install-recommends --no-upgrade \
    curl \
    wget \
    bzip2 \
    ca-certificates \
    locales \
    fonts-liberation \
    build-essential \
    cmake \
    inkscape \
    jed \
    libsm6 \
    libxext-dev \
    libxrender1 \
    lmodern \
    netcat \
    pandoc \
    texlive-fonts-recommended \
    texlive-generic-recommended \
    texlive-latex-base \
    texlive-latex-extra \
    texlive-xetex \
    ffmpeg \
    graphviz\
    git \
    nano \
    vim \
    emacs \
    htop \
    zip \
    unzip \
    libncurses5-dev \
    libncursesw5-dev \
    libopenmpi-dev \
    libopenblas-base \
    libopenblas-dev \
    libomp-dev \
    libjpeg-dev \
    libpng-dev \
    libboost-all-dev \
    libsdl2-dev \
    openssh-client \
    openssh-server \
    swig \
    pkg-config \
    g++ \
    zlib1g-dev \
    protobuf-compiler \
    libosmesa6-dev \
    patchelf \
    xvfb \
    zsh \
    sudo \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

RUN apt-get update && \
    apt-get install --allow-change-held-packages -yq \
    libcudnn7 \
    libcudnn7-dev \
    libnccl2 \
    libnccl-dev && \
    apt-get clean && \
    ldconfig && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# Configure environment

ENV CONDA_DIR=/opt/conda \
    SHELL=/bin/bash \
    NB_USER=jovyan \
    NB_UID=1000 \
    NB_GID=100 \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8

ENV PATH=$CONDA_DIR/bin:$PATH \
    HOME=/home/$NB_USER

# script used to restore permissions after each step as root

ADD fix-permissions /usr/local/bin/fix-permissions

# Create jovyan user with UID=1000 and in the 'users' group
# and make sure these dirs are writable by the `users` group.

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \  
    groupadd wheel -g 11 && \
    echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su && \
    useradd -m -s /bin/bash -N -u $NB_UID $NB_USER && \
    mkdir -p $CONDA_DIR && \
    chown $NB_USER:$NB_GID $CONDA_DIR && \
    chmod g+w /etc/passwd && \
    fix-permissions /home/$NB_USER && \
    fix-permissions $CONDA_DIR

USER $NB_UID

RUN fix-permissions /home/$NB_USER

# Install conda as jovyan

ENV MINICONDA_VERSION 4.6.14

WORKDIR /home/$NB_USER

ADD requirements.txt requirements.txt

RUN wget --quiet https://repo.continuum.io/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    /bin/bash Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh -f -b -p $CONDA_DIR && \
    rm Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    $CONDA_DIR/bin/conda config --system --prepend channels conda-forge && \
    $CONDA_DIR/bin/conda config --system --set auto_update_conda false && \
    $CONDA_DIR/bin/conda config --system --set show_channel_urls true && \
    $CONDA_DIR/bin/conda install --quiet --yes conda="${MINICONDA_VERSION%.*}.*" && \
    $CONDA_DIR/bin/conda update --all --quiet --yes && \
    echo "Installing packages" && \
    conda install -n root conda-build && \
    conda install -c nvidia -c numba -c pytorch -c conda-forge -c rapidsai -c defaults  --quiet --yes \
    'python=3.6' \
    'cudatoolkit=10.0' \
    'tk' \
    'numpy>=1.16.1' \
    'numba>=0.41.0dev' \
    'pandas' \
    'blas=*=openblas' \
    'cython>=0.29' && \
    pip install --no-cache-dir -r /home/$NB_USER/requirements.txt && \
    rm /home/$NB_USER/requirements.txt && \
    pip uninstall opencv-python -y && \
    pip install --no-cache-dir opencv-contrib-python && \
    # Install Jupyter Notebook, Lab, and Hub
    conda install -c conda-forge --quiet --yes \
    'notebook=5.7.*' \
    'jupyterhub=0.9.*' \
    'jupyterlab=0.35.*' \
    'jupyter_contrib_nbextensions' \
    'ipywidgets=7.2*' && \
    pip install --no-cache-dir nbresuse jupyterthemes && \
    jupyter notebook --generate-config && \
    # Activate ipywidgets extension in the environment that runs the notebook server
    jupyter nbextension enable --py widgetsnbextension --sys-prefix && \
    jupyter serverextension enable --py nbresuse --sys-prefix && \
    jupyter nbextension install --py nbresuse --sys-prefix && \
    jupyter nbextension enable --py nbresuse --sys-prefix && \
    jupyter contrib nbextension install --sys-prefix && \
    # Also activate ipywidgets extension for JupyterLab
    jupyter labextension install @jupyter-widgets/jupyterlab-manager && \
    jupyter labextension install jupyterlab-topbar-extension && \
    jupyter labextension install jupyterlab-server-proxy && \
    jupyter labextension install jupyterlab-system-monitor && \
    pip install --no-cache-dir nbgitpuller && \
    jupyter serverextension enable --py nbgitpuller --sys-prefix && \
    jupyter labextension install @jupyterlab/hub-extension && \
    conda install --quiet --yes 'tini=0.18.0' && \
    conda list tini | grep tini | tr -s ' ' | cut -d ' ' -f 1,2 >> $CONDA_DIR/conda-meta/pinned && \
    conda clean -tipsy && \
    conda build purge-all && \
    npm cache clean --force && \
    rm -rf $CONDA_DIR/share/jupyter/lab/staging && \
    rm -rf /home/$NB_USER/.cache && \
    rm -rf /home/$NB_USER/.node-gyp && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# extras

# pytorch

RUN conda install -c pytorch pytorch torchvision cudatoolkit=10.0 --quiet --yes && \
    pip install --no-cache-dir torchtext pytorch-pretrained-bert && \
    conda install -c pytorch -c fastai fastai dataclasses && \
    conda clean -tipsy && \
    conda build purge-all && \
    rm -rf /home/$NB_USER/.cache && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# apex

RUN git clone --depth 1 https://github.com/NVIDIA/apex && \
    cd apex && \
    pip install -v --no-cache-dir \
     --global-option="--cpp_ext" --global-option="--cuda_ext" \
     . && \
    cd .. && rm -rf apex && \
    rm -rf /home/$NB_USER/.cache && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# facet

USER root

RUN cd /opt/ && git clone --depth 1 https://github.com/PAIR-code/facets

USER $NB_UID

RUN cd /opt/facets/ && jupyter nbextension install facets-dist/ --sys-prefix && \
    export PYTHONPATH=$PYTHONPATH:/opt/facets/facets_overview/python/ && \
    npm cache clean --force && \
    rm -rf $CONDA_DIR/share/jupyter/lab/staging && \
    rm -rf /home/$NB_USER/.cache && \
    rm -rf /home/$NB_USER/.node-gyp && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER


# nvtop

USER root

RUN cd /home/$NB_USER && \
    git clone https://github.com/Syllo/nvtop.git && \
    mkdir -p nvtop/build && cd nvtop/build && \
    cmake .. -DNVML_RETRIEVE_HEADER_ONLINE=True && \
    make && make install && \
    cd .. && rm -rf nvtop && \
    rm -rf /home/$NB_USER/.cache && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

USER $NB_UID

# RAPIDS

RUN pip install --no-cache-dir \
      dask-xgboost xgboost dask_labextension && \
    conda install -c nvidia/label/cuda10.0 -c rapidsai/label/cuda10.0 \
      -c numba -c conda-forge -c defaults \
      python=3.6 \
      dask \
      cudf \
      cuml \
      cugraph \
      dask-cuda \
      dask-cudf \
      dask-cuml \
      nvstrings && \
    pip uninstall pillow -y && \
      CC="cc -mavx2" pip install -U --force-reinstall --no-cache-dir pillow-simd && \
    jupyter labextension install dask-labextension && \
    conda clean -tipsy && \
    conda build purge-all && \
    npm cache clean --force && \
    rm -rf $CONDA_DIR/share/jupyter/lab/staging && \
    rm -rf /home/$NB_USER/.cache && \
    rm -rf /home/$NB_USER/.node-gyp && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# install our own build of TensorFlow

USER $NB_UID

ENV TENSORFLOW_URL=https://s3-ap-southeast-1.amazonaws.com/nvaitc/tensorflow_gpu-1.13.1%2Bnv-cp36-cp36m-linux_x86_64.whl \
    TENSORFLOW_FILENAME=tensorflow_gpu-1.13.1+nv-cp36-cp36m-linux_x86_64.whl

RUN cd /home/$NB_USER/ && \
    echo -c "Downloading ${TENSORFLOW_FILENAME} from ${TENSORFLOW_URL}" && \
    wget -O ${TENSORFLOW_FILENAME} ${TENSORFLOW_URL} && \
    pip install --no-cache-dir ${TENSORFLOW_FILENAME} && \
    pip install --no-cache-dir --ignore-installed PyYAML \
      jupyter-tensorboard \
      tensorflow-hub \
      tensorflow-data-validation \
      tensorflow-model-analysis \
      && \
    jupyter nbextension enable --py widgetsnbextension --sys-prefix && \
    jupyter nbextension install --py --symlink tensorflow_model_analysis --sys-prefix && \
    jupyter nbextension enable --py tensorflow_model_analysis --sys-prefix && \
    rm -rf /home/$NB_USER/${TENSORFLOW_FILENAME} && \
    jupyter tensorboard enable --sys-prefix && \
    jupyter labextension install jupyterlab_tensorboard && \
    npm cache clean --force && \
    rm -rf $CONDA_DIR/share/jupyter/lab/staging && \
    rm -rf /home/$NB_USER/.cache && \
    rm -rf /home/$NB_USER/.node-gyp && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# OpenMPI + Horovod

USER root

RUN mkdir /tmp/openmpi && \
    cd /tmp/openmpi && \
    wget https://www.open-mpi.org/software/ompi/v3.1/downloads/openmpi-3.1.2.tar.gz && \
    tar zxf openmpi-3.1.2.tar.gz && \
    cd openmpi-3.1.2 && \
    ./configure --enable-orterun-prefix-by-default && \
    make -j $(nproc) all && \
    make install && \
    ldconfig && \
    rm -rf /tmp/openmpi

RUN ldconfig /usr/local/cuda/targets/x86_64-linux/lib/stubs

ENV HOROVOD_GPU_ALLREDUCE=NCCL \
    HOROVOD_WITH_TENSORFLOW=1 \
    HOROVOD_WITH_PYTORCH=1

RUN pip install --no-cache-dir horovod && \
    rm -rf /home/$NB_USER/.cache && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

RUN ldconfig && \
    mv /usr/local/bin/mpirun /usr/local/bin/mpirun.real && \
    echo '#!/bin/bash' > /usr/local/bin/mpirun && \
    echo 'mpirun.real --allow-run-as-root "$@"' >> /usr/local/bin/mpirun && \
    chmod a+x /usr/local/bin/mpirun && \
    echo "hwloc_base_binding_policy = none" >> /usr/local/etc/openmpi-mca-params.conf && \
    echo "rmaps_base_mapping_policy = slot" >> /usr/local/etc/openmpi-mca-params.conf && \
    echo "btl_tcp_if_exclude = lo,docker0" >> /usr/local/etc/openmpi-mca-params.conf && \
    echo NCCL_DEBUG=INFO >> /etc/nccl.conf && \
    mkdir -p /var/run/sshd && \
    cat /etc/ssh/ssh_config | grep -v StrictHostKeyChecking > /etc/ssh/ssh_config.new && \
    echo "    StrictHostKeyChecking no" >> /etc/ssh/ssh_config.new && \
    mv /etc/ssh/ssh_config.new /etc/ssh/ssh_config

# autokeras

USER $NB_UID

RUN cd /home/$NB_USER && \
    git clone https://github.com/NVAITC/autokeras.git && \
    cd autokeras/ && python setup.py install && \
    cd .. && rm -rf autokeras && \
    rm -rf /home/$NB_USER/.cache && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# Import matplotlib the first time to build the font cache

USER root

ENV XDG_CACHE_HOME /home/$NB_USER/.cache/

RUN MPLBACKEND=Agg python -c "import matplotlib.pyplot" && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# end extras

EXPOSE 8888

WORKDIR $HOME

# Configure container startup

ENTRYPOINT ["tini", "-g", "--"]
CMD ["start-notebook.sh"]

# Add local files as late as possible to avoid cache busting

COPY user_setup /opt/user_setup
ENV USER_SETUP /opt/user_setup/setup.sh

COPY start.sh /usr/local/bin/
COPY start-notebook.sh /usr/local/bin/
COPY start-singleuser.sh /usr/local/bin/
COPY jupyter_notebook_config.py /etc/jupyter/

RUN fix-permissions /etc/jupyter/ && \
    usermod -s /bin/bash $NB_USER

# Switch back to jovyan to avoid accidental container runs as root

USER $NB_UID
