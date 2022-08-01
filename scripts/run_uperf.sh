#!/usr/bin/env bash

CR=ripsaw-uperf-crd.yaml
# run network-perf common.sh
cd $NETWORK_PERF_DIR && source common.sh && cd -

echo "###############################################"
echo "Workload: ${WORKLOAD}"
echo "Network policy: ${NETWORK_POLICY}"
echo "Samples: ${SAMPLES}"
echo "Pairs: ${PAIRS}"
if [[ ${SERVICEIP} == "true" && ${SERVICETYPE} == "metallb" ]]; then
    echo "Service type: ${SERVICETYPE}"
    echo "Address pool: ${ADDRESSPOOL}"
    echo "Service ETP: ${SERVICE_ET}"
fi
echo "###############################################"

for pairs in ${PAIRS}; do
    export PAIRS=${pairs}
    if ! run_workload ${CR}; then
        exit 1
    fi
done

remove_benchmark_operator ${OPERATOR_REPO} ${OPERATOR_BRANCH}

echo "Finished workload ${0}"
