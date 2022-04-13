prep_uperf_workload() {
    envsubst <ripsaw-uperf-crd.yaml >$NETWORK_PERF_DIR/ripsaw-uperf-crd.yaml
    export PAIRS=4
    export SAMPLES=1
}
