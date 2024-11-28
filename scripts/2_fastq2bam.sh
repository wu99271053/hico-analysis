#!/bin/bash

# Default values for parameters
SRA_ID=""
THREADS=4
MODE="--very-sensitive-local"  # Default mode for Bowtie2 alignment


# Function to display help
function show_help() {
    echo "Usage: $0 --sra_id <SRA_ID> [--threads <NUM_THREADS>]"
    echo
    echo "Description: This script processes trimmed FASTQ files and aligns them to the sacCer3 reference genome using Bowtie2."
    echo "Options:"
    echo "  --sra_id        The SRA ID to process (required)."
    echo "  --threads       Number of threads to use for alignment (default: 4)."
    echo "  --mode          Bowtie2 alignment mode (default: '--very-sensitive-local')."
    echo "  -h, --help      Show this help message and exit."
    echo
    echo "Example:"
    echo "  bash $0 --sra_id SRR1951777 --threads 8 --mode '--sensitive'"
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --sra_id) SRA_ID="$2"; shift ;;
        --threads) THREADS="$2"; shift ;;
        --mode) MODE="$2"; shift ;;
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

# Step 1: Download the reference genome
echo "Downloading reference genome sacCer3..."
genomepy install sacCer3 -g ${SRA_ID}/
if [ $? -ne 0 ]; then
    echo "Error downloading reference genome sacCer3. Exiting."
    exit 1
fi

# Step 2: Build the Bowtie2 index
echo "Building Bowtie2 index for sacCer3..."
bowtie2-build ./${SRA_ID}/sacCer3/sacCer3.fa ${SRA_ID}/sacCer3/sacCer3_index
if [ $? -ne 0 ]; then
    echo "Error building Bowtie2 index for sacCer3. Exiting."
    exit 1
fi

# Step 3: Alignment with Bowtie2 
echo "Running Bowtie2 alignment and converting directly to BAM..."

bowtie2 -x ${SRA_ID}/sacCer3/sacCer3_index \
        -1 ${SRA_ID}/fastq/${SRA_ID}_input_1.fastq.gz \
        -2 ${SRA_ID}/fastq/${SRA_ID}_input_2.fastq.gz \
        $MODE \
        -p $THREADS | \
samtools view -bhS  > ${SRA_ID}/${SRA_ID}.bam

if [ $? -ne 0 ]; then
    echo "Error during Bowtie2 alignment for $SRA_ID. Exiting."
    exit 1
fi

echo "Bowtie2 alignment and BAM conversion completed successfully for $SRA_ID!"


