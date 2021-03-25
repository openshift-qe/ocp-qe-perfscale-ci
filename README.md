# E2E Benchmarking CI Repo - Loaded Upgrade

## Steps
1. Create cluster or using existing flexy job
2. Load cluster using scale-ci
3. Upgrade Cluster 
4. Destroy (based on parameter)

## Purpose
Run Loaded Upgrade workload on a given OpenShift cluster or it can create one for you based on ocp version, network type, installation type and cloud type. 
In both installation types the OpenShift cluster `kubeconfig` is fetched from given flexy job id.


## Scale Ci Options
Types: 
* "cluster-density"
* "pod-density"
* "node-density"
* "etcd-perf"
* "max-namespaces"
* "max-services"
* "router-perf"
* "storage-perf"

* NOTE: the cluster-density, pod-density and node-density point to my fork and will write results to [sheet](https://docs.google.com/spreadsheets/d/1uiKGYQyZ7jxchZRU77lsINpa23HhrFWjphsqGjTD-u4/edit?usp=sharing)
All other loading jobs point to the main [scale-ci](https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/job/scale-ci/job/e2e-benchmarking-multibranch-pipeline/) repo 

## Upgrade

For the upgrade you can pass multiple versions (delimited by a comma) to the script and it'll execute each one sequentially 
It'll use quay.io/openshift-release-dev/ocp-release (all builds) or registry.ci.openshift.org/ocp/release (nightly builds only)

If the upgrade fails it'll run a quick diagnostics (similar to UpgradeCI) and run must-gather to get results


## Write to File

If writeToFile is set to True it will print off results to this [sheet](https://docs.google.com/spreadsheets/d/1uiKGYQyZ7jxchZRU77lsINpa23HhrFWjphsqGjTD-u4/edit?usp=sharing) 
This will print off results for the scale-ci job (to the specific tab based on the job), the upgrade, and the overall results of the loaded upgrade 

Based on the ending cluster version, results for the overall loaded-upgrade job will also be printed into this [sheet](https://docs.google.com/spreadsheets/d/1yqQxAxLcYEF-VHlQ_KDLs8NOFsRLb4R8V2UM9VFaRBI/edit?ouid=100476695391511856299&usp=sheets_home&ths=true) on the clusterversion tab  



### Author
Paige Rubendall <@paigerube14 on Github>

