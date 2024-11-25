This is a pipeline for preprocessing hico data from fastq to npz, featuring sra-tools, genomepy, cutadapt, bowtie2, pairtools, cooler 

the pipeline could be run in default (SRR6471984) using the run.sh. or could be individually run using the respective script.

the hico data is comparatively larger than normal hi-c files. with keeping all the processed files. a 500 GB disk space is expected. fasterq-dump expect large disk space for holding tmp files and ask users to manualy compress the fastq file. for limited disk space user, use fastq-dump instead (seek to sratool documentation)

the sam file is huge (~200 gb). however the final product small in size.


docker image is provided for installing necessary package, it is also possible to install using the yml file

