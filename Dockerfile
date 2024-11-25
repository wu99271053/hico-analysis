# Use a lightweight base image (e.g., Ubuntu or Alpine)
FROM ubuntu:20.04

# Set environment variables
ENV PATH=/miniconda3/bin:$PATH

# Install wget and other required packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    bash \
    bzip2 \
    && rm -rf /var/lib/apt/lists/*

# Download and install Miniconda
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -u -p /miniconda3 && \
    rm /tmp/miniconda.sh && \
    /miniconda3/bin/conda init bash

# Set up conda environment initialization
RUN /miniconda3/bin/conda init && \
    echo "source /miniconda3/bin/activate" >> ~/.bashrc

# Activate conda by default
SHELL ["/bin/bash", "-c"]

RUN /miniconda3/bin/conda config --add channels defaults && \
    /miniconda3/bin/conda config --add channels bioconda && \
    /miniconda3/bin/conda config --add channels conda-forge && \
    /miniconda3/bin/conda install -y \
    cutadapt \
    bowtie2 \
    pairtools \
    cooler \
    sra-tools \
    genomepy \
    && /miniconda3/bin/conda clean -a -y

    

# Set the default shell
CMD ["/bin/bash"]