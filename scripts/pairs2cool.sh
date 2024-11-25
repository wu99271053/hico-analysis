#!/bin/bash

# Default parameters
SRA_ID=""
BIN_SIZE=128

# Function to display help
function show_help() {
    echo "Usage: $0 --sra_id <SRA_ID> --bin_size <BIN_SIZE>"
    echo
    echo "Description: This script creates .cool files from .pairs.gz files and performs zoomify for multi-resolution aggregation."
    echo "Options:"
    echo "  --sra_id        The SRA ID to process (required)."
    echo "  --bin_size      Bin size for cooler cload (required)."
    echo "  -h, --help      Show this help message and exit."
    echo
    echo "Example:"
    echo "  bash $0 --sra_id SRR1951777 --bin_size 1000"
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --sra_id) SRA_ID="$2"; shift ;;
        --bin_size) BIN_SIZE="$2"; shift ;;
        -h|--help) show_help; exit 0 ;;
        *) echo "Unknown parameter passed: $1"; show_help; exit 1 ;;
    esac
    shift
done

# Validate input parameters
if [ -z "$SRA_ID" ] || [ "$BIN_SIZE" -le 0 ]; then
    echo "Error: --sra_id and --bin_size are required."
    show_help
    exit 1
fi

echo "Processing SRA ID: ${SRA_ID} with bin size: ${BIN_SIZE}"

# Step 1: Create .cool file
echo "Creating .cool file with bin size ${BIN_SIZE}..."
cooler cload pairs \
    --chrom1 2 \
    --pos1 3 \
    --chrom2 4 \
    --pos2 5 \
    ${SRA_ID}/chromosome.sizes:${BIN_SIZE} \
    ${SRA_ID}/pairs/${SRA_ID}_filtered.pairs.gz \
    ${SRA_ID}/cooler/${SRA_ID}_${BIN_SIZE}.cool
if [ $? -ne 0 ]; then
    echo "Error creating .cool file for ${SRA_ID}. Exiting."
    exit 1
fi
echo "Successfully created .cool file: ${SRA_ID}/cooler/${SRA_ID}_${BIN_SIZE}.cool"

# Step 2: Create multi-resolution .mcool file
echo "Creating multi-resolution .mcool file..."
cooler zoomify ${SRA_ID}/cooler/${SRA_ID}_${BIN_SIZE}.cool -o ${SRA_ID}/cooler/${SRA_ID}.mcool
if [ $? -ne 0 ]; then
    echo "Error during zoomify for ${SRA_ID}. Exiting."
    exit 1
fi
echo "Successfully created multi-resolution .mcool file: ${SRA_ID}/cooler/${SRA_ID}.mcool"

echo "cooler Processing completed for ${SRA_ID}!"