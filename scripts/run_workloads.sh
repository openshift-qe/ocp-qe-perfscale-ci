source ../utils/common.sh
source ./common.sh
source ./netobserv.sh

case ${WORKLOAD} in
uperf)
    export NETWORK_PERF_DIR='workloads/network-perf'
    prep_uperf_workload
    cd $NETWORK_PERF_DIR && WORKLOAD="pod2pod" ./run.sh && cd -
    ;;
node-density-heavy)
    export KUBE_BURNER_DIR='workloads/kube-burner'
    #TODO: update
    cd $KUBE_BURNER_DIR && ./run.sh && cd -
    ;;

esac
