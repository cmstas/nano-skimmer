#!/bin/bash

# Constants
OUTPUTDIR="output"
CACHE="root://xcache-redirector.t2.ucsd.edu:2042/"
OUTPUT_XRD="root://redirector.t2.ucsd.edu:1095//store/user/aaarora/skims"
CMSSWVERSION='CMSSW_14_1_4'
MAX_RETRIES=10
SLEEP_DURATION="1m"

# Arguments
IFILE=$1
JOB_ID=$2

# Functions
function stageout {
    local COPY_SRC=$1
    local COPY_DEST=$2
    local retries=0
    local COPY_STATUS=1

    until [ $retries -ge $MAX_RETRIES ]; do
        echo "Stageout attempt $((retries+1)): env -i X509_USER_PROXY=${X509_USER_PROXY} gfal-copy -p -f -t 7200 --verbose --checksum ADLER32 ${COPY_SRC} ${COPY_DEST}"
        env -i X509_USER_PROXY=${X509_USER_PROXY} gfal-copy -p -f -t 7200 --verbose --checksum ADLER32 ${COPY_SRC} ${COPY_DEST}
        COPY_STATUS=$?
        if [ $COPY_STATUS -eq 0 ]; then
            echo "Successful stageout with $retries retries"
            break
        else
            echo "Failed stageout attempt $((retries+1))"
            retries=$((retries+1))
            echo "Sleeping for $SLEEP_DURATION"
            sleep $SLEEP_DURATION
        fi
    done

    if [ $COPY_STATUS -ne 0 ]; then
        echo "Removing output file because gfal-copy crashed with code $COPY_STATUS"
        env -i X509_USER_PROXY=${X509_USER_PROXY} gfal-rm --verbose ${COPY_DEST}
        local REMOVE_STATUS=$?
        if [ $REMOVE_STATUS -ne 0 ]; then
            echo "gfal-copy and gfal-rm both failed with codes $COPY_STATUS and $REMOVE_STATUS"
            echo "You probably have a corrupt file sitting on hadoop now."
            exit 1
        fi
    fi
}

function source_environment {
    if [ -r "$OSGVO_CMSSW_Path/cmsset_default.sh" ]; then
        echo "sourcing environment: source $OSGVO_CMSSW_Path/cmsset_default.sh"
        source "$OSGVO_CMSSW_Path/cmsset_default.sh"
    elif [ -r "$OSG_APP/cmssoft/cms/cmsset_default.sh" ]; then
        echo "sourcing environment: source $OSG_APP/cmssoft/cms/cmsset_default.sh"
        source "$OSG_APP/cmssoft/cms/cmsset_default.sh"
    elif [ -r /cvmfs/cms.cern.ch/cmsset_default.sh ]; then
        echo "sourcing environment: source /cvmfs/cms.cern.ch/cmsset_default.sh"
        source /cvmfs/cms.cern.ch/cmsset_default.sh
    else
        echo "ERROR! Couldn't find cmsset_default.sh"
        exit 1
    fi
}

function setup_cmssw {
    echo ${SCRAMARCH}
    export SCRAM_ARCH=${SCRAMARCH}
    scramv1 project ${CMSSWVERSION}
    cd ${CMSSWVERSION}/src/
    eval `scramv1 runtime -sh`
    cd -
}

function run_skimmer {
    echo "Running skimmer on $IFILE"
    mkdir -p $OUTPUTDIR
    python3 skimmer.py --out $OUTPUTDIR --cache $CACHE $IFILE
}

function merge_skims {
    local SKIMFILES=($(ls -d $OUTPUTDIR/*))
    if [[ "${#SKIMFILES[@]}" == "0" ]]; then
        echo "No output files to merge; exiting..."
        exit 0
    elif [[ "${#SKIMFILES[@]}" == "1" ]]; then
        mv ${SKIMFILES[0]} $OUTPUTDIR/output.root
    else
        local MERGECMD="haddnano.py $OUTPUTDIR/output.root ${SKIMFILES[@]}"
        echo $MERGECMD
        $MERGECMD
    fi
}

# Main script
source_environment
setup_cmssw

tar -xzf package.tar.gz
cd nanoaod-skim/
cd NanoAODTools/
bash standalone/env_standalone.sh build
source standalone/env_standalone.sh
cd /srv/nanoaod-skim

run_skimmer

if [ $? -ne 0 ]; then
    echo "Skimmer failed; retrying one more time..."
    run_skimmer
fi

merge_skims

ERA=$(echo $IFILE | awk -F'/' '{print $4}')
SAMPLE_NAME=$(echo $IFILE | awk -F'/' '{print $5}')
GFAL_OUTPUT_DIR="${OUTPUT_XRD}/${ERA}/${SAMPLE_NAME}"

# Copying the output file
COPY_SRC="file://$(pwd)/$OUTPUTDIR/output.root"
COPY_DEST="${GFAL_OUTPUT_DIR}/output_${JOB_ID}.root"

echo "Copying output file from ${COPY_SRC} to ${COPY_DEST}"
gfal-mkdir -p $GFAL_OUTPUT_DIR
stageout $COPY_SRC $COPY_DEST