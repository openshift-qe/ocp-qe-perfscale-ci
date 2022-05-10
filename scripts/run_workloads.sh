source ../../e2e-benchmarking/utils/common.sh
source ../../e2e-benchmarking/utils/benchmark-operator.sh
source ./common.sh
source ./netobserv.sh

if [[ $Deploy_NetObserv == "OperatorHub" ]]; then
    deploy_operatorhub_noo
elif [[ $Deploy_NetObserv == "main" ]]; then
    deploy_main_noo
fi

populate_netobserv_metrics

case ${WORKLOAD_TYPE} in
uperf)
    export NETWORK_PERF_DIR='../../e2e-benchmarking/workloads/network-perf'
    export WORKLOAD="pod2pod"
    prep_uperf_workload
    ./run_uperf.sh
    ;;
node-density-heavy)
    export KUBE_BURNER_DIR='../../e2e-benchmarking/workloads/kube-burner'
    prep_kubeburner_workload
    export WORKLOAD="node-density-heavy"
    cd $KUBE_BURNER_DIR && ./run.sh && cd -
    ;;

esac
