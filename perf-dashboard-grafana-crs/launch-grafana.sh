#!/bin/bash
export ES_USER=${ES_USER:-ocp-qe}

export PROMETHEUS_USER=${PROMETHEUS_USER:-internal}
export PROMETHEUS_URL=${PROMETHEUS_URL:-https://prometheus-k8s.openshift-monitoring.svc:9091}
export ES_SERVER=${ES_SERVER:-https://search-ocp-qe-perf-scale-test-elk-hcm7wtsqpxy7xogbu72bor4uve.us-east-1.es.amazonaws.com:443}

if [ -z "$ES_PASSWORD" ]
then
    echo -e "\033[32m\$ES_PASSWORD is empty, set password in an env variable and rerun the script.\033[0m"
    exit 1
fi

echo -e "\033[32mInstalling Grafana Operator\n\n\033[0m"
oc create -f grafana-operator-install.yaml


echo -e "\033[32mWait for Grafana operator to be installed\033[0m"
sleep 30

echo -e "\033[32mGrafana instance\n\n"
oc create -f grafana-instance.yaml

echo -e "\033[32mWait for Grafana deployment to be created\033[0m"
sleep 30

# echo -e "Patch grafana deployment with latest image, as currently operator in the OpenShift is running older version, that doesn't support reading baseImage attribute in Custom Resource"
# oc set image deployment grafana-deployment grafana='quay.io/openshift/origin-grafana:latest'
# echo -e "Remove above workaround when Grafana operator original channel in OpenShift is close to upstream release version v3.6.0 or higher"

echo "\033[32mCreate grafana datasources\033[0m"

export PROMETHEUS_PASSWORD=$(oc get secrets -n openshift-monitoring grafana-datasources -o go-template='{{index .data "prometheus.yaml"| base64decode }}' | jq '.datasources[0].basicAuthPassword' -r)
echo -e "\033[32mFound password for Prometheus: $PROMETHEUS_PASSWORD\n\n\033[0m"
# substitute env vars into datasources, e.g. PROMETHEUS_PASSWORD from above
for file in ./datasources/*.yaml; do
    envsubst < $file | oc create -f -
done

echo -e "\033[32mCreating dashboards\n\n\033[0m"
oc create -f dashboards/

echo -e "\033[32mAccess your grafana at: https://`oc get route grafana-route -o=jsonpath='{.status.ingress.*.host}{"\n\n"}'`\033[0m"


echo -e "\033[32mDefault login is set to admin/secret\n\n\033[0m"
