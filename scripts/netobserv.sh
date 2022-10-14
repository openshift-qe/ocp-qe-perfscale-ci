NAMESPACE=${1:-netobserv}
export DEFAULT_SC=$(oc get storageclass -o=jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
SCRIPTS_DIR=$WORKSPACE/ocp-qe-perfscale-ci/scripts
if [[ "${INSTALLATION_SOURCE}" == "OperatorHub" ]]; then
  echo "Using OperatorHub for installing NOO"
  NOO_SUBSCRIPTION=$SCRIPTS_DIR/noo-released-subscription.yaml
  FLOWCOLLECTOR=$SCRIPTS_DIR/flows_v1alpha1_flowcollector_versioned_lokistack.yaml
elif [[ "${INSTALLATION_SOURCE}" == "Source" ]]; then
  echo "Using Source for installing NOO"
  NOO_SUBSCRIPTION=$SCRIPTS_DIR/noo-main-subscription.yaml
  FLOWCOLLECTOR=$SCRIPTS_DIR/flows_v1alpha1_flowcollector_lokistack.yaml
fi

deploy_netobserv() {
  oc new-project ${NAMESPACE} || true
  oc apply -f $SCRIPTS_DIR/operator_group.yaml
  oc apply -f $NOO_SUBSCRIPTION
  sleep 60
  oc wait --timeout=180s --for=condition=ready pod -l app=netobserv-operator -n ${NAMESPACE}
  while :; do
    oc get crd/flowcollectors.flows.netobserv.io && break
    sleep 1
  done
  oc apply -f $FLOWCOLLECTOR
  echo "====> Waiting for flowlogs-pipeline pod to be ready"
  while :; do
    oc get daemonset flowlogs-pipeline -n ${NAMESPACE} && break
    sleep 1
  done
  sleep 60
  oc wait --timeout=180s --for=condition=ready pod -l app=flowlogs-pipeline -n ${NAMESPACE}
  deploy_lokistack
}

deploy_main_catalogsource() {
  echo "deploying netobserv operator and flowcollector CR"
  # creating catalog source from the main bundle
  oc apply -f $SCRIPTS_DIR/netobserv-catalogsource.yaml
  sleep 30
  oc wait --timeout=180s --for=condition=ready pod -l olm.catalogSource=netobserv-testing -n openshift-marketplace
}

deploy_loki() {
  oc apply -f $SCRIPTS_DIR/loki-storage-1.yaml
  oc apply -f $SCRIPTS_DIR/loki-storage-2.yaml
  oc wait --timeout=120s --for=condition=ready pod -l app=loki -n ${NAMESPACE}
  echo "loki is deployed"
}

delete_flowcollector() {
  echo "deleting flowcollector"
  oc delete flowcollector/cluster
}

uninstall_netobserv() {
  oc delete flowcollector/cluster
  oc delete -f $NOO_SUBSCRIPTION
  oc delete csv -l operators.coreos.com/netobserv-operator.${NAMESPACE}
  oc delete -f $SCRIPTS_DIR/operator_group.yaml
  oc delete project ${NAMESPACE}
  oc delete catalogsource/netobserv-testing -n openshift-marketplace
}

populate_netobserv_metrics() {
  oc apply -f $SCRIPTS_DIR/cluster-monitoring-config.yaml
  if [[ "${ENABLE_KAFKA}" == "true" ]]; then
    oc apply -f $SCRIPTS_DIR/service-monitor-kafka.yaml
  else
    oc apply -f $SCRIPTS_DIR/service-monitor.yaml
  fi
  echo "Added ServiceMonitor for NetObserv prometheus metrics"
}

setup_dittybopper_template() {
  sleep 30
  oc wait --timeout=120s --for=condition=ready pod -n openshift-user-workload-monitoring -l app.kubernetes.io/component=controller
  oc wait --timeout=120s --for=condition=ready pod -n openshift-user-workload-monitoring -l app.kubernetes.io/managed-by=prometheus-operator
  export PROMETHEUS_USER_WORKLOAD_BEARER=$(oc sa get-token prometheus-user-workload -n openshift-user-workload-monitoring || oc sa new-token prometheus-user-workload -n openshift-user-workload-monitoring)
  export THANOS_URL=https://$(oc get route thanos-querier -n openshift-monitoring -o json | jq -r '.spec.host')
  envsubst "${PROMETHEUS_USER_WORKLOAD_BEARER} ${THANOS_URL}" <$SCRIPTS_DIR/netobserv-dittybopper.yaml.template >$SCRIPTS_DIR/netobserv-dittybopper.yaml
}

deploy_lokistack() {
  oc apply -f $SCRIPTS_DIR/loki-subscription.yaml -n openshift-operators-redhat
  sleep 30
  RAND_SUFFIX=$(tr </dev/urandom -dc 'a-z0-9' | fold -w 12 | head -n 1 || true)
  if [[ "$WORKLOAD" != "None" ]]; then
    export S3_BUCKETNAME = "netobserv-ocpqe-perf-loki-$RAND_SUFFIX"
  else
    export S3_BUCKETNAME = "netobserv-ocpqe-perf-loki-$WORKLOAD"
  fi
  # create s3 secret for loki
  $SCRIPTS_DIR/deploy-loki-aws-secret.sh $S3_BUCKETNAME
  oc wait --timeout=180s --for=condition=ready pod -l app.kubernetes.io/name=loki-operator -n openshift-operators-redhat
  if [[ "${LOKISTACK_SIZE}" == "1x.extra-small" ]]; then
    LokiStack_CONFIG=$SCRIPTS_DIR/lokistack-1x-exsmall.yaml
  elif [[ "${LOKISTACK_SIZE}" == "1x.small" ]]; then
    LokiStack_CONFIG=$SCRIPTS_DIR/lokistack-1x-small.yaml
  elif [[ "${LOKISTACK_SIZE}" == "1x.medium" ]]; then
    LokiStack_CONFIG=$SCRIPTS_DIR/lokistack-1x-medium.yaml
  else
    LokiStack_CONFIG=$SCRIPTS_DIR/lokistack-1x-exsmall.yaml
  fi
  TMP_LOKICONFIG=/tmp/lokiconfig.yaml
  envsubst <$LokiStack_CONFIG >$TMP_LOKICONFIG
  oc apply -f $TMP_LOKICONFIG
  sleep 30
  oc wait --timeout=300s --for=condition=ready pod -l app.kubernetes.io/name=lokistack -n openshift-operators-redhat
}

deploy_kafka() {
  oc create namespace ${NAMESPACE} --dry-run=client -o yaml | oc apply -f -
  oc apply -f $SCRIPTS_DIR/amq-streams/subscription.yaml
  sleep 60
  oc wait --timeout=180s --for=condition=ready pod -l name=amq-streams-cluster-operator -n openshift-operators
  oc apply -f "https://raw.githubusercontent.com/netobserv/documents/main/examples/kafka/metrics-config.yaml" -n ${NAMESPACE}
  curl -s -L "https://raw.githubusercontent.com/netobserv/documents/main/examples/kafka/default.yaml" | envsubst | oc apply -n ${NAMESPACE} -f -

  KAFKA_TOPIC=$SCRIPTS_DIR/amq-streams/kafkaTopic.yaml
  TMP_KAFKA_TOPIC=/tmp/topic.yaml
  envsubst <$KAFKA_TOPIC >$TMP_KAFKA_TOPIC
  oc apply -f $TMP_KAFKA_TOPIC -n ${NAMESPACE}
  oc wait --timeout=180s --for=condition=ready kafkatopic network-flows -n ${NAMESPACE}

  # updated FLP replicas # if different than already configured.
  FLP_REPLICAS=$(oc get flowcollector/cluster -o jsonpath='{.spec.processor.kafkaConsumerReplicas}')
  if [[ "$FLP_KAFKA_REPLICAS" != "$FLP_REPLICAS" ]]; then
    oc patch flowcollector/cluster --type=json -p "[{"op": "replace", "path": "/spec/processor/kafkaConsumerReplicas", "value": ${FLP_KAFKA_REPLICAS}}]"
  fi
  oc wait --timeout=180s --for=condition=ready flowcollector/cluster
}
