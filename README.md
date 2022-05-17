# E2E Benchmarking CI Repo - Loaded Upgrade

## Steps
1. Create cluster or using existing flexy job
2. Scale up cluster (if wanted)
3. Load cluster using scale-ci
4. Cluster Check Using Cerberus
5. Upgrade Cluster 
6. Perform must-gather if any failures during run
7. Destroy (based on parameter)

## Purpose
Run Loaded Upgrade workload on a given OpenShift cluster or it can create one for you based on ocp version, network type, installation type and cloud type. 
In both installation types the OpenShift cluster `kubeconfig` is fetched from given flexy job id.


### Flexy Installation Variables
Uses cluster-builder to help create flexy clusters from CI profiles or specifying a cloud type, network type, and
 installation type
 
 You always will need to specify:
 * an OCP_PREFIX (the name of the cluster to create)
 * an OCP_VERSION (any version [here](https://openshift-release.apps.ci.l2s4.p1.openshiftapps.com/) )


### Profile installation type  
CI_PROFILE: Currently the profiles only suppport OCP version 4.10 and 4.11
The [profiles are listed here](https://gitlab.cee.redhat.com/aosqe/ci-profiles/-/tree/master/scale-ci), it will go to
 one of the versioned folders based on the OCP_VERSION you give above
 
You'll give the name of the file (under the specific version) without `.install.yaml`
Ex.) 02_IPI-on-AWS 

PROFILE_SCALE_SIZE: the size of cluster that you'll end up creating (number of worker nodes)
This will specify the vm_worker_type and/or vm_master_type recommended for the size cluster that you'll end up using
(The number of worker nodes will be overwritten with SCALE_UP variable at loaded-upgrade level)

CI_PROFILES_URL: url of the gitlab ci-profiles repository to use when looking for profile information; `https://gitlab.cee.redhat.com/aosqe/ci-profiles.git/` is default
CI_PROFILES_REPO_BRANCH: branch of above url to look at ci-profiles under; `master` is default

### Cloud/Network installation type  
CLOUD_TYPE: Specify cloud type from drop down list
NETWORK_TYPE: `sdn` or `ovn`, type of network for cloud specified 
INSTALL_TYPE: `upi` or `ipi` 

MASTER_COUNT: if you want to overwrite the number of masters that gets created in original flexy installation
WORKER_COUNT: if you want to overwrite the number of workers that gets created in original flexy installation

In both installation types, the flexy job id will be printed to the description of the cluster-builder job so loaded
-upgrade jobs will be able to get the flexy id to run on that cluster



## Scale Ci Options
Types: 
* "cluster-density"
* "pod-density"
* "node-density"
* "node-density-heavy"
* "etcd-perf"
* "max-namespaces"
* "max-services"
* "pod-network-policy-test"
* "router-perf"
* "storage-perf"
* "network-perf-hostnetwork-network-test"
* "network-perf-pod-network-test"
* "network-perf-serviceip-network-test"


* NOTE: The scale-ci tests have a boolean parameter (write_to_sheet) that will write results to this [sheet](https://docs.google.com/spreadsheets/d/1uiKGYQyZ7jxchZRU77lsINpa23HhrFWjphsqGjTD-u4/edit?usp=sharing) 

## Upgrade

For the upgrade you can pass multiple versions (delimited by a comma) to the script and it'll execute each upgrade sequentially


It'll use quay.io/openshift-release-dev/ocp-release (all builds) or registry.ci.openshift.org/ocp/release (nightly builds only)

Or if selected, you can execute and EUS style of upgrade. For more information on this type of upgrade see [documentation](https://docs.openshift.com/container-platform/4.9/updating/preparing-eus-eus-upgrade.html)
You can also set the the type of upgrade channel that is set in the EUS upgrade. IE fast, stable, eus, or candidate 

If the upgrade fails it'll run a quick diagnostics (similar to UpgradeCI) and run must-gather to get results



## Write to File

If writeToFile is set to True it will print off results to this [sheet](https://docs.google.com/spreadsheets/d/1uiKGYQyZ7jxchZRU77lsINpa23HhrFWjphsqGjTD-u4/edit?usp=sharing) 
This will print off results for the scale-ci job (to the specific tab based on the job), the upgrade, and the overall results of the loaded upgrade 

Based on the ending cluster version, results for the overall loaded-upgrade job will also be printed into this [sheet](https://docs.google.com/spreadsheets/d/1yqQxAxLcYEF-VHlQ_KDLs8NOFsRLb4R8V2UM9VFaRBI/edit?ouid=100476695391511856299&usp=sheets_home&ths=true) on the clusterversion tab  


### Author
Paige Rubendall <@paigerube14 on Github>

