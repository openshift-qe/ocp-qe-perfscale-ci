# E2E Benchmarking CI Repo - Upgrade 

## Purpose

Upgrade a given OpenShift cluster to a new version. OpenShift cluster `kubeconfig` is fetched from given flexy job id. 

### Parameters
Set ENABLE_FORCE to 'True' to set the "--force" parameter on the upgrade command being run

Set SCALE to 'True' to scale the nodes up by one at the end of the upgrade (if successful)

Set EUS_UPGRADE to True to run an upgrade using these steps: "https://docs.google.com/document/d/1396VAUFLmhj8ePt9NfJl0mfHD7pUT7ii30AO7jhDp0g/edit#heading=h.bv3v69eaalsw"

EUS_CHANNEL: channel type to set for EUS_UPGRADE, will be ignored if EUS_UPGRADE is not set to True

MAX_UNAVAILABLE: The number of unavailable nodes you will have during an upgrade, will want to set to 5 for clusters with 50 nodes or more

WRITE_TO_FILE: Boolean on whether to write results to Upgrade tab in Scale-Ci sheet


### Steps
1. Find proper oc adm upgrade command to run using flags and archiecture type
2. Perform Upgrade
3. Will constantly poll clusterversion up to 2.5 hours
4. After upgrade completes, the nodes may still be trying to update, will wait up to 15 minutes for each node to become ready 
5. Will check at the end if an nodes are not ready and if we have degraded cluster operators
6. If SCALE is set to true will increase one of the machinesets by 1 and wait for node to become running


### EUS Upgarde General Information
For EUS_UPGRADE and arm architecture types, will get versions from here
https://arm64.ocp.releases.ci.openshift.org/graph

If non arm type, will use 
https://amd64.ocp.releases.ci.openshift.org/graph

**NOTE**: this type of upgrade should not use force except when updating to a nightly build 

#### Steps
1. Pause MachinePool for workers 
   ```oc patch --type=merge --patch='{"spec":{"paused":true}}' machineconfigpool/worker```
2. Patch the clusterversion to have the next available z stream version
   ```EX.) oc patch clusterversion/version --patch '{"spec":{"channel":"stable-4.7"}}' --type=merge```
3. If going from 4.8 to 4.9 clusters, need to perform this extra step
   ```oc -n openshift-config patch cm admin-acks --type=merge -p='{"data":{"ack-4.8-kube-1.22-api-removals-in-4.9":"true"}}'```
4. Verify version you're upgrade to is in `Recommended Updates` under `oc adm upgrade`
5. Perform upgrade using command
   1. z stream: 
   `oc adm upgrade --to $target_version_prefix" <optional --force>`
   2. Nightly
   `oc adm upgrade --to-image $target_sha --force --allow-explicit-upgrade"`
      1. Target_sha 
      2. Curl graph url above for your architeture type
      3. Find the `version` you're trying to ugprade to 
      4. Use `payload` url as `target_sha`
6. Performs step 3-5 from above
7. Unpause MachinePool for workers
   ```oc patch --type=merge --patch='{"spec":{"paused":false}}' machineconfigpool/worker```
8. Wait for all workers to update
9. Scale machine workers if SCALE=true 

### Author
Paige Rubendall <@paigerube14 on GitHub>

