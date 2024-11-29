#!/bin/bash

# Default values for parameters
SRA_ID=""
THREADS=4

# Function to display help
function show_help() {
    echo "Usage: $0 --sra_id <SRA_ID> [--threads <NUM_THREADS>]"
    echo
    echo "Description: This script processes SAM files to generate parsed and deduplicated .pairs files."
    echo "Options:"
    echo "  --sra_id        The SRA ID to process (required)."
    echo "  --threads       Number of threads to use for sorting and deduplication (default: 4)."
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

# Extract chromosome sizes directly from BAM file
echo "Extracting chromosome sizes from BAM file header..."

samtools view -H ${SRA_ID}/${SRA_ID}.bam | grep '^@SQ' | \
sed -n 's/.*SN:\([^[:space:]]*\).*LN:\([^[:space:]]*\).*/\1\t\2/p' > ${SRA_ID}/chromosome.sizes

if [ $? -ne 0 ]; then
    echo "Error extracting chromosome sizes from BAM file for $SRA_ID. Exiting."
    exit 1
fi

echo "Chromosome sizes extracted successfully for $SRA_ID!"


# Parsing, sorting, deduplication

echo "parsing alignment into ligation event."
echo "Processing BAM file to pairs for ${SRA_ID}..."
pairtools parse2 -c ${SRA_ID}/chromosome.sizes \
                 --max-insert-size 150 \
                 --drop-sam \
                 --drop-seq \
                 --output-parsed-alignments ${SRA_ID}/${SRA_ID}_analysis.stats \
                 --output-stats ${SRA_ID}/${SRA_ID}_parse.stats \
                 ${SRA_ID}/${SRA_ID}.bam | \
pairtools sort --nproc $THREADS --tmpdir=./ | \
pairtools dedup --output-stats ${SRA_ID}/${SRA_ID}_dedup.stats | \
pairtools select '(pair_type == "UU")' \
                 -o ${SRA_ID}/${SRA_ID}.pairs.gz

if [ $? -ne 0 ]; then
    echo "Error processing pairs for ${SRA_ID}. Exiting."
    exit 1
fi

# Final Output
echo "Completed preprocessing for ${SRA_ID}!"

