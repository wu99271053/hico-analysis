# Use a lightweight base image
FROM ubuntu:20.04

# Set environment variables
ENV PATH=/miniconda3/bin:$PATH
ENV DEBIAN_FRONTEND=noninteractive

# Install wget and other required packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    bash \
    bzip2 \
    && rm -rf /var/lib/apt/lists/*

# Download and install Miniconda
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh --no-check-certificate && \
    bash /tmp/miniconda.sh -b -p /miniconda3 && \
    rm /tmp/miniconda.sh && \
    /miniconda3/bin/conda init bash

# Set up conda environment and install tools
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
    samtools \
    && /miniconda3/bin/conda clean -a -y

# Set the default shell
SHELL ["/bin/bash", "-c"]

# Activate Conda by default when starting the container
RUN echo "source /miniconda3/bin/activate" >> ~/.bashrc

# Set default command to launch Bash
CMD ["/bin/bash"]