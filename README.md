# HiCO-Analysis Pipeline

This repository contains scripts and tools for analyzing Hi-C data, from preprocessing raw reads to generating cooler files and multi-resolution `.mcool` files for downstream analysis.

---

## Installation Instructions

### **Option 1: Install Required Packages via Conda**

1. **Create and activate the Conda environment:**
   ```bash
   conda create -n hico-analysis
   conda activate hico-analysis
   conda install -c bioconda -c conda-forge \
    cutadapt bowtie2 pairtools cooler sra-tools genomepy samtools



2. **Create and activate the Conda environment:**

git clone https://github.com/<your-repo>/hico-analysis.git
cd hico-analysis
bash scripts/run.sh --sra_id SRR6017984


Optional **run the docker image:**
docker pull --platform linux/amd64 tarnishederic/hico-analysis:latest           
docker run -it --rm tarnishederic/hico-analysis:latest
