prep_uperf_workload() {
    export PAIRS=4
    export SAMPLES=1
    envsubst '${PAIRS} ${SAMPLES} ${PROTOCOL} ${TRAFFIC_TYPE} ${PACKET_SIZE}' <ripsaw-uperf-crd.yaml >$NETWORK_PERF_DIR/ripsaw-uperf-crd.yaml
    cat $NETWORK_PERF_DIR/ripsaw-uperf-crd.yaml
}

populate_netobserv_metrics() {
    oc apply -f cluster-monitoring-config.yaml
    oc apply -f service-monitor.yaml
    log "Added ServiceMonitor for NetObserv prometheus metrics"
}

prep_kubeburner_workload() {
    export METRICS_PROFILE=$PWD/netobserv-metrics.yaml
}
