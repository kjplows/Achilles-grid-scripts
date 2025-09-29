#!/usr/bin/sh

set -euxo pipefail

usage() {
    cat << EOF 
Usage: 
      $0 
           -i, --input  where does the image live
	   -c, --cmd    the wrapper to execute in the container
           -o, --output output dir on scratch
	   [--cache cache directory]
	   [--runcard runcard to run]
           [-h, --help]
EOF

    exit 1

}

echo "********************************"
echo `date`
myhost=`hostname -f`
echo Running on host $myhost
echo "********************************"
retcode=0 #this will be the value we return

start_sec=$(date +%s)
start_time=$(date +%F_%T)

WORKDIR=$(mktemp -d)
cd $WORKDIR

INPUT_IMAGE=""
INPUT_CMD=""
OUTPUT_DIR=""
INPUT_CACHE=""
INPUT_RUNCARD=""

while [[ $# -gt 0 ]] ; do
    case "$1" in 
	-i|--input) INPUT_IMAGE="$2" ; shift 2 ;;
	-c|--cmd) INPUT_CMD="$2" ; shift 2 ;;
	-o|--output) OUTPUT_DIR="$2" ; shift 2 ;;
	--cache) INPUT_CACHE="$2" ; shift 2 ;;
	--runcard) INPUT_RUNCARD="$2" ; shift 2 ;;
	-h|--help) usage ;;
	*) echo "Invalid option: $1" ; usage ;;
    esac
done

# Do setup, pull in image to execute
set +eux
source /cvmfs/fermilab.opensciencegrid.org/packages/common/spack/current/NULL/share/spack/setup-env.sh
spack load fife-utils@3.7.8%gcc@11.4.1
#mkdir ${WORKDIR}/output
ifdh cp -D ${INPUT_IMAGE} ${WORKDIR}/ 2> /dev/null
ifdh cp -D ${INPUT_CMD} ${WORKDIR}/ 2> /dev/null
if [[ ! -z ${INPUT_CACHE} ]] ; then
   ifdh cp -r -D ${INPUT_CACHE} ${WORKDIR}/ 2> /dev/null
fi
tar zxf $(basename ${INPUT_IMAGE})
set -eux
BASE_IMAGE=${WORKDIR}/achilles_sandbox #RETHERE fix this
BASE_CMD=$(basename ${INPUT_CMD})
cp ${WORKDIR}/${BASE_CMD} ${BASE_IMAGE}/achilles/achilles-src/run/
if [[ ! -z ${INPUT_CACHE} ]] ; then
    echo "Copying cache: ${WORKDIR}/$(basename ${INPUT_CACHE}) --> ${BASE_IMAGE}/achilles/achilles-src/run/"
    cp -r ${WORKDIR}/$(basename ${INPUT_CACHE}) ${BASE_IMAGE}/achilles/achilles-src/run/
fi
echo
echo "ls -lt ${BASE_IMAGE}/achilles/achilles-src/run"
ls -lt ${BASE_IMAGE}/achilles/achilles-src/run
echo
sleep 2
BIND_MOUNTS="-B ${BASE_IMAGE}/achilles/achilles-src/run:/achilles/achilles-src/run \
		 -B /cvmfs:/cvmfs"
if [[ ! -z ${INPUT_RUNCARD} ]] ; then
    echo "Mounting $(dirname ${INPUT_RUNCARD}) to /achilles/achilles-src/runcards"
    RUNCARD_DIR=$(dirname ${INPUT_RUNCARD})
    BIND_MOUNTS=${BIND_MOUNTS}" -B ${RUNCARD_DIR}/:/achilles/achilles-src/runcards"
fi
echo
echo "About to run apptainer on image: ${BASE_IMAGE}"
echo
cmd="/cvmfs/oasis.opensciencegrid.org/mis/apptainer/current/bin/apptainer exec ${BIND_MOUNTS} ${BASE_IMAGE} /achilles/achilles-src/run/${BASE_CMD}"
echo
echo "EXECUTING"
echo $cmd
eval $cmd
echo "Done"
echo
echo "ls -lt ${BASE_IMAGE}/achilles/achilles-src/run/"
ls -lt ${BASE_IMAGE}/achilles/achilles-src/run/
echo
sleep 2
echo "Setting OUTPUT_FILE via find ${BASE_IMAGE}/achilles/achilles-src/run/ -iname '*.hepmc' | head -n 1"
OUTPUT_FILE=$(find ${BASE_IMAGE}/achilles/achilles-src/run/ -iname '*.hepmc' | head -n 1)
echo "OUTPUT_FILE: ${OUTPUT_FILE}"
OLD_OUTPUT_FILE=$(basename ${OUTPUT_FILE})
echo "OLD_OUTPUT_FILE: ${OLD_OUTPUT_FILE}"
OUTPUT_FILE=${OUTPUT_FILE%*.hepmc}
OUTPUT_FILE=${OUTPUT_FILE}_${CLUSTER}.${PROCESS}.hepmc
OUTPUT_FILE=$(basename ${OUTPUT_FILE})
echo "mv ${BASE_IMAGE}/achilles/achilles-src/run/${OLD_OUTPUT_FILE} ${WORKDIR}/${OUTPUT_FILE}"
mv ${BASE_IMAGE}/achilles/achilles-src/run/${OLD_OUTPUT_FILE} ${WORKDIR}/${OUTPUT_FILE}
echo "My output file is ${WORKDIR}/$(basename ${OUTPUT_FILE})"

echo "ifdh cp -D ${WORKDIR}/$(basename ${OUTPUT_FILE}) ${OUTPUT_DIR}/ 2> /dev/null"
ifdh cp -D ${WORKDIR}/$(basename ${OUTPUT_FILE}) ${OUTPUT_DIR}/ 2> /dev/null

stop_time=$(date +%F_%T)
stop_sec=$(date +%s)
duration=$(expr $stop_sec "-" $start_sec )

echo Executable exit code: $retcode
echo Job duration in seconds: $duration
exit $retcode
