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

