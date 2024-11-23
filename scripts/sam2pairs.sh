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

# Step 7: Extract chromosome sizes directly from SAM file
echo "Extracting chromosome sizes from SAM file..."
grep '^@SQ' ${SRA_ID}/input/${SRA_ID}.sam > temp_sizes.txt
awk '{for(i=1;i<=NF;i++){if($i ~ /^SN:/){name=substr($i,4)}; if($i ~ /^LN:/){length=substr($i,4)} }; print name "\t" length}' temp_sizes.txt > ${SRA_ID}/input/chromosome.sizes
rm temp_sizes.txt

# Parsing, sorting, deduplication
pairtools parse2 -c ${SRA_ID}/input/chromosome.sizes \
                 -o ${SRA_ID}/input/pairs/${SRA_ID}_parsed2.pairs.gz \
                 --max-insert-size 150 \
                 --drop-sam \
                 --drop-seq \
                 --output-parsed-alignments ${SRA_ID}/stats/${SRA_ID}_analysis.stats \
                 --output-stats ${SRA_ID}/stats/${SRA_ID}_output.stats \
                 ${SRA_ID}/input/${SRA_ID}.sam
                
if [ $? -ne 0 ]; then
    echo "Error parsing ligation events for $SRA_ID. Exiting."
    exit 1
fi

# Step 9: Sorting ligation events
echo "Sorting ligation events..."
pairtools sort -o ${SRA_ID}/input/pairs/${SRA_ID}_sorted.pairs.gz \
               --nproc $THREADS \
               --tmpdir=./ \
               ${SRA_ID}/input/pairs/${SRA_ID}_parsed2.pairs.gz
if [ $? -ne 0 ]; then
    echo "Error sorting ligation events for $SRA_ID. Exiting."
    exit 1
fi

# Step 10: Detecting PCR duplications
echo "Detecting PCR duplications..."
pairtools dedup --mark dedup \
                ${SRA_ID}/input/pairs/${SRA_ID}_sorted.pairs.gz \
                -o ${SRA_ID}/input/pairs/${SRA_ID}_dedup.pairs.gz
if [ $? -ne 0 ]; then
    echo "Error detecting PCR duplications for $SRA_ID. Exiting."
    exit 1
fi

# Step 11: Selecting unique-unique ligation events
echo "Selecting unique-unique ligation events..."
pairtools select '(pair_type == "UU")' \
                 -o ${SRA_ID}/input/pairs/${SRA_ID}_filtered.pairs.gz \
                 ${SRA_ID}/input/pairs/${SRA_ID}_dedup.pairs.gz
if [ $? -ne 0 ]; then
    echo "Error selecting unique-unique ligation events for $SRA_ID. Exiting."
    exit 1
fi


# Final Output
echo "Completed preprocessing for ${SRA_ID}!"
echo "Output files:"
echo "  Parsed pairs: ${SRA_ID}_parsed2.pairs.gz"
echo "  Sorted pairs: ${SRA_ID}_sorted.pairs.gz"
echo "  Deduplicated pairs: ${SRA_ID}_dedup.pairs.gz"
echo "  Filtered pairs: ${SRA_ID}_filtered.pairs.gz"
echo "  Stats: ${SRA_ID}_parsed.stats, ${SRA_ID}_output.stats"
