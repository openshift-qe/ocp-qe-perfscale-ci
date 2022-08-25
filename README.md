# E2E Benchmarking CI Repo - Router Perf Tests

## Purpose

Run Router Perf Tests workload on a given OpenShift cluster. OpenShift cluster `kubeconfig` is fetched from given flexy job id.

## Parameters
For the meaning of the parameters, please refer to [router-perf-v2](https://github.com/cloud-bulldozer/e2e-benchmarking/blob/master/workloads/router-perf-v2/README.md)

BASELINE_UUID: Baseline UUID used for comparison. A comparsion result of this run and the Baseline will be written into a google sheet. If not provided, the data of only this run will be written into a google sheet.

COMPARISON_ALIASES: Benchmark-comparison aliases (UUIDs will be replaced by these aliase). If you want to keep the UUIDs in the google sheet for future reference, don't use COMPARISON_ALIASES.

### Scaling and Adding Infra/Workload Nodes
These use the Jenkinsfile defined on [cluster-worker-scaling](https://github.com/openshift-qe/ocp-qe-perfscale-ci/tree/cluster-workers-scaling) branch.

SCALE_UP: to scale the worker nodes on your cluster up to that number. This takes into account the current number of workers and splits the workers between the machinesets 

SCALE_DOWN: scale down the cluster to a certain number of workers after the workload is completed 

INFRA_WORKLOAD_INSTALL: to install infrastructure and workload nodes to a cluster. This will move promethues and ingress pods to those machines to allow the worker nodes to only run the workload under test. But [router-perf-v2](https://github.com/cloud-bulldozer/e2e-benchmarking/blob/master/workloads/router-perf-v2/README.md) will move the promethues pods back to worker nodes to avoid them impacting the router pods.

### Contacts
Qiujie Li <@qiliRedHat on Github>

Paige Rubendall <@paigerube14 on Github>