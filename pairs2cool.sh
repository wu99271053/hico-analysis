#!/bin/bash

# Parameters
SRA_ID=$1
BIN_SIZE=$2

# Step 1: Subsetting orientations
echo "Subsetting orientations..."

declare -A ORIENTATIONS=(
    ["inward"]="((strand1 == '+') & (strand2 == '+'))"
    ["outward"]="((strand1 == '+') & (strand2 == '-'))"
    ["tandem-entry"]="((strand1 == '-') & (strand2 == '+'))"
    ["tandem-exit"]="((strand1 == '-') & (strand2 == '-'))"
)

subset_orientation() {
    ORIENTATION_NAME=$1
    CONDITION=$2
    OUTPUT_FILE=${SRA_ID}_${ORIENTATION_NAME}.pairs.gz

    echo "Subsetting ${ORIENTATION_NAME} orientation..."
    pairtools select "${CONDITION}" -o ${OUTPUT_FILE} ${SRA_ID}_filtered.pairs.gz
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
    INPUT_FILE=$1
    OUTPUT_FILE=$2

    echo "Creating .cool file for ${INPUT_FILE}..."
    cooler cload pairs \
        --chrom1 2 \
        --pos1 3 \
        --chrom2 4 \
        --pos2 5 \
        genomes/sacCer3.chrom.sizes:${BIN_SIZE} \
        ${INPUT_FILE} \
        ${OUTPUT_FILE}
    if [ $? -ne 0 ]; then
        echo "Error creating .cool file for ${INPUT_FILE}. Exiting."
        exit 1
    fi
    echo "Successfully created .cool file: ${OUTPUT_FILE}"
}

# Process the main filtered file
create_cool_file "${SRA_ID}_filtered.pairs.gz" "${SRA_ID}_filtered_${BIN_SIZE}.cool"

# Process all orientation files
for ORIENTATION_NAME in "${!ORIENTATIONS[@]}"; do
    INPUT_FILE=${SRA_ID}_${ORIENTATION_NAME}.pairs.gz
    OUTPUT_FILE=${SRA_ID}_${ORIENTATION_NAME}_${BIN_SIZE}.cool
    create_cool_file "${INPUT_FILE}" "${OUTPUT_FILE}"
done

echo "Completed creating .cool files for ${SRA_ID}!"