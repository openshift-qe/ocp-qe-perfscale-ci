#!/usr/bin/env bash

# run network-perf common.sh
cd $NETWORK_PERF_DIR && source common.sh && cd -

log "###############################################"
log "Workload: ${WORKLOAD}"
log "Network policy: ${NETWORK_POLICY}"
log "Samples: ${SAMPLES}"
log "Pairs: ${PAIRS}"
if [[ ${SERVICEIP} == "true" && ${SERVICETYPE} == "metallb" ]]; then
    log "Service type: ${SERVICETYPE}"
    log "Address pool: ${ADDRESSPOOL}"
    log "Service ETP: ${SERVICE_ET}"
fi
log "###############################################"

for pairs in ${PAIRS}; do
    export PAIRS=${pairs}
    if ! run_workload ${CR}; then
        exit 1
    fi
done

remove_benchmark_operator ${OPERATOR_REPO} ${OPERATOR_BRANCH}

log "Finished workload ${0}"
