#!/usr/bin/bash

# For reliable, robust and maintainable bash scripts, start with following commands
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

#########################################################################################
# HEADER
#########################################################################################
#% 
#% DESCRIPTION
#
#% This bash file that stiches together the preprocessing steps for RNA-seq sequences
#% from 3'RNA-seq project.
#% 
#% USAGE and EXAMPLE
#% sh ${SCRIPT_NAME} [-h] inputs
#% ./${SCRIPT_NAME} [-h]  inputs
#% 
#% OPTIONS
#% inputs:    Folder containing all raw sequence FASTQ files, this will be updated in the
#%            next version
#
#% NOTE: Care should be taken to supply full or relative path to the script file (this
#%       file) and input folder.
#% 
# ---------------------------------------------------------------------------------------
#+ SCRIPT INFORMATION
#
#+ VERSION: 0.0.2
#+ AUTHOR:  Akshay Paropkari
#+ LICENSE: MIT
#
# ---------------------------------------------------------------------------------------
#% REFERENCES
#
#% 1. BBTools Suite - https://jgi.doe.gov/data-and-tools/bbtools/
#% 2. FastQC - http://www.bioinformatics.babraham.ac.uk/projects/fastqc/
#% 3. STAR - manual: https://github.com/alexdobin/STAR/blob/master/doc/STARmanual.pdf
#% 4. featureCounts - http://bioinf.wehi.edu.au/featureCounts/
#% 
#########################################################################################
# END_HEADER
#########################################################################################

# Help output
#== needed variables ==#
SCRIPT_HEADSIZE=$(head -50 "${0}" |grep -n "^# END_HEADER" | cut -f1 -d:)
SCRIPT_NAME=$(basename "${0}")

#== usage functions ==#
usagefull() { head -"${SCRIPT_HEADSIZE}" "${0}"| grep -e "^#%" | sed -e "s/^#[%+]\ //g" -e "s/\${SCRIPT_NAME}/${SCRIPT_NAME}/g" ; }
scriptinfo() { head -"${SCRIPT_HEADSIZE}" "${0}" | grep -e "^#+" | sed -e "s/^#+\ //g" -e "s/\${SCRIPT_NAME}/${SCRIPT_NAME}/g"; }

if [[ "$1" = "-h" ]] || [[ "$1" = "--help" ]] ; then
    usagefull
    scriptinfo
    exit 0
fi


# Testing for input
if [[ -z "$1" ]] ; then
    date '+%a %D %r'
    echo 'Input folder not supplied. Exiting program.'
    exit 1
fi


# Changing working directory to input folder
dir=$1
printf "%s\n" "$dir"    # print the folder name which is being processed
# cd into each folder in the directory
cd "$dir" || { echo "cd into input folder failed! Please check your working directory." ; exit 1 ; }


# Starting preprocessing
for f in *001.fastq
do

  in_file=$(basename "$f")

  echo -e "\e[1;4mProcessing $in_file\e[0m"
  echo

  # •••••••••••••••••••••••••••••••••• #
  # Step 1: Adapter and polyA trimming #
  # •••••••••••••••••••••••••••••••••• #

  date '+%a %D %r'; echo -e '\e[4mAdapter and polyA trimming\e[0m'

  # Create output file name and command to run
  trimmed_file=$(basename "$f" .fastq)_trimmed.fastq
  CMD1="bbduk.sh in=$in_file out=$trimmed_file ref=/home/aparopkari/bbmap/resources/polyA.fa.gz,/home/aparopkari/bbmap/resources/truseq.fa.gz k=13 ktrim=r useshortkmers=t mink=5 qtrim=r trimq=10 minlength=20 > $(basename "$f" .fastq)_trimmed.log"

  # Echo and run command
  echo "$CMD1"
  $CMD1
  echo

  # •••••••••••••••••••••••••••••••••••••••••••••••••••••••••••• #
  # Step 2: Fastqc generates a report of sequencing read quality #
  # •••••••••••••••••••••••••••••••••••••••••••••••••••••••••••• #

  date '+%a %D %r'; echo -e '\e[4mRead quality assessment\e[0m'

  # Create directory to save the quality reports, one per FASTQ file and create command to run
  mkdir -p "$(basename "$f" .fastq)"_qc
  CMD2="fastqc -t 20 --nogroup -o $(basename "$f" .fastq)_qc $trimmed_file"

  # Echo and run command
  echo "$CMD2"
  $CMD2
  echo

  # •••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••• #
  # Step 3: STAR aligns and counts the trimmed reads to the reference genome #
  # •••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••• #

  date '+%a %D %r'; echo -e '\e[4mAligning QC reads to Candida albicans A21 genome\e[0m'

  # Create command to run
  CMD3="STAR --runThreadN 19 --genomeDir /home/aparopkari/rnaseq_pipeline/ca21_genome_index/ --readFilesIn $trimmed_file --outFilterType BySJout --outFilterMultimapNmax 50 --alignSJoverhangMin 8 --alignSJDBoverhangMin 1 --outFilterMismatchNmax 999 --outFilterMismatchNoverLmax 0.6 --alignIntronMin 20 --alignIntronMax 1000000 --alignMatesGapMax 1000000 --outSAMattributes NH HI NM MD --outSAMtype BAM SortedByCoordinate --quantMode GeneCounts --outFileNamePrefix $(basename "$f" .fastq) > $(basename "$f" .fastq)_alignment.log"

  # Echo and run command
  echo "$CMD3"
  $CMD3
  echo


#########################  REPLACED WITH “STAR” GENE COUNTING  ###########################
#   •••••••••••••••••••••••••••••••••••••••• #
#   Step 4: Read counting with featureCounts #
#   •••••••••••••••••••••••••••••••••••••••• #
# 
#   date '+%a %D %r'; echo -e '\e[4mGetting read counts for aligned reads\e[0m'
# 
#   Get .bam file from previous step and create command to run
#   bam_file=$(basename $in_file .fastq)Aligned.sortedByCoord.out.bam
#   CMD4="featureCounts -a /home/aparopkari/rnaseq_pipeline/C_albicans_SC5314_A22_current_features.gtf -t CDS -g gene_id -T 20 -o $(basename "$f" .fastq)_counts.txt $bam_file > $(basename "$f" .fastq)_counts.log"
#   
#   Echo and run command
#   echo “$CMD4”
#   $CMD4
#   echo
#########################  END REPLACED WITH “STAR” GENE COUNTING  #######################
done
