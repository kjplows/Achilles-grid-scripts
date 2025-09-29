#!/bin/bash

echo "Starting execution of ACHILLES wrapper at: $(date)"

cd /achilles/achilles-src/
source /cvmfs/sbnd.opensciencegrid.org/products/sbnd/setup_sbnd.sh
#source setup_global_vars.sh
setup root v6_28_12 -q e26:p3915:prof
setup lhapdf v6_5_4 -q e26:p3915:prof
setup log4cpp v1_1_3e -q e26:prof
setup pdfsets v5_9_1b
setup gdb v13_1
setup git v2_45_1
setup cmake v3_27_4
setup boost v1_82_0 -q e26:prof
setup tbb v2021_9_0 -q e26
setup sqlite v3_40_01_00
setup pythia v6_4_28x -q e26:prof
setup hepmc3 v3_2_7 -q e26:p3915:prof
setup geant4 v4_11_2_p02 -q e26:prof
setup inclxx v5_2_9_5f -q e26:prof
setup hdf5 v1_12_2b -q e26:prof
setup spdlog v1_9_2 -q e26:prof
echo
echo "export PATH=/achilles/achilles-src/build/bin:${PATH}"
export PATH=/achilles/achilles-src/build/bin:${PATH}
echo
echo "ls /achilles/achilles-src/run"
ls /achilles/achilles-src/run
sleep 2
echo
echo "cd /achilles/achilles-src/run"
cd /achilles/achilles-src/run
echo
echo "ln -s /achilles/achilles-src/data/"
ln -s /achilles/achilles-src/data/
ACTIVE_CARD=""
if [[ $(find /achilles/achilles-src/runcards/ -type f) ]] ; then
    ACTIVE_CARD=$(find /achilles/achilles-src/runcards/ -type f)
else
    ACTIVE_CARD=/achilles/achilles-src/run.yml
fi
echo
echo "cp ${ACTIVE_CARD} ."
cp ${ACTIVE_CARD} .
echo
echo "cp /achilles/achilles-src/FormFactors.yml ."
cp /achilles/achilles-src/FormFactors.yml .
echo
echo "ls /achilles/achilles-src/run"
ls /achilles/achilles-src/run
sleep 2
echo "achilles $(basename ${ACTIVE_CARD}) 2>&1"
achilles $(basename ${ACTIVE_CARD}) 2>&1
sleep 2
echo
#mkdir /achilles/achilles-src/run/output/
#echo "mv achilles.hepmc /achilles/achilles-src/run/output/"
#mv achilles.hepmc /achilles/achilles-src/run/output/
#echo
echo "ls -lt /achilles/achilles-src/run/"
ls -lt /achilles/achilles-src/run/

echo "Finished execution of ACHILLES wrapper at: $(date)"
