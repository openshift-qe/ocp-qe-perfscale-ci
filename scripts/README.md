# NetObserv Performance Scripts
The purpose of the scripts in this directory is to measure [netobserv](https://github.com/netobserv/network-observability-operator) metrics performance.

Multiple workloads are run to generate traffic for the cluster:
1. uperf - pod-to-pod traffic generation.
2. node-density-heavy (using kube-burner)
3. router-perf

## Metrics Collection
Below are the metrics that are collected as part of the tests:
* CPU usage of pods in `netobserv` namespace
* Memory usage of pods in `netobserv` namespace
* Disk usage for LokiStack PVCs
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
3. Depending on which functions within `netobserv.sh` you plan to use, you may also need to install the AWS CLI and properly set your credentials

### Installing the Network Observability Operator
There are two methods you can use to install the operator:

#### OperatorHub
To install from Operator Hub, navigate to the `scripts/` directory and run `$ INSTALLATION_SOURCE=OperatorHub; source netobserv.sh ; deploy_netobserv`

#### Source
GitHub Actions is used to [build and push images from the upstream operator repository](https://github.com/netobserv/network-observability-operator/actions) to [quay.io](https://quay.io/repository/netobserv/network-observability-operator-catalog?tab=tags) where the `vmain` tag is used to track the Github `main` branch.

To install from Source, navigate to the `scripts/` directory and run `$ INSTALLATION_SOURCE=Source; source netobserv.sh ; deploy_netobserv`

### Creating LokiStack using Loki Operator
It is recommended to use Loki operator to create a LokiStack for Network Observability. `$ deploy_netobserv` function in [section](#installing-the-network-observability-operator) takes care of deploying LokiStack. To create LokiStack manually, the following steps can be performed:
1. Create a loki-operator subscription `$ oc apply -f loki/loki-subscription.yaml` to install loki-operator. Loki operator pod should be running in `openshift-operators-redhat` namespace
2. Create a AWS secret for S3 bucket to be used for LokiStack using the `$ ./deploy-loki-aws-secret.sh` script. By default, it is setup to use `netobserv-loki` S3 bucket.
3. Multiple sizes of LokiStack are supported and configs are added here. Depending upon the LokiStack size, high-end machine types might be required for the cluster:
    * lokistack-1x-exsmall.yaml - Extra-small t-shirt size LokiStack.
        - Requirements: Can be run on `t2.micro` machines.
        - Use case: For demos, development and feature testing. Should NOT be used for  testing.
    * lokistack-1x-small.yaml - Small t-shirt size LokiStack
        - Requirements: `m5.4xlarge` machines.
        - Use case: Standard performance/scale testing.
    * lokistack-1x-medium.yaml - Medium t-shirt size LokiStack
        - Requirments: `m5.8xlarge` machines.
        - Use case: Large-scale performance/scale testing.

    Depending upon your cluster size and use case, run `$ oc apply -f <lokistack yaml manifest>`
4. LokiStack should be created under `openshift-operators-redhat` namespace

### Setting up FLP service and creating service-monitor
Navigate to the `scripts/` directory of this repository and run `$ populate_netobserv_metrics`

### Updating common parameters of flowcollector
You can update common parameters of flowcollector with the following commands:
- **Sampling rate:** `$ oc patch flowcollector cluster --type=json -p "[{"op": "replace", "path": "/spec/<collector agent>/sampling", "value": <value>}]"`
- **CPU limit:** `$ oc patch flowcollector  cluster --type=json -p "[{"op": "replace", "path": "/spec/flowlogsPipeline/resources/limits/cpu", "value": "<value>m"}]"`
    -  Note that 1000m = 1000 millicores, i.e. 1 core
- **Memory limit:**: `$ oc patch flowcollector  cluster --type=json -p "[{"op": "replace", "path": "/spec/flowlogsPipeline/resources/limits/memory", "value": "<value>Mi"}]"`
- **Replicas:** `$ oc patch flowcollector  cluster --type=json -p "[{"op": "replace", "path": "/spec/flowlogsPipeline/replicas", "value": <value>}]"`

### Enabling Kafka
TODO

### Using Dittybopper
1. Navigate to the `scripts/` directory of this repository and run `$ setup_dittybopper_template`
2. Clone the [performance-dashboards](https://github.com/cloud-bulldozer/performance-dashboards) repo if you haven't already
3. From `performance-dashboards/dittybopper`, run `$ ./deploy.sh -t $WORKSPACE/ocp-qe-perfscale-ci/scripts/netobserv-dittybopper.yaml -i $WORKSPACE/ocp-qe-perfscale-ci/scripts/netobserv_dittybopper_<collector agent>.json`
4. If the data isn't visible, you can manually import it by going to the Grafana URL (can be obtained with `$ oc get routes -n dittybopper`), logging in as `admin`, and uploading the relevant dittybopper config file in the `Dashboards` view.

### Example simulating pod2pod network traffic
1. Install the [Benchmark Operator](https://github.com/cloud-bulldozer/benchmark-operator) via [Ripsaw CLI](https://github.com/cloud-bulldozer/benchmark-operator/tree/master/cli) by cloning the operator, installing Ripsaw CLI, and running `$ ripsaw operator install`
2. Once the operator is installed, run the commands below to begin simulating network traffic:
```bash
$ source scripts/uperf_env.sh <duration in seconds>
$ tmpfile=$(mktemp); envsubst < scripts/uperf_pod2pod.yaml > $tmpfile && echo $tmpfile
$ ripsaw benchmark run -f $tmpfile -t 7200
```

## Testing with Scale CI
You can use the OCP QE PerfScale team's [scale-ci Jenkins jobs](https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/job/scale-ci/job/e2e-benchmarking-multibranch-pipeline/) to run performance and scale tests against NO-enabled clusters

### Running Scale CI tests via Jenkins
Navigate to the Jenkins job page and click on `Build with Parameters`. You may want to include the following `ENV_VARS` prior to building:
```
ERROR_ON_VERIFY=false
MAX_WAIT_TIMEOUT=10m
```

## Network Observability Prometheus and Elasticsearch tool (NOPE)
The Network Observability Prometheus and Elasticsearch tool, or NOPE, is a Python program that is used for collecting and sharing performance data for a given OpenShift cluster running the Network Observability Operator, using Prometheus range queries for collection and Elasticsearch servers for sharing.

Queries are sourced from the `netobserv_queries_ebpf.yaml` file within the `scripts/queries/` directory by default, but this can be overriden with the `--yaml-file` flag to run other queries from within other files.

Gathered data can be tied to specific UUIDs and/or Jenkins jobs using specific flags - see the below section for more information.

If no Elasticsearch server is available to be uploaded to, a raw JSON file will be written to the `data/` directory in the project - note this directory will be created automatically if it does not already exist. You can also explictily dump data to a JSON file rather than upload to Elasticsearch with the `--dump` flag.

### Running the NOPE tool
1. Ensure you have Python 3.9+ and Pip installed (verify with `python --version` and `pip --version`)
2. Install requirements with `pip install -r scripts/requirements.txt`
3. If you wish to upload to Elasticsearch, set the following environmental variables:
```bash
$ export ES_USERNAME=<elasticsearch username>
$ export ES_PASSWORD=<elasticsearch password>
```
4. Run the tool with `./scripts/nope.py`

To see all command line options available for the NOPE tool, you can run it with the `--help` argument.

Note that if you are running the NOPE tool in Upload mode by passing the `--upload-file` flag all other flags will be ignored. You do not need to be connected to an OpenShift cluster if you are running in Upload mode.

### Mr. Sandman
Sometimes, the only way to get data such as UUID and workload timestamp information is directly from the workload job runs. If you find yourself in need of this but don't want to manually pour through logs, you can let Mr. Sandman give it a shot by running `./scripts/sandman.py --file <path/to/out/file>`

## Fetching metrics using Touchstone 
NetObserv metrics uploaded to Elasticsearch can be fetched using `touchstone` tool provided by [benchmark-comparison](https://github.com/cloud-bulldozer/benchmark-comparison). Once you have touchstone setup, you can run it with any given UUID using the `netobserv_touchstone.json` file in the [e2e-benchmarking](https://github.com/cloud-bulldozer/e2e-benchmarking/tree/master/utils/touchstone-configs) repo.
