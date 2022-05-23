# NETOBSERV Performance Scripts
The purpose of scripts in this directory is to measure [network-observability](https://github.com/netobserv/network-observability-operator) metrics performance

Multiple workloads are run to generate traffic for the the cluster:
1. uperf - pod-to-pod traffic generation.
2. node-density-heavy (using kube-burner)
3. router-perf

## Network Observability Prometheus and Elasticsearch tool (NOPE)
The Network Observability Prometheus and Elasticsearch tool, or NOPE, is a Python program that is used for collecting and sharing performance data for a given OpenShift cluster running the Network Observability Operator, using Prometheus queries for collection and Elasticsearch servers for sharing. Queries are sourced from the `netobserv-metrics.yaml` file within the `scripts/` directory by default, but this can be overriden with the `--yaml_file` flag. Raw JSON files are written to the `data/` directory in the project - note this directory will be created automatically if it does not already exist.

### Prerequisties
1. Ensure you have Python 3.9+ and Pip installed (verify with `python --version` and `pip --version`)
2. Create an OCP4 cluster with OVN enabled
3. Install the [Network Observability Operator](https://github.com/netobserv/network-observability-operator) by cloning the operator and running `$ make deploy ; oc apply -f config/samples/flows_v1alpha1_flowcollector.yaml ; make deploy-loki ; make deploy-grafana`

### Setting up FLP service and creating service-monitor
1. Navigate to the root directory of this repository
2. Run the following commands:
```bash
oc apply -f scripts/cluster-monitoring-config.yaml
oc apply -f scripts/service-monitor.yaml
sleep 10
oc wait --timeout=120s --for=condition=ready pod -n openshift-user-workload-monitoring -l app.kubernetes.io/component=controller
oc wait --timeout=120s --for=condition=ready pod -n openshift-user-workload-monitoring -l app.kubernetes.io/managed-by=prometheus-operator
```

### Simulating network traffic
1. Install the [Benchmark Operator](https://github.com/cloud-bulldozer/benchmark-operator) via [Ripsaw CLI](https://github.com/cloud-bulldozer/benchmark-operator/tree/master/cli) by cloning the operator, installing Ripsaw CLI, and running `$ ripsaw operator install`
2. Once the operator is installed, run the commands below to begin simulating network traffic:
```bash
$ source <path/to/uperf_env.sh> # TODO: Determine if we should include this
$ tmpfile=$(mktemp); envsubst < <path/to/uperf_pod2pod.yaml> > $tmpfile && echo $tmpfile  # TODO: Determine if we should include this
$ ripsaw benchmark run -f $tmpfile -t 7200
```

### Running the tool
1. Install requirements with `pip install -r scripts/requirements.txt`
2. Set your `kubeconfig` and login to your cluster as `kubeadmin`
3. Run the tool with `./scripts/nope.py`

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
