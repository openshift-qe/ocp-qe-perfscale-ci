# E2E Benchmarking CI Repo - Kube Burner OCP 

## Purpose
Run specific workloads on a given OpenShift cluster. OpenShift cluster `kubeconfig` is fetched from given flexy job id.
Can read more at [kube-burner ocp](https://kube-burner.readthedocs.io/en/latest/ocp/)


## Polarion Test Case
Node Density TC: [OCP-41163](https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-41163)

Node Density Heavy TC: [OCP-49146](https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-49146)

Cluster Density TC: [OCP-41162](https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-41162)


## Parameters

Node Density and Node Density Heavy and Node Density CNI: 
```
NODE_COUNT: number of worker nodes on your cluster  
PODS_PER_NODE: Work up to 250
```

cluster-density and cluster-density-v2: Set VARIABLE to 9 * num_workers, 1 namespace per iteration


### Scaling and Adding Infra/Workload Nodes

These use the Jenkinsfile defined on [cluster-worker-scaling](https://github.com/openshift-qe/ocp-qe-perfscale-ci/tree/cluster-workers-scaling) branch

Set SCALE_UP to scale the worker nodes on your cluster up to that number. This takes into account the current number of workers and splits the workers between the machinesets 

SCALE_DOWN: scale down the cluster to a certain number of workers after the workload is completed 

Use INFRA_WORKLOAD_INSTALL to install infrastructure and workload nodes to a cluster. This will move promethues pods to those machines to allow the worker nodes to only run the workload under test 

### Author
Paige Rubendall <@paigerube14 on Github>
