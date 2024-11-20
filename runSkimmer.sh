#!/bin/bash

INPUT_DATASET=$1

if [ -z "$INPUT_DATASET" ]; then
    echo "Usage: ./runSkimmer.sh <input_dataset>"
    exit 1
fi

echo "Creating tarball of Skimming code"
if [ -d "package.tar.gz" ]; then
    rm package.tar.gz
fi

if [ ! -d "nanoaod-skim" ]; then
    echo nanoaod-skim directory not found!
fi

tar -czf package.tar.gz nanoaod-skim/

echo "Submitting jobs for dataset: $INPUT_DATASET"

# if CMSSW is not set, set it
if [ -z "$CMSSW_VERSION" ]; then
    echo "CMSSW environment not found!"
    exit 1
fi

echo "Making list of files in dataset"
dasgoclient --query="file dataset=$INPUT_DATASET" > file_list.txt

if [ $? -ne 0 ]; then
    echo "!!! Error in getting file list from DAS !!!"
    exit 1
fi

echo "Sumitting jobs to condor"
condor_submit submit.jdl
