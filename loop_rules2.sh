#/!/bin/bash

export CONFIG_LOC=${PWD}/configs
export TOLERANCE_LOC=${PWD}/tolerancy-configs

cd e2e-benchmarking/utils

if [[ -n "$BASELINE_UUID" ]]; then
    echo "setting baseline server"
    export ES_SERVER_BASELINE=$ES_SERVER
    echo "grafana url https://grafana.rdu2.scalelab.redhat.com:3000/d/8wDGrVY4k/kube-burner-compare-update?orgId=1&var-Datasource=QE%20kube-burner&var-sdn=OVNKubernetes&var-workload=${WORKLOAD}&var-worker_nodes=&var-latencyPercentile=P99&var-condition=Ready&var-component=kube-apiserver&var-uuid=${UUID}&var-uuid=${BASELINE_UUID}"

fi

ls

ls /tmp/${WORKLOAD}-${UUID}

rm -rf /tmp/${WORKLOAD}-${UUID}
rm -rf *.csv
echo "ls remove"
ls
source compare.sh
mkdir results
failed_comparison=0

COMPARISON_OUTPUT_LIST=""

export COMPARISON_CONFIG=${COMPARISON_CONFIG_PARAM}
export TOLERANCY_RULES=${TOLERANCY_RULES_PARAM}

echo $CONFIG_LOC
run_benchmark_comparison

cp *.csv results/
cd ../..

echo "failed comparisons: $failed_comparison"
if [[ $failed_comparison -ne 0 ]]; then
    exit 1
else 
    exit 0
fi