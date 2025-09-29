#!/usr/bin/bash

# Really useful! See https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425
# causes Bash to exit upon common errors:
# e --> exit status != 0, u --> undef'ed var, x --> print all commands, o pipefail --> do not mask errors

set -euxo pipefail
#set +x # OK debugging done

usage() {
    cat << EOF 
Usage: 
      $0 -i input_image.tar.gz 
         -c input_wrapper.sh 
	 -o output_dir 
	 [--cache cache-directory] 
         [--runcard run-card.yml]

    -i, --input     input image
    -o, --output    Output dir on scratch
    -c, --cmd       Command script to execute on ACHILLES container
    --cache         Directory of pre-computed ACHILLES xsec (for speeding up execution)
    --runcard       Runcard to execute (on /pnfs: will bind-mount the directory of the runcard)
    -h     Print this help message and exit
EOF

    exit 1
}

INPUT_IMAGE=""
OUTPUT_DIR=""
INPUT_CMD=""
INPUT_CACHE=""
INPUT_RUNCARD=""
NUM_JOBS=1

# getopts only supports single-dash arguments. Boo!
# Parse arguments manually
while [[ $# -gt 0 ]] ; do
    case "$1" in 
	-o|--output) OUTPUT_DIR="$2" ; shift 2 ;;
	-i|--input) INPUT_IMAGE="$2" ; shift 2 ;;
	-c|--cmd) INPUT_CMD="$2" ; shift 2 ;;
	--cache) INPUT_CACHE="$2" ; shift 2 ;;
	--runcard) INPUT_RUNCARD="$2" ; shift 2 ;;
	-h|--help) usage ;;
	*) echo "Invalid option: $1" ; usage ;;
    esac
done

if [[ -z ${OUTPUT_DIR} || -z ${INPUT_IMAGE} || -z ${INPUT_CMD} ]] ; then
    echo "Check args: -o ${OUTPUT_DIR}, -i ${INPUT_IMAGE}, -c ${INPUT_CMD}"
    exit 1
fi

# Check if directory exists, exit out if it does to not hammer dCache
if [[ -d ${OUTPUT_DIR} ]] ; then
    echo "Refusing to go on, this directory exists on scratch: ${OUTPUT_DIR}"
    echo "Use a different directory please"
    exit 1
else
    mkdir -p ${OUTPUT_DIR}
fi

# Check if input image exists
if [[ ! -f ${INPUT_IMAGE} ]] ; then
    echo "Cannot find input image at ${INPUT_IMAGE}. Refusing to go on"
    exit 1
fi
if [[ ! -f ${INPUT_CMD} ]] ; then
    echo "Cannot find input command script at ${INPUT_CMD}. Refusing to go on"
    exit 1
fi

# If we've asked for a cache directory, check it's on pnfs
if [ ! -z ${INPUT_CACHE} ] && [ ! $(echo ${INPUT_CACHE} | grep '/pnfs') ] ; then
    echo "You've asked for an input cache that's not on /pnfs, ignoring input cache"
    INPUT_CACHE=""
fi
if [ ! -z ${INPUT_CACHE} ] && [ ! -d ${INPUT_CACHE} ] ; then
    echo "Error - input cache ${INPUT_CACHE} not found. Exiting"
    exit 1
fi

# If we've asked for a runcard, same check
if [ ! -z ${INPUT_RUNCARD} ] && [ ! $(echo ${INPUT_RUNCARD} | grep '/pnfs') ] ; then
    echo "You've asked for an input runcard that's not on /pnfs, ignoring input runcard"
    INPUT_RUNCARD=""
fi
if [ ! -z ${INPUT_RUNCARD} ] && [ ! -f ${INPUT_RUNCARD} ] ; then
    echo "Error - input runcard ${INPUT_RUNCARD} not found. Exiting"
    exit 1
fi

# submit the script with arguments
cmd="jobsub_submit -e IFDH_DEBUG=1 --group=sbnd --role=Analysis \
	--memory=2GB --disk=4GB --resource-provides=usage_model=DEDICATED,OPPORTUNISTIC \
	--expected-lifetime=1h \
	--auth-methods=token -N ${NUM_JOBS} \
	file://$(pwd)/run_achilles_wrapper.sh \
	--input ${INPUT_IMAGE} --cmd ${INPUT_CMD} --output ${OUTPUT_DIR}"
if [[ ! -z ${INPUT_CACHE} ]] ; then
    cmd=${cmd}"--cache ${INPUT_CACHE}"
fi
if [[ ! -z ${INPUT_RUNCARD} ]] ; then
    cmd=${cmd}"--runcard ${INPUT_RUNCARD}"
fi

echo ${cmd}
eval ${cmd}

