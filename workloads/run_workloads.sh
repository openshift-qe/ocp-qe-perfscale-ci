source ../e2e-benchmarking/utils/common.sh
source ./common.sh
source ./netobserv.sh

case ${WORKLOAD} in
uperf)
    NETWORK_PERF_DIR='../e2e-benchmarking/workloads/network-perf'
    prep_uperf_workload
    cd $NETWORK_PERF_DIR && WORKLOAD="pod2pod" ./run.sh
    ;;
node-density-heavy)
    KUBE_BURNER_DIR='../e2e-benchmarking/workloads/kube-burner'
    #TODO: update
    cd $KUBE_BURNER_DIR && ./run.sh
    ;;

esac
