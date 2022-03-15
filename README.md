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

## Parameters

Cluster-density should run with ITERATIONS = 4 iterations * worker nodes

Node Density and Node Density Heavy: 
```
NODE_COUNT: number of worker nodes on your cluster  
PODS_PER_NODE: Work up to 250
```


pod-density: Set ITERATIONS to 200 * num_workers, work up to 250 * num_workers (Number of pods in 1 namespace)

cluster-density: Set ITERATIONS to 4 * num_workers, 1 namespace per iteration

max-namespaces: Set ITERATIONS to ~30 * num_workers, 1 namespace per iteration

max-services: Set ITERATIONS to 200 * num_workers, work up to 250 * num_workers (1 namespace/service per iteration)


### Author
Paige Rubendall <@paigerube14 on Github>
