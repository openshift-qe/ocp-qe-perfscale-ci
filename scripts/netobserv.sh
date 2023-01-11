#!/usr/bin/env bash

SCRIPTS_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
export DEFAULT_SC=$(oc get storageclass -o=jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
if [[ $INSTALLATION_SOURCE == "Downstream" ]]; then
  echo "Using 'Downstream' as INSTALLATION_SOURCE"
  NOO_SUBSCRIPTION=$SCRIPTS_DIR/subscriptions/netobserv-downstream-subscription.yaml
  FLOWCOLLECTOR=$SCRIPTS_DIR/flowcollector/flows_v1alpha1_flowcollector_downstream_lokistack.yaml
elif [[ $INSTALLATION_SOURCE == "OperatorHub" ]]; then
  echo "Using 'OperatorHub' as INSTALLATION_SOURCE"
  NOO_SUBSCRIPTION=$SCRIPTS_DIR/subscriptions/netobserv-upstream-subscription.yaml
  FLOWCOLLECTOR=$SCRIPTS_DIR/flowcollector/flows_v1alpha1_flowcollector_upstream_lokistack.yaml
elif [[ $INSTALLATION_SOURCE == "Source" ]]; then
  echo "Using 'Source' as INSTALLATION_SOURCE"
  NOO_SUBSCRIPTION=$SCRIPTS_DIR/subscriptions/netobserv-main-subscription.yaml
  FLOWCOLLECTOR=$SCRIPTS_DIR/flowcollector/flows_v1alpha1_flowcollector_main_lokistack.yaml
else
  echo "Please set INSTALLATION_SOURCE env variable to either 'Downstream', 'OperatorHub', or 'Source' if you intend to use the 'deploy_netobserv' function"
fi

deploy_netobserv() {
  echo "====> Deploying LokiStack"
  deploy_lokistack
  echo "====> Deploying NetObserv"
  if [[ $INSTALLATION_SOURCE == "Downstream" ]]; then
    deploy_unreleased_catalogsource
  elif [[ $INSTALLATION_SOURCE == "Source" ]]; then
    deploy_main_catalogsource
  fi
  echo "====> Creating NetObserv OperatorGroup and Subscription"
  oc apply -f $SCRIPTS_DIR/netobserv-operatorgroup.yaml
  oc apply -f $NOO_SUBSCRIPTION
  sleep 60
  if [[ $INSTALLATION_SOURCE == "Downstream" ]]; then
    oc wait --timeout=180s --for=condition=ready pod -l app=netobserv-operator -n openshift-operators
  else
    oc wait --timeout=180s --for=condition=ready pod -l app=netobserv-operator -n netobserv
  fi
  while :; do
    oc get crd/flowcollectors.flows.netobserv.io && break
    sleep 1
  done
  echo "====> Creating Flow Collector"
  oc apply -f $FLOWCOLLECTOR
  echo "====> Waiting for flowlogs-pipeline pods to be ready"
  while :; do
    oc get daemonset flowlogs-pipeline -n netobserv && break
    sleep 1
  done
  sleep 60
  oc wait --timeout=180s --for=condition=ready pod -l app=flowlogs-pipeline -n netobserv

  echo "====> Adding RBACs for authToken HOST"
  oc apply -f $SCRIPTS_DIR/clusterRoleBinding-HOST.yaml
}

deploy_lokistack() {
  echo "====> Creating NetObserv Project (if it does not already exist)"
  oc new-project netobserv || true

  echo "====> Creating openshift-operators-redhat Namespace and OperatorGroup"
  oc apply -f $SCRIPTS_DIR/loki/loki-operatorgroup.yaml

  echo "====> Creating loki-operator CatalogSource (if applicable) and Subscription"
  if [[ $LOKI_OPERATOR == "Released" ]]; then
    oc apply -f $SCRIPTS_DIR/subscriptions/loki-released-subscription.yaml
  elif [[ $LOKI_OPERATOR == "Unreleased" ]]; then
    deploy_unreleased_catalogsource
    oc apply -f $SCRIPTS_DIR/subscriptions/loki-unreleased-subscription.yaml
  else
    echo "====> No Loki Operator config was found - using Released"
    oc apply -f $SCRIPTS_DIR/subscriptions/loki-released-subscription.yaml
  fi
  
  echo "====> Generate S3_BUCKETNAME"
  RAND_SUFFIX=$(tr </dev/urandom -dc 'a-z0-9' | fold -w 12 | head -n 1 || true)
  if [[ $WORKLOAD == "None" ]] || [[ -z $WORKLOAD ]]; then
    export S3_BUCKETNAME="netobserv-ocpqe-perf-loki-$RAND_SUFFIX"
  else
    export S3_BUCKETNAME="netobserv-ocpqe-perf-loki-$WORKLOAD"
  fi

  # if cluster is to be preserved, do the same for S3 bucket
  CLUSTER_NAME=$(oc get infrastructure cluster -o jsonpath='{.status.infrastructureName}')
  if [[ $CLUSTER_NAME =~ "preserve" ]]; then
    S3_BUCKETNAME+="-preserve"
  fi
  echo "====> S3_BUCKETNAME is $S3_BUCKETNAME"

  echo "====> Creating S3 secret for Loki"
  $SCRIPTS_DIR/deploy-loki-aws-secret.sh $S3_BUCKETNAME
  sleep 60
  oc wait --timeout=180s --for=condition=ready pod -l app.kubernetes.io/name=loki-operator -n openshift-operators-redhat

  echo "====> Determining LokiStack config"
  if [[ $LOKISTACK_SIZE == "1x.extra-small" ]]; then
    LokiStack_CONFIG=$SCRIPTS_DIR/loki/lokistack-1x-exsmall.yaml
  elif [[ $LOKISTACK_SIZE == "1x.small" ]]; then
    LokiStack_CONFIG=$SCRIPTS_DIR/loki/lokistack-1x-small.yaml
  elif [[ $LOKISTACK_SIZE == "1x.medium" ]]; then
    LokiStack_CONFIG=$SCRIPTS_DIR/loki/lokistack-1x-medium.yaml
  else
    echo "====> No LokiStack config was found - using 1x-exsmall"
    LokiStack_CONFIG=$SCRIPTS_DIR/loki/lokistack-1x-exsmall.yaml
  fi
  TMP_LOKICONFIG=/tmp/lokiconfig.yaml
  envsubst <$LokiStack_CONFIG >$TMP_LOKICONFIG

  echo "====> Creating LokiStack"
  oc apply -f $TMP_LOKICONFIG
  sleep 30
  oc wait --timeout=300s --for=condition=ready pod -l app.kubernetes.io/name=lokistack -n netobserv

  echo "====> Configuring Loki rate limit alert"
  oc apply -f $SCRIPTS_DIR/loki/loki-ratelimit-alert.yaml
}

deploy_unreleased_catalogsource() {
  echo "====> Creating qe-unreleased-testing CatalogSource"
  oc apply -f $SCRIPTS_DIR/catalogsources/qe-unreleased-catalogsource.yaml
  sleep 30
  oc wait --timeout=180s --for=condition=ready pod -l olm.catalogSource=qe-unreleased-testing -n openshift-marketplace
}

deploy_main_catalogsource() {
  echo "====> Creating netobserv-main-testing CatalogSource from the main bundle"
  oc apply -f $SCRIPTS_DIR/catalogsources/netobserv-main-catalogsource.yaml
  sleep 30
  oc wait --timeout=180s --for=condition=ready pod -l olm.catalogSource=netobserv-main-testing -n openshift-marketplace
}

deploy_loki() {
  echo "====> Deploying Loki"
  oc apply -f $SCRIPTS_DIR/loki/loki-storage-1.yaml
  oc apply -f $SCRIPTS_DIR/loki/loki-storage-2.yaml
  oc wait --timeout=120s --for=condition=ready pod -l app=loki -n netobserv
}

deploy_kafka() {
  echo "====> Deploying Kafka"
  oc create namespace netobserv --dry-run=client -o yaml | oc apply -f -
  echo "====> Creating amq-streams Subscription"
  oc apply -f $SCRIPTS_DIR/amq-streams/amq-streams-subscription.yaml
  sleep 60
  oc wait --timeout=180s --for=condition=ready pod -l name=amq-streams-cluster-operator -n openshift-operators
  echo "====> Creating kafka-metrics ConfigMap and kafka-resources-metrics PodMonitor"
  oc apply -f "https://raw.githubusercontent.com/netobserv/documents/main/examples/kafka/metrics-config.yaml" -n netobserv
  echo "====> Creating kafka-cluster Kafka"
  curl -s -L "https://raw.githubusercontent.com/netobserv/documents/main/examples/kafka/default.yaml" | envsubst | oc apply -n netobserv -f -

  echo "====> Creating network-flows KafkaTopic"
  KAFKA_TOPIC=$SCRIPTS_DIR/amq-streams/kafkaTopic.yaml
  TMP_KAFKA_TOPIC=/tmp/topic.yaml
  envsubst <$KAFKA_TOPIC >$TMP_KAFKA_TOPIC
  oc apply -f $TMP_KAFKA_TOPIC -n netobserv
  sleep 60
  oc wait --timeout=180s --for=condition=ready kafkatopic network-flows -n netobserv

  echo "====> Update flowcollector to use KAFKA deploymentModel"
  oc patch flowcollector cluster --type=json -p "[{"op": "replace", "path": "/spec/deploymentModel", "value": "KAFKA"}]"

  echo "====> Update flowcollector replicas"
  oc patch flowcollector/cluster --type=json -p "[{"op": "replace", "path": "/spec/processor/kafkaConsumerReplicas", "value": $FLP_KAFKA_REPLICAS}]"

  echo "====> Update clusterrolebinding Service Account from flowlogs-pipeline to flowlogs-pipeline-transformer"
  oc apply -f $SCRIPTS_DIR/clusterRoleBinding-HOST-kafka.yaml

  oc wait --timeout=180s --for=condition=ready flowcollector/cluster
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

setup_dittybopper_template() {
  echo "====> Setting up dittybopper template"
  sleep 30
  oc wait --timeout=120s --for=condition=ready pod -n openshift-user-workload-monitoring -l app.kubernetes.io/component=controller
  oc wait --timeout=120s --for=condition=ready pod -n openshift-user-workload-monitoring -l app.kubernetes.io/managed-by=prometheus-operator
  export PROMETHEUS_USER_WORKLOAD_BEARER=$(oc sa get-token prometheus-user-workload -n openshift-user-workload-monitoring || oc sa new-token prometheus-user-workload -n openshift-user-workload-monitoring)
  export THANOS_URL=https://$(oc get route thanos-querier -n openshift-monitoring -o json | jq -r '.spec.host')
  envsubst "$PROMETHEUS_USER_WORKLOAD_BEARER $THANOS_URL" <$SCRIPTS_DIR/netobserv-dittybopper.yaml.template >$SCRIPTS_DIR/netobserv-dittybopper.yaml
}

delete_s3() {
  echo "====> Deleting AWS S3 Bucket"
  echo "====> Getting S3 Bucket Name"
  S3_BUCKET_NAME=$(/bin/bash -c 'oc extract cm/lokistack-config -n netobserv --keys=config.yaml --confirm --to=/tmp | xargs -I {} egrep bucketnames {} | cut -d: -f 2 | xargs echo -n')
  echo "====> Got $S3_BUCKET_NAME"
  aws s3 rm s3://$S3_BUCKET_NAME --recursive
  sleep 30
  aws s3 rb s3://$S3_BUCKET_NAME --force
}

delete_lokistack() {
  echo "====> Deleting LokiStack"
  oc delete --ignore-not-found lokistack/lokistack -n netobserv
}

delete_kafka() {
  echo "====> Deleting Kafka (if applicable)"
  echo "====> Getting Deployment Model"
  DEPLOYMENT_MODEL=$(oc get flowcollector -o jsonpath="{.items[*].spec.deploymentModel}" -n netobserv)
  echo "====> Got $DEPLOYMENT_MODEL"
  if [[ $DEPLOYMENT_MODEL == "KAFKA" ]]; then
    oc delete kafka/kafka-cluster -n netobserv
    oc delete kafkaTopic/network-flows -n netobserv
  fi
}

delete_flowcollector() {
  echo "====> Deleting Flow Collector"
  # note 'cluster' is the default Flow Collector name, but that may not always be the case
  oc delete --ignore-not-found flowcollector/cluster
}

delete_netobserv() {
  echo "====> Deleting NetObserv Subscription, CSV, OperatorGroup, and Project"
  oc delete --ignore-not-found -f $SCRIPTS_DIR/subscriptions/netobserv-main-subscription.yaml
  oc delete --ignore-not-found -f $SCRIPTS_DIR/subscriptions/netobserv-upstream-subscription.yaml
  oc delete --ignore-not-found -f $SCRIPTS_DIR/subscriptions/netobserv-downstream-subscription.yaml
  NAMESPACE=$(oc get pods -l app=netobserv-operator -o jsonpath='{.items[*].metadata.namespace}' -A)
  oc delete csv -l operators.coreos.com/netobserv-operator.$NAMESPACE -n $NAMESPACE
  oc delete --ignore-not-found -f $SCRIPTS_DIR/netobserv-operatorgroup.yaml
  oc delete project netobserv
  echo "====> Deleting netobserv-main-testing CatalogSource"
  oc delete --ignore-not-found catalogsource/netobserv-main-testing -n openshift-marketplace
}

delete_loki_operator() {
  echo "====> Deleting Loki Operator Subscription and CSV"
  oc delete --ignore-not-found -f $SCRIPTS_DIR/subscriptions/loki-released-subscription.yaml
  oc delete --ignore-not-found -f $SCRIPTS_DIR/subscriptions/loki-unreleased-subscription.yaml
  oc delete csv -l operators.coreos.com/loki-operator.openshift-operators-redhat -n openshift-operators-redhat
}

nukeobserv() {
  echo "====> Nuking NetObserv and all related resources"
  delete_s3
  delete_lokistack
  delete_kafka
  delete_flowcollector
  delete_netobserv
  delete_loki_operator
}
