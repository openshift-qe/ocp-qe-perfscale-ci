prep_uperf_workload() {
    envsubst <ripsaw-uperf-crd.yaml >$NETWORK_PERF_DIR/ripsaw-uperf-crd.yaml
    cat $NETWORK_PERF_DIR/ripsaw-uperf-crd.yaml
}
override_uperf_env() {
    export PAIRS=4
    export SAMPLES=1
}
