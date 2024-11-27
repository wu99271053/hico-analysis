#!/bin/bash

# Function to display help
show_help() {
    echo "Usage: $0 --sra_id <SRA_ID> --bin_size <BIN_SIZE> --threads <THREADS>"
    echo
    echo "Description: Orchestrates the entire Hi-C data preprocessing pipeline."
    echo "Options:"
    echo "  --sra_id        The SRA ID to process (required)."
    echo "  --bin_size      Bin size for cooler cload (default: 128)."
    echo "  --threads       Number of threads to use (default: 4)."
    echo "  -h, --help      Show this help message and exit."
    echo
    echo "Example:"
    echo "  bash $0 --sra_id SRR1951777 --bin_size 128 --threads 8"
}

# Default parameters
SRA_ID=""
BIN_SIZE=128
THREADS=4

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --sra_id) SRA_ID="$2"; shift ;;
        --bin_size) BIN_SIZE="$2"; shift ;;
        --threads) THREADS="$2"; shift ;;
        -h|--help) show_help; exit 0 ;;
        *) echo "Unknown parameter passed: $1"; show_help; exit 1 ;;
    esac
    shift
done

# Validate input
if [ -z "$SRA_ID" ]; then
    echo "Error: --sra_id is required."
    show_help
    exit 1
fi

# Function to create necessary directories
create_directories() {
    echo "Creating directories for ${SRA_ID}..."
    mkdir -p ${SRA_ID}/{cooler,fastq,npz,pairs,stats}
}

# Step 1: Create directories
create_directories

# Step 2: Call fastq processing script
echo "Starting fastq processing..."
bash scripts/1_empty2fastq.sh --sra_id ${SRA_ID} --threads ${THREADS}
if [ $? -ne 0 ]; then
    echo "Error during fastq processing for ${SRA_ID}. Exiting."
    exit 1
fi

# Step 3: Call fastq to sam processing script
echo "Starting fastq to sam conversion..."
bash scripts/2_fastq2bam.sh --sra_id ${SRA_ID} --threads ${THREADS}
if [ $? -ne 0 ]; then
    echo "Error during fastq to sam conversion for ${SRA_ID}. Exiting."
    exit 1
fi

# Step 4: Call sam to pairs processing script
echo "Starting sam to pairs processing..."
bash scripts/3_bam2pairs.sh --sra_id ${SRA_ID} --threads ${THREADS}
if [ $? -ne 0 ]; then
    echo "Error during sam to pairs processing for ${SRA_ID}. Exiting."
    exit 1
fi

# Step 5: Call pairs to cooler processing script
echo "Starting pairs to cooler processing..."
bash scripts/4_pairs2mcool.sh --sra_id ${SRA_ID} --bin_size ${BIN_SIZE}
if [ $? -ne 0 ]; then
    echo "Error during pairs to cooler processing for ${SRA_ID}. Exiting."
    exit 1
fi

# Step 6: Call Python script to process cooler to npz
echo "Converting cooler to npz..."
python3 scripts/5_mcool2npz.py --sra_id ${SRA_ID}
if [ $? -ne 0 ]; then
    echo "Error converting cooler to npz for ${SRA_ID}. Exiting."
    exit 1
fi

echo "Pipeline completed successfully for ${SRA_ID}!"