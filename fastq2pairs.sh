#!/bin/bash

# Default values for parameters
SRA_ID=""
THREADS=4

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --sra_id) SRA_ID="$2"; shift ;;
        --threads) THREADS="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Check if SRA_ID is provided
if [ -z "$SRA_ID" ]; then
    echo "Error: --sra_id is required."
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

# Step 3: Download the reference genome
echo "Downloading reference genome sacCer3..."
genomepy install sacCer3
if [ $? -ne 0 ]; then
    echo "Error downloading reference genome sacCer3. Exiting."
    exit 1
fi

# Step 4: Build the Bowtie2 index
echo "Building Bowtie2 index for sacCer3..."
bowtie2-build ~/sacCer/sacCer3.fa sacCer3
if [ $? -ne 0 ]; then
    echo "Error building Bowtie2 index for sacCer3. Exiting."
    exit 1
fi

# Step 5: Remove adaptors with Cutadapt
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
echo "Trimming reads to fixed length (35bp) with Cutadapt..."
cutadapt -l 35 \
         -o ${SRA_ID}_input_1.fastq.gz \
         -p ${SRA_ID}_input_2.fastq.gz \
         intermediate_${SRA_ID}_1.fastq.gz intermediate_${SRA_ID}_2.fastq.gz \
         -j $THREADS \
         --json=${SRA_ID}_fixed_length.cutadapt.json
if [ $? -ne 0 ]; then
    echo "Error during fixed-length trimming for $SRA_ID. Exiting."
    exit 1
fi

# Step 6: Alignment with bowtie2 
echo "Running Bowtie2 alignment..."
bowtie2 -x sacCer \
        -1 ${SRA_ID}_input_1.fastq.gz \
        -2 ${SRA_ID}_input_2.fastq.gz \
        -S ${SRA_ID}.sam \
        --very-sensitive-local \
        -p $THREADS
if [ $? -ne 0 ]; then
    echo "Error during Bowtie2 alignment for $SRA_ID. Exiting."
    exit 1
fi


# Step 7: Extract chromosome sizes directly from SAM file
echo "Extracting chromosome sizes from SAM file..."
grep '^@SQ' ${SRA_ID}.sam > temp_sizes.txt
awk '{for(i=1;i<=NF;i++){if($i ~ /^SN:/){name=substr($i,4)}; if($i ~ /^LN:/){length=substr($i,4)} }; print name "\t" length}' temp_sizes.txt > chromosome.sizes
if [ $? -ne 0 ]; then
    echo "Error extracting chromosome sizes from SAM file for $SRA_ID. Exiting."
    exit 1
fi
rm temp_sizes.txt


# Step 8: Parsing alignment to ligation events
echo "Parsing alignment to ligation events..."
pairtools parse2 -c chromosome.sizes \
                 -o ${SRA_ID}_parsed2.pairs.gz \
                 --max-insert-size 150 \
                 --drop-sam \
                 --drop-seq \
                 --output-parsed-alignments ${SRA_ID}_analysis.stats \
                 --output-stats ${SRA_ID}_output.stats \
                 ${SRA_ID}.sam
if [ $? -ne 0 ]; then
    echo "Error parsing ligation events for $SRA_ID. Exiting."
    exit 1
fi

# Step 9: Parsing alignment to ligation events
echo "Sorting ligation events..."
pairtools sort -o ${SRA_ID}_sorted.pairs.gz \
               --nproc $THREADS \
               --tmpdir=./ \
               ${SRA_ID}_parsed2.pairs.gz
if [ $? -ne 0 ]; then
    echo "Error sorting ligation events for $SRA_ID. Exiting."
    exit 1
fi

# Step 10: Detecting PCR duplications
echo "Detecting PCR duplications..."
pairtools dedup --mark dedup \
                ${SRA_ID}_sorted.pairs.gz \
                -o ${SRA_ID}_dedup.pairs.gz
if [ $? -ne 0 ]; then
    echo "Error detecting PCR duplications for $SRA_ID. Exiting."
    exit 1
fi

# Step 11: Selecting unique-unique ligation events
echo "Selecting unique-unique ligation events..."
pairtools select '(pair_type == "UU")' \
                 -o ${SRA_ID}_filtered.pairs.gz \
                 ${SRA_ID}_dedup.pairs.gz
if [ $? -ne 0 ]; then
    echo "Error selecting unique-unique ligation events for $SRA_ID. Exiting."
    exit 1
fi

echo "Completed preprocessing for ${SRA_ID}!"