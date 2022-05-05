deploy_operatorhub_noo() {
  oc new-project network-observability
  oc wait --timeout=180s --for=condition=ready pod app=network-observability-operator -n network-observability

  oc apply -f $WORKSPACE/ocp-qe-perfscale/scripts/noo-subscription.yaml
  envsubst <$WORKSPACE/ocp-qe-perfscale/scripts/flows_v1alpha1_flowcollector_versioned.yaml >$WORKSPACE/ocp-qe-perfscale/scripts/flows.yaml

  oc apply -f $WORKSPACE/ocp-qe-perfscale/scripts/flows.yaml
  oc wait --timeout=180s --for=condition=ready pod -l app=flowlogs-pipeline -n network-observability

  deploy_loki
}

deploy_main_noo() {
  log "deploying network-observability operator and flowcollector CR"
  git clone https://github.com/netobserv/network-observability-operator.git
  export NETOBSERV_DIR=${PWD}/network-observability-operator
  add_go_path
  log $(go version)
  log $PATH
  cd ${NETOBSERV_DIR} && make deploy && cd -
  log "deploying flowcollector"
  envsubst <$WORKSPACE/ocp-qe-perfscale/scripts/flows_v1alpha1_flowcollector.yaml >$WORKSPACE/ocp-qe-perfscale/scripts/flows.yaml
  oc apply -f $WORKSPACE/ocp-qe-perfscale/scripts/flows.yaml
  oc wait --timeout=180s --for=condition=ready pod -l app=flowlogs-pipeline -n network-observability
  log "waiting 120 seconds before checking IPFIX collector IP in OVS"
  sleep 120
  get_ipfix_collector_ip
  deploy_loki
}

deploy_loki() {
  oc apply -f $WORKSPACE/ocp-qe-perfscale/scripts/loki-storage-1.yaml
  oc apply -f $WORKSPACE/ocp-qe-perfscale/scripts/loki-storage-2.yaml
  oc wait --timeout=120s --for=condition=ready pod -l app=loki -n network-observability
  log "loki is deployed"
}

delete_flowcollector() {
  log "deleteing flowcollector"
  oc delete -f $NETOBSERV_DIR/config/samples/flows_v1alpha1_flowcollector.yaml
  rm -rf $NETOBSERV_DIR
}

add_go_path() {
  log "adding go bin to PATH"
  export PATH=$PATH:/usr/local/go/bin
}

get_ipfix_collector_ip() {
  ovnkubePods=$(oc get pods -l app=ovnkube-node -n openshift-ovn-kubernetes -o jsonpath='{.items[*].metadata.name}')
  for podName in $ovnkubePods; do
    OVS_IPFIX_COLLECTOR_IP=$(oc get pod/$podName -n openshift-ovn-kubernetes -o jsonpath='{.spec.containers[*].env[?(@.name=="IPFIX_COLLECTORS")].value}')
    if [[ -z "$OVS_IPFIX_COLLECTOR_IP" ]]; then
      log "IPFIX collector IP is not configured in OVS"
      exit 1
    fi
    log "$OVS_IPFIX_COLLECTOR_IP is configured for $podName"
  done
}
