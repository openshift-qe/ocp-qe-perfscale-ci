prep_uperf_workload() {
    export PAIRS=4
    export SAMPLES=1
    envsubst '${PAIRS} ${SAMPLES} ${PROTOCOL} ${TRAFFIC_TYPE} ${PACKET_SIZE}' <ripsaw-uperf-crd.yaml >$NETWORK_PERF_DIR/ripsaw-uperf-crd.yaml
    cat $NETWORK_PERF_DIR/ripsaw-uperf-crd.yaml
}
override_uperf_env() {

}
