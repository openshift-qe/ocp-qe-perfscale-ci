export DEFAULT_SC=$(oc get storageclass -o=jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
export TOPIC_PARTITIONS=6
export FLP_KAFKA_REPLICAS=3
