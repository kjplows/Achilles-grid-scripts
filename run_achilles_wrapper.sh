#!/usr/bin/sh

set -euxo pipefail

usage() {
    cat << EOF 
Usage: 
      $0 
           -i, --input  where does the image live
	   -c, --cmd    the wrapper to execute in the container
           -o, --output output dir on scratch
	   --nevents    N events to run (default 10000)
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
NEVENTS=10000

while [[ $# -gt 0 ]] ; do
    case "$1" in 
	-i|--input) INPUT_IMAGE="$2" ; shift 2 ;;
	-c|--cmd) INPUT_CMD="$2" ; shift 2 ;;
	-o|--output) OUTPUT_DIR="$2" ; shift 2 ;;
	--cache) INPUT_CACHE="$2" ; shift 2 ;;
	--runcard) INPUT_RUNCARD="$2" ; shift 2 ;;
	--nevents) NEVENTS="$2" ; shift 2 ;;
	-h|--help) usage ;;
	*) echo "Invalid option: $1" ; usage ;;
    esac
done

# Do setup, pull in image to execute
set +eux
source /cvmfs/fermilab.opensciencegrid.org/packages/common/spack/current/NULL/share/spack/setup-env.sh
spack load fife-utils@3.7.8%gcc@11.4.1
#mkdir ${WORKDIR}/output
# Sleep a random amount of time to avoid dCache overloads
RANDOM_SLEEP=$(echo "${RANDOM} % 30" | bc)
echo "Sleeping for ${RANDOM_SLEEP} sec before moving on..."
sleep ${RANDOM_SLEEP}

ifdh cp -D ${INPUT_IMAGE} ${WORKDIR}/ 2> /dev/null
ifdh cp -D ${INPUT_CMD} ${WORKDIR}/ 2> /dev/null
if [[ ! -z ${INPUT_CACHE} ]] ; then
    #mkdir ${WORKDIR}/$(basename ${INPUT_CACHE})
    #ifdh cp -r -D ${INPUT_CACHE} ${WORKDIR}/$(basename ${INPUT_CACHE}) 2> /dev/null
    ifdh cp -D ${INPUT_CACHE} ${WORKDIR}/ 2> /dev/null
fi
ls -lt ${WORKDIR}
tar zxf ${WORKDIR}/$(basename ${INPUT_IMAGE})
# We don't need the tarball anymore...
rm -f ${WORKDIR}/$(basename ${INPUT_IMAGE})
set -eux
BASE_IMAGE=${WORKDIR}/achilles_sandbox #RETHERE fix this
BASE_CMD=$(basename ${INPUT_CMD})
cp ${WORKDIR}/${BASE_CMD} ${BASE_IMAGE}/achilles/achilles-src/run/
if [[ ! -z ${INPUT_CACHE} ]] ; then
    #mkdir ${BASE_IMAGE}/achilles/achilles-src/run/.achilles
    tar zxvf ${WORKDIR}/$(basename ${INPUT_CACHE})
    # We don't need the tarball anymore...
    rm -f ${WORKDIR}/$(basename ${INPUT_CACHE})
    echo
    echo
    echo "ls ${WORKDIR}/"
    ls ${WORKDIR}/
    #echo "Copying cache: ${WORKDIR}/$(basename ${INPUT_CACHE})/* --> ${BASE_IMAGE}/achilles/achilles-src/run/.achilles"
    echo "Copying cache: ${WORKDIR}/.achilles --> ${BASE_IMAGE}/achilles/achilles-src/run/.achilles"
    #cp -r ${WORKDIR}/$(basename ${INPUT_CACHE})/* ${BASE_IMAGE}/achilles/achilles-src/run/.achilles
    cp -r ${WORKDIR}/.achilles ${BASE_IMAGE}/achilles/achilles-src/run/
fi
echo
echo "ls -lt ${BASE_IMAGE}/achilles/achilles-src/run"
ls -lt ${BASE_IMAGE}/achilles/achilles-src/run
echo
sleep 2
BIND_MOUNTS="-B ${BASE_IMAGE}/achilles/achilles-src/run:/achilles/achilles-src/run \
		 -B /cvmfs:/cvmfs"
if [[ ! -z ${INPUT_RUNCARD} ]] ; then
    #echo "Mounting $(dirname ${INPUT_RUNCARD}) to /achilles/achilles-src/runcards"
    #RUNCARD_DIR=$(dirname ${INPUT_RUNCARD})
    #BIND_MOUNTS=${BIND_MOUNTS}" -B ${RUNCARD_DIR}/:/achilles/achilles-src/runcards"
    echo "Copying runcard from ${INPUT_RUNCARD} to ${BASE_IMAGE}/achilles/achilles-src/runcards/"
    ifdh cp -D ${INPUT_RUNCARD} ${BASE_IMAGE}/achilles/achilles-src/runcards/ 2> /dev/null
    # Act on the runcard to replace seed
    CLUSTER_MOD=$(echo "${CLUSTER} / 1000" | bc)
    CLUSTER_MOD=$(echo "${CLUSTER_MOD} + (${RANDOM} % 1000)" | bc)
    RUN=$(echo "${CLUSTER_MOD} * 1000 + ${PROCESS}" | bc)
    sed -i "s/REPLACE_RUN/${RUN}/g" ${BASE_IMAGE}/achilles/achilles-src/runcards/$(basename ${INPUT_RUNCARD})
    echo "Random seed: $(cat ${BASE_IMAGE}/achilles/achilles-src/runcards/$(basename ${INPUT_RUNCARD}) | grep 'Seed')"

    # Figure out the energy
    ENERGY=$(echo "(${PROCESS}+11)*10" | bc)
    sed -i "s/REPLACE_ENERGY/${ENERGY}/g" ${BASE_IMAGE}/achilles/achilles-src/runcards/$(basename ${INPUT_RUNCARD})
    echo "Energy: $(cat ${BASE_IMAGE}/achilles/achilles-src/runcards/$(basename ${INPUT_RUNCARD}) | grep 'Energy')"

    sed -i "s/REPLACE_NEVENTS/${NEVENTS}/g" ${BASE_IMAGE}/achilles/achilles-src/runcards/$(basename ${INPUT_RUNCARD})
    echo "N events: $(cat ${BASE_IMAGE}/achilles/achilles-src/runcards/$(basename ${INPUT_RUNCARD}) | grep 'NEvents')"
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
