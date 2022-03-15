# Benchmark Comparison using E2E Benchmarking Repo

## Purpose
Compare specific workloads based on version and OpenShift configuration to give pass/fail status. OpenShift cluster `kubeconfig` is fetched from given flexy job id.

### Benchmark-Comparison with Tolerations
The [benchmark-comparison](https://github.com/cloud-bulldozer/benchmark-comparison) tool is used with [tolerations](https://github.com/cloud-bulldozer/benchmark-comparison#using-tolerations) to programmatically show if we have regressions between run to run based on a 'BASELINE_UUID'. 

If COMPARSION_CONFIG environment variable automatically set to gather data based on these config files
 
 * [clusterVersion.json](https://github.com/cloud-bulldozer/e2e-benchmarking/tree/master/workloads/kube-burner/touchstone-configs/clusterVersion.json) 
 * [podLatency.json](https://github.com/cloud-bulldozer/e2e-benchmarking/tree/master/workloads/kube-burner/touchstone-configs/podLatency.json)
 * [podCPU-avg.json](https://github.com/cloud-bulldozer/e2e-benchmarking/tree/master/workloads/kube-burner/touchstone-configs/podCPU-avg.json)
 * [podCPU-max.json](https://github.com/cloud-bulldozer/e2e-benchmarking/tree/master/workloads/kube-burner/touchstone-configs/podCPU-max.json)
 * [podMemory-avg.json](https://github.com/cloud-bulldozer/e2e-benchmarking/tree/master/workloads/kube-burner/touchstone-configs/podMemory-avg.json)
 * [podMemory-max.json](https://github.com/cloud-bulldozer/e2e-benchmarking/tree/master/workloads/kube-burner/touchstone-configs/podMemory-max.json)
Other files found [here](https://github.com/cloud-bulldozer/e2e-benchmarking/tree/master/utils/touchstone-configs)


Set proper TOLERANCY_RULES files based on comparison config files you set. The tolerancy file data points must be also captured in the config file above

 * Kube burner- [pod-latency-tolerancy-rules.yaml](https://github.com/paigerube14/e2e-benchmarking/blob/tolerancy_kubeburner/workloads/kube-burner/pod-latency-tolerancy-rules.yaml) 
 * Router-perf [mb-tolerancy-rules.yaml](https://github.com/cloud-bulldozer/e2e-benchmarking/blob/master/workloads/router-perf-v2/mb-tolerancy-rules.yaml)
 * Network-perf[uperf-tolerancy-rules.yaml](https://github.com/cloud-bulldozer/e2e-benchmarking/blob/master/workloads/network-perf/uperf-tolerancy-rules.yaml)

### Author
Paige Rubendall <@paigerube14 on Github>
