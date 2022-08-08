deploy_operatorhub_noo() {
  oc new-project network-observability

  oc apply -f $WORKSPACE/ocp-qe-perfscale-ci/scripts/operator_group.yaml
  oc apply -f $WORKSPACE/ocp-qe-perfscale-ci/scripts/noo-subscription.yaml
  sleep 20
  oc wait --timeout=180s --for=condition=ready pod -l app=network-observability-operator -n network-observability
  while :; do
    oc get crd/flowcollectors.flows.netobserv.io && break
    sleep 1
  done
  envsubst <$WORKSPACE/ocp-qe-perfscale-ci/scripts/flows_v1alpha1_flowcollector_versioned.yaml >$WORKSPACE/ocp-qe-perfscale-ci/scripts/flows.yaml
  oc apply -f $WORKSPACE/ocp-qe-perfscale-ci/scripts/flows.yaml
  echo "====> Waiting for flowlogs-pipeline pod to be ready"
  while :; do
    oc get deployment flowlogs-pipeline -n network-observability && break
    sleep 1
  done
  oc wait --timeout=180s --for=condition=ready pod -l app=flowlogs-pipeline -n network-observability

  deploy_loki
}

deploy_main_noo() {
  echo "deploying network-observability operator and flowcollector CR"
  git clone https://github.com/netobserv/network-observability-operator.git
  export NETOBSERV_DIR=${PWD}/network-observability-operator
  add_go_path
  echo $(go version)
  echo $PATH
  cd ${NETOBSERV_DIR} && make deploy && cd -
  echo "deploying flowcollector"
  envsubst <$WORKSPACE/ocp-qe-perfscale-ci/scripts/flows_v1alpha1_flowcollector.yaml >$WORKSPACE/ocp-qe-perfscale-ci/scripts/flows.yaml
  oc apply -f $WORKSPACE/ocp-qe-perfscale-ci/scripts/flows.yaml
  oc wait --timeout=180s --for=condition=ready pod -l app=flowlogs-pipeline -n network-observability
  echo "waiting 120 seconds before checking IPFIX collector IP in OVS"
  sleep 120
  get_ipfix_collector_ip
  deploy_loki
}

deploy_loki() {
  oc apply -f $WORKSPACE/ocp-qe-perfscale-ci/scripts/loki-storage-1.yaml
  oc apply -f $WORKSPACE/ocp-qe-perfscale-ci/scripts/loki-storage-2.yaml
  oc wait --timeout=120s --for=condition=ready pod -l app=loki -n network-observability
  echo "loki is deployed"
}

delete_flowcollector() {
  echo "deleting flowcollector"
  oc delete -f $NETOBSERV_DIR/config/samples/flows_v1alpha1_flowcollector.yaml
  rm -rf $NETOBSERV_DIR
}

add_go_path() {
  echo "adding go bin to PATH"
  export PATH=$PATH:/usr/local/go/bin
}

get_ipfix_collector_ip() {
  ovnkubePods=$(oc get pods -l app=ovnkube-node -n openshift-ovn-kubernetes -o jsonpath='{.items[*].metadata.name}')
  for podName in $ovnkubePods; do
    OVS_IPFIX_COLLECTOR_IP=$(oc get pod/$podName -n openshift-ovn-kubernetes -o jsonpath='{.spec.containers[*].env[?(@.name=="IPFIX_COLLECTORS")].value}')
    if [[ -z "$OVS_IPFIX_COLLECTOR_IP" ]]; then
      echo "IPFIX collector IP is not configured in OVS"
      exit 1
    fi
    echo "$OVS_IPFIX_COLLECTOR_IP is configured for $podName"
  done
}

uninstall_operatorhub_netobserv() {
  oc delete flowcollector/cluster
  oc delete -f $WORKSPACE/ocp-qe-perfscale-ci/scripts/noo-subscription.yaml
  oc delete csv -l operators.coreos.com/netobserv-operator.network-observability
  oc delete -f $WORKSPACE/ocp-qe-perfscale-ci/scripts/operator_group.yaml
  oc delete project network-observability
}
