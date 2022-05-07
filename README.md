# E2E Benchmarking CI Repo - Cluster Builder

## Purpose
Run Cluster Builder to help create flexy cluster from CI profiles or specifying a cloud type, network type, and
 installation type
 
 You always will need to specify:
 * an OCP_PREFIX (the name of the cluster to create)
 * an OCP_VERSION (any version [here](https://openshift-release.apps.ci.l2s4.p1.openshiftapps.com/) )


### Profile installation type  
CI_PROFILE: Currently the profiles only suppport OCP version 4.10 and 4.11
The [profiles are listed here](https://gitlab.cee.redhat.com/aosqe/ci-profiles/-/tree/master/scale-ci), it will go to
 one of the versioned folders based on the OCP_VERSION you give above
 
You'll give the name of the file (under the specific version) withouth `.install.yaml`
Ex.) 02_IPI-on-AWS 

PROFILE_SCALE_SIZE: the size of cluster that you'll end up creating (number of worker nodes)
This will specify the vm_worker_type and/or vm_master_type recommended for the size cluster that you'll end up using
(The number of worker nodes will be overwritten with SCALE_UP variable at loaded-upgrade level)

### Cloud/Network installation type  
CLOUD_TYPE: Specify cloud type from drop down list
NETWORK_TYPE: `sdn` or `ovn`, type of network for cloud specified 
INSTALL_TYPE: `upi` or `ipi` 

MASTER_COUNT: if you want to overwrite the number of masters that gets created in original flexy installation
WORKER_COUNT: if you want to overwrite the number of workers that gets created in original flexy installation

In both installation types, the flexy job id will be printed to the description of the job so following jobs will be
 able to get the flexy id to run on that cluster


### Author
Paige Rubendall <@paigerube14 on Github>

