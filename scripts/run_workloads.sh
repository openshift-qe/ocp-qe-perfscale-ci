source ../../e2e-benchmarking/utils/common.sh
source ./common.sh
source ./netobserv.sh

deploy_flowcollector

case ${WORKLOAD_TYPE} in
uperf)
    export NETWORK_PERF_DIR='../../e2e-benchmarking/workloads/network-perf'
    source $NETWORK_PERF_DIR/env.sh
    source $NETWORK_PERF_DIR/common.sh
    override_uperf_env
    prep_uperf_workload
    cd $NETWORK_PERF_DIR && export WORKLOAD="pod2pod" ./run.sh && cd -
    ;;
node-density-heavy)
    export KUBE_BURNER_DIR='../../e2e-benchmarking/workloads/kube-burner'
    #TODO: update
    cd $KUBE_BURNER_DIR && export WORKLOAD="node-density-heavy" ./run.sh && cd -
    ;;

esac
