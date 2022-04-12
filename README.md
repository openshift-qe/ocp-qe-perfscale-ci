# E2E Benchmarking CI Repo - Network Perf


## Purpose

Run Network Perf workload on a given OpenShift cluster. OpenShift cluster `kubeconfig` is fetched from given flexy job id.

## Polarion TC

[OCP-43079](https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-43079)

## Documentation
[Network-perf](https://github.com/cloud-bulldozer/e2e-benchmarking/tree/master/workloads/network-perf) documentation


pod to pod using SDN: set WORKLOAD=pod2pod
pod to pod using SDN and network policy: set WORKLOAD=pod2pod and NETWORK_POLICY=true
pod to pod using Hostnetwork: set WORKLOAD=hostnet
pod to service: set WORKLOAD=pod2svc
pod to service and network policy: set WORKLOAD=pod2svc and NETWORK_POLICY=true


### Author
Mike Fiedler<@mffiedler on Github>