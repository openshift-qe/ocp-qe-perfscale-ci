# E2E Benchmarking CI Repo - Cluster Post Config

## Purpose

To be called after fresh Flexy-cluster is created. And then call again before flexy-destroy to revert any changes made to the cluster.

This will add infra and workload machinesets/nodes to your cluster and take some of the openshift specific work off of the worker nodes so you're able to test your workload on worker nodes specifically 
This will move the monitoring pods and ingress operator pods to the infrasturcure nodes 

## Parameters

BUILD_NUMBER: the flexy job id of the cluster to scale up/down on 

HOST_NETWORK_CONFIGS: Allow adding and removing firewall ports for HostNetwork Uperf testing. Can be extended to do other operations. 

PROVISION_OR_TEARDOWN: Set this to PROVISION to configure Firewall Rules otherwise TEARDOWN to remove Firewall Rules
This is useful for Hostnetwork Uperf Testing where you'd want to have certain firewall ports opened for your flexy cluster before you trigger the tests.
REMEMBER: If you use this job, do not forget to Teardown, else Flexy-destroy for your cluster will fail

INFRA_NODES: Install the infrasturcure and workload nodes to your existing cluster. The yaml files applied will be dependent on the type of flexy installation/cloud type as well as the enviornment variables set in ENV_VARS

ENV_VARS: This is where cloud specific variables will be passed to create the infrasture and workload nodes, one pair on each line. 
For OPENSHIFT_PROMETHEUS_STORAGE_CLASS and OPENSHIFT_ALERTMANAGER_STORAGE_CLASS, use `oc get storageclass` to get them on your cluster.

```
e.g.for AWS:
AMD/Standard Architecture:
OPENSHIFT_INFRA_NODE_INSTANCE_TYPE=m5.12xlarge
OPENSHIFT_WORKLOAD_NODE_INSTANCE_TYPE=m5.8xlarge

ARM64 Architecture:
OPENSHIFT_INFRA_NODE_INSTANCE_TYPE=m6g.12xlarge
OPENSHIFT_WORKLOAD_NODE_INSTANCE_TYPE=m6g.8xlarge

Both Architectures also need:
OPENSHIFT_INFRA_NODE_VOLUME_IOPS=0
OPENSHIFT_INFRA_NODE_VOLUME_TYPE=gp2
OPENSHIFT_INFRA_NODE_VOLUME_SIZE=100
OPENSHIFT_WORKLOAD_NODE_VOLUME_IOPS=0
OPENSHIFT_WORKLOAD_NODE_VOLUME_TYPE=gp2
OPENSHIFT_WORKLOAD_NODE_VOLUME_SIZE=500
OPENSHIFT_PROMETHEUS_STORAGE_CLASS=gp2
OPENSHIFT_ALERTMANAGER_STORAGE_CLASS=gp2


e.g. for Azure:
OPENSHIFT_INFRA_NODE_VOLUME_SIZE=128
OPENSHIFT_INFRA_NODE_VOLUME_TYPE=Premium_LRS
OPENSHIFT_INFRA_NODE_VM_SIZE=Standard_D48s_v3
OPENSHIFT_WORKLOAD_NODE_VOLUME_SIZE=500
OPENSHIFT_WORKLOAD_NODE_VOLUME_TYPE=Premium_LRS
OPENSHIFT_WORKLOAD_NODE_VM_SIZE=Standard_D32s_v3
OPENSHIFT_PROMETHEUS_STORAGE_CLASS=managed-csi
OPENSHIFT_ALERTMANAGER_STORAGE_CLASS=managed-csi

e.g.for GCP:
OPENSHIFT_INFRA_NODE_VOLUME_SIZE=100
OPENSHIFT_INFRA_NODE_VOLUME_TYPE=pd-ssd
OPENSHIFT_INFRA_NODE_INSTANCE_TYPE=n1-standard-64
OPENSHIFT_WORKLOAD_NODE_VOLUME_SIZE=500
OPENSHIFT_WORKLOAD_NODE_VOLUME_TYPE=pd-ssd
OPENSHIFT_WORKLOAD_NODE_INSTANCE_TYPE=n1-standard-32
GCP_PROJECT=openshift-qe
GCP_SERVICE_ACCOUNT_EMAIL=openshift-qe.iam.gserviceaccount.com

e.g. for vSphere:
OPENSHIFT_INFRA_NODE_VOLUME_SIZE=120
OPENSHIFT_INFRA_NODE_CPU_COUNT=48
OPENSHIFT_INFRA_NODE_MEMORY_SIZE=196608
OPENSHIFT_INFRA_NODE_CPU_CORE_PER_SOCKET_COUNT=2
OPENSHIFT_INFRA_NODE_NETWORK_NAME=qe-segment
OPENSHIFT_WORKLOAD_NODE_VOLUME_SIZE=500
OPENSHIFT_WORKLOAD_NODE_CPU_COUNT=32
OPENSHIFT_WORKLOAD_NODE_MEMORY_SIZE=131072
OPENSHIFT_WORKLOAD_NODE_CPU_CORE_PER_SOCKET_COUNT=2
OPENSHIFT_WORKLOAD_NODE_NETWORK_NAME=qe-segment

e.g. for Alicloud:
OPENSHIFT_INFRA_NODE_VOLUME_SIZE=100
OPENSHIFT_INFRA_NODE_INSTANCE_TYPE=ecs.g6.13xlarge
OPENSHIFT_WORKLOAD_NODE_VOLUME_SIZE=500
OPENSHIFT_WORKLOAD_NODE_INSTANCE_TYPE=ecs.g6.8xlarge
OPENSHIFT_PROMETHEUS_STORAGE_CLASS=alicloud-disk
OPENSHIFT_ALERTMANAGER_STORAGE_CLASS=alicloud-disk

e.g. for Ibmcloud:
OPENSHIFT_INFRA_NODE_INSTANCE_TYPE=bx2d-48x192
OPENSHIFT_WORKLOAD_NODE_INSTANCE_TYPE=bx2-32x128
OPENSHIFT_PROMETHEUS_STORAGE_CLASS=ibmc-vpc-block-5iops-tier
OPENSHIFT_ALERTMANAGER_STORAGE_CLASS=ibmc-vpc-block-5iops-tier

e.g. for OSP:
OPENSHIFT_INFRA_NODE_INSTANCE_TYPE=ci.cpu.xxxl
OPENSHIFT_WORKLOAD_NODE_INSTANCE_TYPE=ci.cpu.xxl

And ALWAYS INCLUDE(except for vSphere provider) this part, for Prometheus AlertManager, it may look like:
OPENSHIFT_PROMETHEUS_RETENTION_PERIOD=15d
OPENSHIFT_PROMETHEUS_STORAGE_SIZE=500Gi
OPENSHIFT_ALERTMANAGER_STORAGE_SIZE=20Gi
```

INSTALL_DITTYBOPPER: If you want to install dittybopper dashboards to your cluster

DITTYBOPPER_REPO: The dittybopper github url you want to create on your cluster, useful if you are working on your own fork/branch

DITTYBOPPER_REPO_BRANCH: The dittybopper github branch you want to create on your cluster, useful if you are working on your own fork/branch

DITTYBOPPER_PARAMS: Any specific parameters you want to pass to the deploy.sh script to install dittybopper on your cluster

## Current supported cloud cluster types
* AWS
* AWS Customer VPC
* Azure (only support cluster on region: centralus)
* Azure Customer VPC
* GCP
* Vsphere
* Alicloud/Alibaba 
* IBM Cloud
* OpenStack
* 

### Author
Paige Rubendall <@paigerube14 on Github>