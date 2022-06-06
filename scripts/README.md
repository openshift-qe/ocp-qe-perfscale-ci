# NetObserv Performance Scripts
The purpose of the scripts in this directory is to measure [network-observability](https://github.com/netobserv/network-observability-operator) metrics performance

Multiple workloads are run to generate traffic for the cluster:
1. uperf - pod-to-pod traffic generation.
2. node-density-heavy (using kube-burner)
3. router-perf

## Metrics Collection
Below are the metrics that are collected as part of the tests:
* CPU usage of pods in network-observability NS
* Memory usage of pods in network-observability NS
* Disk usage for PVC=loki-store
* Number of NetFlows processed
* Flow Processing time summary for 0.9 quantile
* Total sum of number of bytes 
* Summary of packet size within Flows
* Number of log lines (flow logs) processed

## Prerequisites
1. Create an OCP4 cluster with OVN enabled
2. Set your `kubeconfig` and login to your cluster as `kubeadmin` - you can verify that you are successfully connected to the cluster by running the simple check below:
```bash
$ oc whoami
kube:admin
```
3. Navigate to the parent directory of `ocp-qe-perfscale-ci` and run `export WORKSPACE=$PWD`
4. Navigate to the `scripts/` directory of this repository and run the following commands:
```bash
$ source netobserv.sh
$ source common.sh
```

### Installing the Network Observability Operator
There are two methods you can use to install the operator:
- To install from Operator Hub, navigate to the `scripts/` directory and run `$ deploy_operatorhub_noo`
- To install from Source, navigate to the `scripts/` directory and run `$ deploy_main_noo`

### Setting up FLP service and creating service-monitor
Navigate to the `scripts/` directory of this repository and run `$ populate_netobserv_metrics`

### Using Dittybopper
1. Set the appropriate environmental variables by running the following:
```bash
export PROMETHEUS_USER_WORKLOAD_BEARER=$(oc sa get-token prometheus-user-workload -n openshift-user-workload-monitoring)
export THANOS_URL=https://`oc get route thanos-querier -n openshift-monitoring -o json | jq -r '.spec.host'`
```
2. From `ocp-qe-perfscale-ci/scripts`, run `$ envsubst '${PROMETHEUS_USER_WORKLOAD_BEARER} ${THANOS_URL}' < netobserv-dittybopper.yaml.template > /tmp/netobserv-dittybopper.yaml`
3. Clone the [performance-dashboards](https://github.com/cloud-bulldozer/performance-dashboards) repo if you haven't already
4. From `performance-dashboards/dittybopper`, run `$ ./deploy.sh -t /tmp/netobserv-dittybopper.yaml`
5. To import the data into Grafana, navigate to the URL printed above after deployment and import the `NetObserv_Metrics.json` file from the `scripts/` directory. You can also get the URL by running `$ oc get routes -n dittybopper`.

### Updating common parameters of flowcollector
You can update common parameters of flowcollector with the following commands:
- **IPFix sampling rate:** `$ oc patch flowcollector cluster --type=json -p '[{"op": "replace", "path": "/spec/ipfix/sampling", "value": <value>}]'`
- **CPU limit:** `$ oc patch flowcollector  cluster --type=json -p '[{"op": "replace", "path": "/spec/flowlogsPipeline/resources/limits/cpu", "value": "<value>m"}]'`
    -  Note that 1000m = 1000 millicores, i.e. 1 core
- **Memory limit:**: `$ oc patch flowcollector  cluster --type=json -p '[{"op": "replace", "path": "/spec/flowlogsPipeline/resources/limits/memory", "value": "<value>Mi"}]'`
- **Replicas:** `$ oc patch flowcollector  cluster --type=json -p '[{"op": "replace", "path": "/spec/flowlogsPipeline/replicas", "value": <value>}]`

### Example simulating pod2pod network traffic
1. Install the [Benchmark Operator](https://github.com/cloud-bulldozer/benchmark-operator) via [Ripsaw CLI](https://github.com/cloud-bulldozer/benchmark-operator/tree/master/cli) by cloning the operator, installing Ripsaw CLI, and running `$ ripsaw operator install`
2. Once the operator is installed, run the commands below to begin simulating network traffic:
```bash
$ source scripts/uperf_env.sh <duration in seconds>
$ tmpfile=$(mktemp); envsubst < scripts/uperf_pod2pod.yaml > $tmpfile && echo $tmpfile
$ ripsaw benchmark run -f $tmpfile -t 7200
```

## Testing with kube-burner
You can use a [fork of the cloud-bulldozer e2e-benchmarking repo](https://github.com/memodi/e2e-benchmarking) maintained by [memodi](https://github.com/memodi) 
in conjunction with the OCP QE PerfScale team's [kube-burner Jenkins job](https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/job/scale-ci/job/e2e-benchmarking-multibranch-pipeline/job/kube-burner/) maintained by [paigerube14](https://github.com/paigerube14) to run kube-burner workload tests against NO-enabled clusters

### Prepping environment for kube-burner tests
Navigate to the `scripts/` directory of this repository and run `$ prep_kubeburner_workload`

### Running kube-burner tests via Jenkins
Navigate to the Jenkins job page and click on `Build with Parameters`. Ensure you set the following variables correctly before building:
1. `ENV_VARS` should be set as such:
```
METRICS_PROFILE=metrics-profiles/netobserv-metrics.yaml
THANOS_QUERIER_HOST <-- copy from local env which is set after running prep_kubeburner_workload step
PROM_URL="https://thanos-querier.openshift-monitoring.svc.cluster.local:9091"
PROM_USER_WORKLOAD="true"
```
2. `E2E_BENCHMARKING_REPO` should be set to `https://github.com/memodi/e2e-benchmarking`
3. `E2E_BENCHMARKING_REPO_BRANCH` should be set to `netobserv-trials`

## Network Observability Prometheus and Elasticsearch tool (NOPE)
The Network Observability Prometheus and Elasticsearch tool, or NOPE, is a Python program that is used for collecting and sharing performance data for a given OpenShift cluster running the Network Observability Operator, using Prometheus queries for collection and Elasticsearch servers for sharing. Queries are sourced from the `netobserv-metrics.yaml` file within the `scripts/` directory by default, but this can be overriden with the `--yaml-file` flag. Raw JSON files are written to the `data/` directory in the project - note this directory will be created automatically if it does not already exist.

### Running the NOPE tool
1. Ensure you have Python 3.9+ and Pip installed (verify with `python --version` and `pip --version`)
2. Install requirements with `pip install -r scripts/requirements.txt`
3. Run the tool with `./scripts/nope.py`

## Fetching metrics using touchstone 
NetObserv metrics uploaded to elasticsearch can be fetched using `touchstone` tool provided by [benchmark-comparison](https://github.com/cloud-bulldozer/benchmark-comparison). Once you have touchstone setup, you can run command as:
`$ touchstone_compare/bin/touchstone_compare --database elasticsearch -url <elasticsearch instance:port> -u <run uuid> --config=scripts/netobserv_touchstone.json`