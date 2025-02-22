#!/bin/bash
# J. Taroni for CCDL 2019
# Create subset files for continuous integration

set -e
set -o pipefail

# Set defaults for release and biospecimen file name
BIOSPECIMEN_FILE=${BIOSPECIMEN_FILE:-biospecimen_ids_for_subset.RDS}
RELEASE=${RELEASE:-release-v10-20191115}
NUM_MATCHED=${NUM_MATCHED:-15}

# This script should always run as if it were being called from
# the directory it lives in.
script_directory="$(perl -e 'use File::Basename;
  use Cwd "abs_path";
  print dirname(abs_path(@ARGV[0]));' -- "$0")"
cd "$script_directory" || exit

# directories that hold the full files for the release and the subset files
# generated via these scripts
FULL_DIRECTORY=../../data/$RELEASE
SUBSET_DIRECTORY=../../data/testing/$RELEASE

#### generate subset files -----------------------------------------------------

# get list of biospecimen ids for subset files
Rscript --vanilla 01-get_biospecimen_identifiers.R \
    --data_directory $FULL_DIRECTORY \
    --output_file $BIOSPECIMEN_FILE \
    --num_matched $NUM_MATCHED

# subset the files
Rscript --vanilla 02-subset_files.R \
  --biospecimen_file $BIOSPECIMEN_FILE \
  --output_directory $SUBSET_DIRECTORY

#### copy files that are not being subset --------------------------------------

# histologies file
cp $FULL_DIRECTORY/pbta-histologies.tsv $SUBSET_DIRECTORY

# independent specimen files
cp $FULL_DIRECTORY/independent-specimens*.tsv $SUBSET_DIRECTORY

# all bed files
cp $FULL_DIRECTORY/*.bed $SUBSET_DIRECTORY

# create a directory that will hold the SNV consensus files
mkdir -p $SUBSET_DIRECTORY/snv-consensus_11122019
# copy the README from the zipped consensus files to the subset directory
cp ../../data/snv-consensus_11122019/README.md $SUBSET_DIRECTORY/snv-consensus_11122019
# move the subset consensus files to the directory
mv $SUBSET_DIRECTORY/consensus_mutation* $SUBSET_DIRECTORY/snv-consensus_11122019

# zip up the folder and then remove
cd $SUBSET_DIRECTORY
zip pbta-snv-consensus_11122019.zip snv-consensus_11122019/*
rm -rf snv-consensus_11122019

# if the md5sum.txt file already exists, get rid of it
rm -f md5sum.txt
# create a new md5sum.txt file
md5sum * > md5sum.txt

# Changelog does not get tracked
cd ../../../analyses/create-subset-files
cp $FULL_DIRECTORY/CHANGELOG.md $SUBSET_DIRECTORY
