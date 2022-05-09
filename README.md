# E2E Benchmarking CI Repo - Kube Burner

## Purpose
Run specific workloads on a given OpenShift cluster. OpenShift cluster `kubeconfig` is fetched from given flexy job id.
Can read more at e2e-benchmark [kube-burner](https://github.com/cloud-bulldozer/benchmark-operator/blob/master/docs/kube-burner.md)


## Polarion Test Case
Node Density TC: [OCP-41163](https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-41163)

Node Density Heavy TC: [OCP-49146](https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-49146)

Cluster Density TC: [OCP-41162](https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-41162)

Max-Namespace TC: [OCP-41165](https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-41165)

Max-Services TC: [OCP-41166](https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-41166)

Pod-Density TC: [OCP-41155](https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-41155)

Concurrent-Builds TC: [OCP-49623](https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-49623)

## Parameters

Cluster-density should run with VARIABLE = 4 VARIABLE * worker nodes

Node Density and Node Density Heavy: 
```
NODE_COUNT: number of worker nodes on your cluster  
PODS_PER_NODE: Work up to 250
```

pod-density: Set VARIABLE to 200 * num_workers, work up to 250 * num_workers (Number of pods in 1 namespace)

cluster-density: Set VARIABLE to 4 * num_workers, 1 namespace per iteration

max-namespaces: Set VARIABLE to ~30 * num_workers, 1 namespace per iteration

max-services: Set VARIABLE to 200 * num_workers, work up to 250 * num_workers (1 namespace/service per iteration)

concurrent-builds: 

```
APP_LIST: space delimited list of applications to build, default and best to use "1 8 15 30 45 60 75"
BUILD_LIST: space delimited list of concurrent builds to build, best to run one at a time because each can take a long
 time 
```

### Scaling and Adding Infra/Workload Nodes

These use the Jenkinsfile defined on [cluster-worker-scaling](https://github.com/openshift-qe/ocp-qe-perfscale-ci/tree/cluster-workers-scaling) branch

Set SCALE_UP to scale the worker nodes on your cluster up to that number. This takes into account the current number of workers and splits the workers between the machinesets 

SCALE_DOWN: scale down the cluster to a certain number of workers after the workload is completed 

Use INFRA_WORKLOAD_INSTALL to install infrastructure and workload nodes to a cluster. This will move promethues pods to those machines to allow the worker nodes to only run the workload under test 

### Benchmark-Comparison 
The [benchmark-comparison](https://github.com/cloud-bulldozer/benchmark-comparison) tool will run at the end of the
 kube-burner workload. It will send a google spreedsheet of the data to your email. When spreadsheet is recieved
  please change the sharing to be viewable by anyone within Red Hat with link

If COMPARSION_CONFIG environment variable is not set in the ENV_VARS the script will automatically set to gather data
 based on these config files
 
 * [clusterVersion.json](https://github.com/cloud-bulldozer/e2e-benchmarking/tree/master/workloads/kube-burner/touchstone-configs/clusterVersion.json) 
 * [podLatency.json](https://github.com/cloud-bulldozer/e2e-benchmarking/tree/master/workloads/kube-burner/touchstone-configs/podLatency.json)
 * [podCPU-avg.json](https://github.com/cloud-bulldozer/e2e-benchmarking/tree/master/workloads/kube-burner/touchstone-configs/podCPU-avg.json)
 * [podCPU-max.json](https://github.com/cloud-bulldozer/e2e-benchmarking/tree/master/workloads/kube-burner/touchstone-configs/podCPU-max.json)
 * [podMemory-avg.json](https://github.com/cloud-bulldozer/e2e-benchmarking/tree/master/workloads/kube-burner/touchstone-configs/podMemory-avg.json)
 * [podMemory-max.json](https://github.com/cloud-bulldozer/e2e-benchmarking/tree/master/workloads/kube-burner/touchstone-configs/podMemory-max.json)

### Author
Paige Rubendall <@paigerube14 on Github>
