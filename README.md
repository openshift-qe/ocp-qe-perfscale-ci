# E2E Benchmarking CI Repo - Network Perf V2


## Purpose

Run Network Perf workload on a given OpenShift cluster. OpenShift cluster `kubeconfig` is fetched from given flexy job id.


## Documentation
[Network-perf-v2](https://github.com/cloud-bulldozer/e2e-benchmarking/tree/master/workloads/network-perf-v2) runs the [k8s-netperf](https://github.com/jtaleric/k8s-netperf)


smoke: set WORKLOAD=smoke.yaml
full: set WORKLOAD=full.yaml


### Author
Mike Fiedler<@mffiedler on Github>
