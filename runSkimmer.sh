#!/bin/bash

INPUT_DATASETS=$1

if [ -z "$INPUT_DATASETS" ]; then
    echo "Usage: ./runSkimmer.sh <input_datasets>"
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

echo "Submitting jobs for datasets: $INPUT_DATASETS"

# if CMSSW is not set, set it
if [ -z "$CMSSW_VERSION" ]; then
    echo "CMSSW environment not found!"
    exit 1
fi

echo "Making list of files in datasets"
rm -f file_list.txt; touch file_list.txt
for dataset in $(echo $INPUT_DATASETS | tr "," "\n"); do
    dasgoclient --query="file dataset=$dataset" >> file_list.txt
done

if [ $? -ne 0 ]; then
    echo "!!! Error in getting file list from DAS !!!"
    exit 1
fi

echo "Sumitting jobs to condor"
condor_submit submit.jdl