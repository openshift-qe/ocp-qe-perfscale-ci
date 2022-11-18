#!/usr/bin/env bash

NAMESPACE=${1:-netobserv}
SCRIPTS_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
export DEFAULT_SC=$(oc get storageclass -o=jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
if [[ "${INSTALLATION_SOURCE}" == "OperatorHub" ]]; then
  echo "Using 'OperatorHub' as INSTALLATION_SOURCE"
  NOO_SUBSCRIPTION=$SCRIPTS_DIR/noo-released-subscription.yaml
  FLOWCOLLECTOR=$SCRIPTS_DIR/flows_v1alpha1_flowcollector_versioned_lokistack.yaml
elif [[ "${INSTALLATION_SOURCE}" == "Source" ]]; then
  echo "Using 'Source' as INSTALLATION_SOURCE"
  NOO_SUBSCRIPTION=$SCRIPTS_DIR/noo-main-subscription.yaml
  FLOWCOLLECTOR=$SCRIPTS_DIR/flows_v1alpha1_flowcollector_lokistack.yaml
else
  echo "Please set INSTALLATION_SOURCE env variable to either 'OperatorHub' or 'Source' if you intend to use the 'deploy_netobserv' function"
fi

deploy_netobserv() {
  echo "====> Deploying NetObserv"
  if [[ "${INSTALLATION_SOURCE}" == "Source" ]]; then
    deploy_main_catalogsource
  fi
  echo "====> Creating NetObserv Project, OperatorGroup, and Subscription"
  oc new-project ${NAMESPACE} || true
  oc apply -f $SCRIPTS_DIR/operator_group.yaml
  oc apply -f $NOO_SUBSCRIPTION
  sleep 60
  oc wait --timeout=180s --for=condition=ready pod -l app=netobserv-operator -n ${NAMESPACE}
  while :; do
    oc get crd/flowcollectors.flows.netobserv.io && break
    sleep 1
  done
  echo "====> Creating flowlogs-pipeline"
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
  echo "====> Creating netobserv-testing CatalogSource from the main bundle"
  oc apply -f $SCRIPTS_DIR/netobserv-catalogsource.yaml
  sleep 30
  oc wait --timeout=180s --for=condition=ready pod -l olm.catalogSource=netobserv-testing -n openshift-marketplace
}

deploy_lokistack() {
  echo "====> Deploying LokiStack"
  echo "====> Creating openshift-operators-redhat Namespace and OperatorGroup, loki-operator Subscription"
  oc apply -f $SCRIPTS_DIR/loki-subscription.yaml -n openshift-operators-redhat
  sleep 30
  RAND_SUFFIX=$(tr </dev/urandom -dc 'a-z0-9' | fold -w 12 | head -n 1 || true)
  CLUSTER_NAME=$(oc get infrastructure cluster -o jsonpath='{.status.infrastructureName}')
  if [[ "$WORKLOAD" == "None" ]]; then
    export S3_BUCKETNAME="netobserv-ocpqe-perf-loki-$RAND_SUFFIX"
  else
    export S3_BUCKETNAME="netobserv-ocpqe-perf-loki-$WORKLOAD"
  fi

  # if cluster is to be preserved, do the same for S3 bucket
  if [[ ${CLUSTER_NAME} =~ "preserve" ]]; then
    S3_BUCKETNAME+="-preserve"
  fi
  echo "====> S3_BUCKETNAME is $S3_BUCKETNAME"

  echo "====> Creating S3 secret for Loki"
  $SCRIPTS_DIR/deploy-loki-aws-secret.sh $S3_BUCKETNAME
  oc wait --timeout=180s --for=condition=ready pod -l app.kubernetes.io/name=loki-operator -n openshift-operators-redhat

  echo "====> Determining LokiStack config"
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

  echo "====> Creating LokiStack"
  oc apply -f $TMP_LOKICONFIG
  sleep 30
  oc wait --timeout=300s --for=condition=ready pod -l app.kubernetes.io/name=lokistack -n openshift-operators-redhat
  echo "====> Configuring Loki rate limit alert"
  oc apply -f $SCRIPTS_DIR/loki-ratelimit-alert.yaml
}

deploy_loki() {
  echo "====> Deploying Loki"
  oc apply -f $SCRIPTS_DIR/loki-storage-1.yaml
  oc apply -f $SCRIPTS_DIR/loki-storage-2.yaml
  oc wait --timeout=120s --for=condition=ready pod -l app=loki -n ${NAMESPACE}
}

populate_netobserv_metrics() {
  echo "====> Creating cluster-monitoring-config ConfigMap"
  oc apply -f $SCRIPTS_DIR/cluster-monitoring-config.yaml
  DEPLOYMENT_MODEL=$(oc get flowcollector -o jsonpath="{.items[*].spec.deploymentModel}" -n netobserv)
  if [[ $DEPLOYMENT_MODEL == "KAFKA" ]]; then
    echo "====> Creating flowlogs-pipeline-transformer Service and ServiceMonitor"
    oc apply -f $SCRIPTS_DIR/service-monitor-kafka.yaml
  else
    echo "====> Creating flowlogs-pipeline Service and ServiceMonitor"
    oc apply -f $SCRIPTS_DIR/service-monitor.yaml
  fi
}

deploy_kafka() {
  echo "====> Deploying Kafka"
  oc create namespace ${NAMESPACE} --dry-run=client -o yaml | oc apply -f -
  echo "====> Creating amq-streams Subscription"
  oc apply -f $SCRIPTS_DIR/amq-streams/subscription.yaml
  sleep 60
  oc wait --timeout=180s --for=condition=ready pod -l name=amq-streams-cluster-operator -n openshift-operators
  echo "====> Creating kafka-metrics ConfigMap and kafka-resources-metrics PodMonitor"
  oc apply -f "https://raw.githubusercontent.com/netobserv/documents/main/examples/kafka/metrics-config.yaml" -n ${NAMESPACE}
  echo "====> Creating Kafka"
  curl -s -L "https://raw.githubusercontent.com/netobserv/documents/main/examples/kafka/default.yaml" | envsubst | oc apply -n ${NAMESPACE} -f -

  echo "====> Creating network-flows KafkaTopic"
  KAFKA_TOPIC=$SCRIPTS_DIR/amq-streams/kafkaTopic.yaml
  TMP_KAFKA_TOPIC=/tmp/topic.yaml
  envsubst <$KAFKA_TOPIC >$TMP_KAFKA_TOPIC
  oc apply -f $TMP_KAFKA_TOPIC -n ${NAMESPACE}
  sleep 60
  oc wait --timeout=180s --for=condition=ready kafkatopic network-flows -n ${NAMESPACE}

  echo "====> Update flowcollector to use KAFKA deploymentModel"
  oc patch flowcollector cluster --type=json -p "[{"op": "replace", "path": "/spec/deploymentModel", "value": "KAFKA"}]"

  echo "====> Update flowcollector replicas"
  oc patch flowcollector/cluster --type=json -p "[{"op": "replace", "path": "/spec/processor/kafkaConsumerReplicas", "value": ${FLP_KAFKA_REPLICAS}}]"

  oc wait --timeout=180s --for=condition=ready flowcollector/cluster
}

setup_dittybopper_template() {
  echo "====> Setting up dittybopper template"
  sleep 30
  oc wait --timeout=120s --for=condition=ready pod -n openshift-user-workload-monitoring -l app.kubernetes.io/component=controller
  oc wait --timeout=120s --for=condition=ready pod -n openshift-user-workload-monitoring -l app.kubernetes.io/managed-by=prometheus-operator
  export PROMETHEUS_USER_WORKLOAD_BEARER=$(oc sa get-token prometheus-user-workload -n openshift-user-workload-monitoring || oc sa new-token prometheus-user-workload -n openshift-user-workload-monitoring)
  export THANOS_URL=https://$(oc get route thanos-querier -n openshift-monitoring -o json | jq -r '.spec.host')
  envsubst "${PROMETHEUS_USER_WORKLOAD_BEARER} ${THANOS_URL}" <$SCRIPTS_DIR/netobserv-dittybopper.yaml.template >$SCRIPTS_DIR/netobserv-dittybopper.yaml
}

delete_s3() {
  echo "====> Deleting AWS S3 Bucket, LokiStack, flowcollector, and Kafka (if applicable)"
  echo "====> Getting S3 Bucket Name"
  S3_BUCKET_NAME=$(/bin/bash -c 'oc extract cm/lokistack-config -n openshift-operators-redhat --keys=config.yaml --confirm --to=/tmp | xargs -I {} egrep bucketnames {} | cut -d: -f 2 | xargs echo -n')
  echo "====> Got $S3_BUCKET_NAME"
  aws s3 rm s3://$S3_BUCKET_NAME --recursive
  aws s3 rb s3://$S3_BUCKET_NAME --force
  oc delete lokistack/lokistack -n openshift-operators-redhat
  delete_flowcollector
  echo "====> Getting Deployment Model"
  DEPLOYMENT_MODEL=$(oc get flowcollector -o jsonpath="{.items[*].spec.deploymentModel}" -n netobserv)
  echo "====> Got $DEPLOYMENT_MODEL"
  if [[ $DEPLOYMENT_MODEL == "KAFKA" ]]; then
    oc delete kafka/kafka-cluster -n netobserv
    oc delete kafkaTopic/network-flows -n netobserv
  fi
}

uninstall_netobserv() {
  echo "====> Uninstalling NetObserv"
  delete_flowcollector
  echo "====> Deleting NetObserv Subscription, OperatorGroup, and Project"
  oc delete --ignore-not-found -f $SCRIPTS_DIR/noo-main-subscription.yaml
  oc delete --ignore-not-found -f $SCRIPTS_DIR/noo-released-subscription.yaml
  oc delete csv -l operators.coreos.com/netobserv-operator.${NAMESPACE}
  oc delete -f $SCRIPTS_DIR/operator_group.yaml
  oc delete project ${NAMESPACE}
  echo "====> Deleting netobserv-testing CatalogSource"
  oc delete --ignore-not-found catalogsource/netobserv-testing -n openshift-marketplace
}

delete_flowcollector() {
  echo "====> Deleting flowcollector"
  oc delete --ignore-not-found flowcollector/cluster
}

nukeobserv() {
  echo "====> Nuking NetObserv and all related resources"
  delete_s3
  uninstall_netobserv
}
