#!/bin/bash

# Default values for parameters
SRA_ID=""
THREADS=4

# Function to display help
function show_help() {
    echo "Usage: $0 --sra_id <SRA_ID> [--threads <NUM_THREADS>] [--trim_length <LENGTH>]"
    echo "Description: This script downloads SRA data, converts it to FASTQ, and compresses the FASTQ files using pigz.
    the fastqs are trimmed pair-end style twice by cutadapt "
    echo "Options:"
    echo "  --sra_id        The SRA ID to process (required)."
    echo "  --threads       Number of threads to use (default: 4)."
    echo "  -h, --help      Show this help message and exit."
    echo
    echo "Example:"
    echo "  bash $0 --sra_id SRR1951777 --threads 8"
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --sra_id) SRA_ID="$2"; shift ;;
        --threads) THREADS="$2"; shift ;;
        -h|--help) show_help; exit 0 ;;
        *) echo "Unknown parameter passed: $1"; show_help; exit 1 ;;
    esac
    shift
done

# Check if SRA_ID is provided
if [ -z "$SRA_ID" ]; then
    echo "Error: --sra_id is required."
    show_help
    exit 1
fi

# Informational output
echo "Processing SRA ID: $SRA_ID with $THREADS threads."

# Step 1: Download SRA data
echo "Downloading SRA data for $SRA_ID..."
prefetch $SRA_ID --max-size u
if [ $? -ne 0 ]; then
    echo "Error downloading $SRA_ID. Exiting."
    exit 1
fi

# Step 2: Convert SRA to FASTQ
echo "Converting SRA to FASTQ..."
# fasterq-dump $SRA_ID -e $THREADS -Z --split-spot 
# if [ $? -ne 0 ]; then
#     echo "Error converting $SRA_ID to FASTQ. Exiting."
#     exit 1
# fi
fasterq-dump --split-spot -e $threads -Z ${SRA_ID} | \
tee >(grep -A 3 '^@SRR.*\/1[[:space:]]' | pigz -p $threads -c > ${SRA_ID}_1.fastq.gz) \
   >(grep -A 3 '^@SRR.*\/2[[:space:]]' | pigz -p $threads -c > ${SRA_ID}_2.fastq.gz)

if [ $? -ne 0 ]; then
    echo "Error during fasterq-dump for $SRA_ID. Exiting."
    exit 1
fi

# Step 3: Remove adaptors with Cutadapt
echo "Removing hi-co adaptors with Cutadapt"
cutadapt -a ACTGCTGACGCTATGTACTCCCGCGGGAGTACATAGCGTCAGCAGT \
         -A ACTGCTGACGCTATGTACTCCCGCGGGAGTACATAGCGTCAGCAGT \
         -o ${SRA_ID}_input_1.fastq.gz \
         -p ${SRA_ID}_input_2.fastq.gz \
         ${SRA_ID}_1.fastq.gz ${SRA_ID}_2.fastq.gz \
         -e 0.2 -j ${THREADS} -m 16 -M 35 --discard-untrimmed \
         --json=${SRA_ID}_adaptor_removal_report.cutadapt.json

if [ $? -ne 0 ]; then
    echo "Error during adaptor removal for $SRA_ID. Exiting."
    exit 1
fi

# # Step 4: Compress FASTQ files using pigz
# echo "Compressing FASTQ files for $SRA_ID using pigz..."
# pigz -p $THREADS ${SRA_ID}_1.fastq
# if [ $? -ne 0 ]; then
#     echo "Error compressing ${SRA_ID}_1.fastq. Exiting."
#     exit 1
# fi

# pigz -p $THREADS ${SRA_ID}_2.fastq
# if [ $? -ne 0 ]; then
#     echo "Error compressing ${SRA_ID}_2.fastq. Exiting."
#     exit 1
# fi

# Final output
mv ${SRA_ID}_1.fastq.gz ${SRA_ID}/
mv ${SRA_ID}_2.fastq.gz ${SRA_ID}/
mv ${SRA_ID}_input_1.fastq.gz ${SRA_ID}/
mv ${SRA_ID}_input_2.fastq.gz ${SRA_ID}/
mv ${SRA_ID}_adaptor_removal_report.cutadapt.json ${SRA_ID}/

echo "Adaptor removal and trimming completed successfully for $SRA_ID!"
echo "Final files are located in input/fastq, and statistics are in stats/."