#!/bin/bash

# Default parameters
SRA_ID=""
BIN_SIZE=0

# Function to display help
function show_help() {
    echo "Usage: $0 --sra_id <SRA_ID> --bin_size <BIN_SIZE>"
    echo
    echo "Description: This script subsets orientations from .pairs.gz files and creates .cool files."
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

# Step 1: Subsetting orientations
echo "Subsetting orientations..."

declare -A ORIENTATIONS=(
    ["inward"]="((strand1 == '+') & (strand2 == '+'))"
    ["outward"]="((strand1 == '+') & (strand2 == '-'))"
    ["tandem-entry"]="((strand1 == '-') & (strand2 == '+'))"
    ["tandem-exit"]="((strand1 == '-') & (strand2 == '-'))"
)

subset_orientation() {
    local ORIENTATION_NAME=$1
    local CONDITION=$2
    local OUTPUT_FILE="input/pairs/${SRA_ID}_${ORIENTATION_NAME}.pairs.gz"

    echo "Subsetting ${ORIENTATION_NAME} orientation..."
    pairtools select "${CONDITION}" -o ${SRA_ID}/${OUTPUT_FILE} ${SRA_ID}/input/pairs/${SRA_ID}_filtered.pairs.gz
    if [ $? -ne 0 ]; then
        echo "Error selecting ${ORIENTATION_NAME} interactions for $SRA_ID. Exiting."
        exit 1
    fi
    echo "Successfully created ${ORIENTATION_NAME} pairs: ${OUTPUT_FILE}"
}

for ORIENTATION_NAME in "${!ORIENTATIONS[@]}"; do
    subset_orientation "${ORIENTATION_NAME}" "${ORIENTATIONS[$ORIENTATION_NAME]}"
done

# Step 2: Create .cool files
echo "Creating .cool files for all orientations with bin size ${BIN_SIZE}..."

create_cool_file() {
    local INPUT_FILE=$1
    local OUTPUT_FILE=$2

    echo "Creating .cool file for ${INPUT_FILE}..."
    cooler cload pairs \
        --chrom1 2 \
        --pos1 3 \
        --chrom2 4 \
        --pos2 5 \
        ${SRA_ID}/input/chromosome.sizes:${BIN_SIZE} \
        ${INPUT_FILE} \
        ${OUTPUT_FILE}
    if [ $? -ne 0 ]; then
        echo "Error creating .cool file for ${INPUT_FILE}. Exiting."
        exit 1
    fi
    echo "Successfully created .cool file: ${OUTPUT_FILE}"
}

# Process the main filtered file
create_cool_file "input/pairs/${SRA_ID}_filtered.pairs.gz" "input/cooler/${SRA_ID}_filtered_${BIN_SIZE}.cool"

# Process all orientation files
for ORIENTATION_NAME in "${!ORIENTATIONS[@]}"; do
    INPUT_FILE="${SRA_ID}/input/pairs/${SRA_ID}_${ORIENTATION_NAME}.pairs.gz"
    OUTPUT_FILE="${SRA_ID}/input/cooler/${SRA_ID}_${ORIENTATION_NAME}_${BIN_SIZE}.cool"
    create_cool_file "${INPUT_FILE}" "${OUTPUT_FILE}"
done

echo "Completed creating .cool files for ${SRA_ID}!"