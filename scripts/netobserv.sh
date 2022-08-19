if [[ "${INSTALLATION_SOURCE}" == "OperatorHub" ]]; then
  NOO_SUBSCRIPTION=$WORKSPACE/ocp-qe-perfscale-ci/scripts/noo-released-subscription.yaml
  FLOWCOLLECTOR=$WORKSPACE/ocp-qe-perfscale-ci/scripts/flows_v1alpha1_flowcollector_versioned_lokistack.yaml
elif [[ "${INSTALLATION_SOURCE}" == "Source" ]]; then
  NOO_SUBSCRIPTION=$WORKSPACE/ocp-qe-perfscale-ci/scripts/noo-main-subscription.yaml
  FLOWCOLLECTOR=$WORKSPACE/ocp-qe-perfscale-ci/scripts/flows_v1alpha1_flowcollector_lokistack.yaml
fi

deploy_netobserv() {
  oc new-project network-observability || true
  oc apply -f $WORKSPACE/ocp-qe-perfscale-ci/scripts/operator_group.yaml
  oc apply -f $NOO_SUBSCRIPTION
  sleep 30
  oc wait --timeout=180s --for=condition=ready pod -l app=network-observability-operator -n network-observability
  while :; do
    oc get crd/flowcollectors.flows.netobserv.io && break
    sleep 1
  done
  oc apply -f $FLOWCOLLECTOR
  echo "====> Waiting for flowlogs-pipeline pod to be ready"
  while :; do
    oc get daemonset flowlogs-pipeline -n network-observability && break
    sleep 1
  done
  oc wait --timeout=180s --for=condition=ready pod -l app=flowlogs-pipeline -n network-observability
  deploy_lokistack
}

deploy_main_catalogsource() {
  echo "deploying network-observability operator and flowcollector CR"
  # creating catalog source from the main bundle
  oc apply -f $WORKSPACE/ocp-qe-perfscale-ci/scripts/netobserv-catalogsource.yaml
  sleep 10
  oc wait --timeout=180s --for=condition=ready pod -l olm.catalogSource=netobserv-testing -n openshift-marketplace
}

deploy_loki() {
  oc apply -f $WORKSPACE/ocp-qe-perfscale-ci/scripts/loki-storage-1.yaml
  oc apply -f $WORKSPACE/ocp-qe-perfscale-ci/scripts/loki-storage-2.yaml
  oc wait --timeout=120s --for=condition=ready pod -l app=loki -n network-observability
  echo "loki is deployed"
}

delete_flowcollector() {
  echo "deleting flowcollector"
  oc delete flowcollector/cluster
  rm -rf $NETOBSERV_DIR
}

uninstall__netobserv() {
  oc delete flowcollector/cluster
  oc delete -f $NOO_SUBSCRIPTION
  oc delete csv -l operators.coreos.com/netobserv-operator.network-observability
  oc delete -f $WORKSPACE/ocp-qe-perfscale-ci/scripts/operator_group.yaml
  oc delete project network-observability
}

populate_netobserv_metrics() {
  oc apply -f $WORKSPACE/ocp-qe-perfscale-ci/scripts/cluster-monitoring-config.yaml
  oc apply -f $WORKSPACE/ocp-qe-perfscale-ci/scripts/service-monitor.yaml
  echo "Added ServiceMonitor for NetObserv prometheus metrics"
}

setup_dittybopper_template() {
  sleep 20
  oc wait --timeout=120s --for=condition=ready pod -n openshift-user-workload-monitoring -l app.kubernetes.io/component=controller
  oc wait --timeout=120s --for=condition=ready pod -n openshift-user-workload-monitoring -l app.kubernetes.io/managed-by=prometheus-operator
  export PROMETHEUS_USER_WORKLOAD_BEARER=$(oc sa get-token prometheus-user-workload -n openshift-user-workload-monitoring || oc sa new-token prometheus-user-workload -n openshift-user-workload-monitoring)
  export THANOS_URL=https://$(oc get route thanos-querier -n openshift-monitoring -o json | jq -r '.spec.host')
  envsubst "${PROMETHEUS_USER_WORKLOAD_BEARER} ${THANOS_URL}" <$WORKSPACE/ocp-qe-perfscale-ci/scripts/netobserv-dittybopper.yaml.template >$WORKSPACE/ocp-qe-perfscale-ci/scripts/netobserv-dittybopper.yaml
}

deploy_lokistack() {
  oc apply -f $WORKSPACE/ocp-qe-perfscale-ci/scripts/loki-subscription.yaml -n openshift-operators-redhat
  sleep 30
  # create s3 secret for loki
  $WORKSPACE/ocp-qe-perfscale-ci/scripts/deploy-loki-aws-secret.sh
  oc wait --timeout=180s --for=condition=ready pod -l app.kubernetes.io/name=loki-operator -n openshift-operators-redhat
  oc apply -f $WORKSPACE/ocp-qe-perfscale-ci/scripts/lokistack-1x-exsmall.yaml
  sleep 10
  oc wait --timeout=300s --for=condition=ready pod -l app.kubernetes.io/name=lokistack -n openshift-operators-redhat
}
