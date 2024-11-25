#!/bin/bash

# Default values for parameters
# Default values for parameters
SRA_ID=""
THREADS=4
TRIM_LENGTH=35  # Default trimming length

# Function to create directories

# Function to display help
function show_help() {
    echo "Usage: $0 --sra_id <SRA_ID> [--threads <NUM_THREADS>] [--trim_length <LENGTH>]"
    echo "Description: This script downloads SRA data, converts it to FASTQ, and compresses the FASTQ files using pigz.
    the fastqs are trimmed pair-end style twice by cutadapt "
    echo "Options:"
    echo "  --sra_id        The SRA ID to process (required)."
    echo "  --threads       Number of threads to use (default: 4)."
    echo "  --trim_length   Length to trim reads to (default: 35)."
    echo "  -h, --help      Show this help message and exit."
    echo
    echo "Example:"
    echo "  bash $0 --sra_id SRR1951777 --threads 8 --trim_length 35"
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --sra_id) SRA_ID="$2"; shift ;;
        --threads) THREADS="$2"; shift ;;
        --trim_length) TRIM_LENGTH="$2"; shift ;;
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
prefetch $SRA_ID --max-size 420000000000
if [ $? -ne 0 ]; then
    echo "Error downloading $SRA_ID. Exiting."
    exit 1
fi

# Step 2: Convert SRA to FASTQ
echo "Converting SRA to FASTQ..."
fasterq-dump $SRA_ID -e $THREADS
if [ $? -ne 0 ]; then
    echo "Error converting $SRA_ID to FASTQ. Exiting."
    exit 1
fi

# Step 3: Compress FASTQ files using pigz
echo "Compressing FASTQ files for $SRA_ID using pigz..."
pigz -p $THREADS ${SRA_ID}_1.fastq
if [ $? -ne 0 ]; then
    echo "Error compressing ${SRA_ID}_1.fastq. Exiting."
    exit 1
fi

pigz -p $THREADS ${SRA_ID}_2.fastq
if [ $? -ne 0 ]; then
    echo "Error compressing ${SRA_ID}_2.fastq. Exiting."
    exit 1
fi


rm ${SRA_ID}_1.fastq

rm ${SRA_ID}_2.fastq
# Final output
echo "FASTQ files for $SRA_ID have been successfully downloaded, converted, and compressed using pigz."


# Step 4: Remove adaptors with Cutadapt
echo "Removing adaptors with Cutadapt..."
cutadapt -a AGATCGGAAGAGCACACGTCTGAACTCCAGTCA \
         -A AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT \
         -o intermediate_${SRA_ID}_1.fastq.gz \
         -p intermediate_${SRA_ID}_2.fastq.gz \
         ${SRA_ID}_1.fastq.gz ${SRA_ID}_2.fastq.gz \
         -e 0.2 -j $THREADS \
         --discard-untrimmed \
         --json=${SRA_ID}_adaptor_removal_report.cutadapt.json
if [ $? -ne 0 ]; then
    echo "Error during adaptor removal for $SRA_ID. Exiting."
    exit 1
fi

# Step 6: Trim reads to fixed length with Cutadapt
echo "Trimming reads to fixed length (${TRIM_LENGTH}bp) with Cutadapt..."
cutadapt -l $TRIM_LENGTH \
         -o ${SRA_ID}_input_1.fastq.gz \
         -L $TRIM_LENGTH \
         -p ${SRA_ID}_input_2.fastq.gz \
         intermediate_${SRA_ID}_1.fastq.gz intermediate_${SRA_ID}_2.fastq.gz \
         -j $THREADS \
         --json=${SRA_ID}_fixed_length.cutadapt.json
if [ $? -ne 0 ]; then
    echo "Error during fixed-length trimming for $SRA_ID. Exiting."
    exit 1
fi

mv ${SRA_ID}_1.fastq.gz ${SRA_ID}/fastq/
mv ${SRA_ID}_2.fastq.gz ${SRA_ID}/fastq/
mv intermediate_${SRA_ID}_1.fastq.gz ${SRA_ID}/fastq/
mv intermediate_${SRA_ID}_2.fastq.gz ${SRA_ID}/fastq/
mv ${SRA_ID}_input_1.fastq.gz ${SRA_ID}/fastq/
mv ${SRA_ID}_input_2.fastq.gz ${SRA_ID}/fastq/
mv ${SRA_ID}_adaptor_removal_report.cutadapt.json ${SRA_ID}/stats/
mv ${SRA_ID}_fixed_length.cutadapt.json ${SRA_ID}/stats/


echo "Adaptor removal and trimming completed successfully for $SRA_ID!"
echo "Final files are located in input/fastq, and statistics are in stats/."