# Worker Scaling Job


## Purpose

This job is supposed to scale up and down the clusters by changing machinesets replicas count for worker nodes.

## Variables 

BUILD_NUMBER: the flexy job id of the cluster to scale up/down on 

WORKER_COUNT: the number of worker nodes to scale the cluster to. This will split the number of workers among all the worker machinesets

Use INFRA_WORKLOAD_INSTALL to install infrastructure and workload nodes to a cluster. This functionality will be automatically done if WORKER_COUNT is higher than 50, but this option will install these machines with out scaling any machines. This will move prometheues pods to those machines to allow the worker nodes to only run the workload under test. This will be done by [cluster-post-config](https://github.com/openshift-qe/ocp-qe-perfscale-ci/tree/cluster-post-config) branch 


### Author
Paige Rubendall <@paigerube14 on Github>
