# NETOBSERV Performance Scripts
The purpose of scripts in this directory is to measure [network-observability](https://github.com/netobserv/network-observability-operator) metrics performance

Multiple workloads are run to generate traffic for the the cluster:
1. uperf - pod-to-pod traffic generation.
2. node-density-heavy (using kube-burner)
3. router-perf