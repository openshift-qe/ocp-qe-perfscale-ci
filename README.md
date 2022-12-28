# Chaos During Upgrade while Monitoring Cluster

This jenkinsfile tests the clusters ability to withstand chaotic scenarios during an upgrade and show it's recovery and overall cluster health once complete.

Right now you have to set a hard coded number of iterations for cerberus to run, haven't figured out how to stop dameon mode once it starts 

The cerberus job, kraken and upgrade (if upstream version set) are all run in parallel and will wait for all jobs to fully finish before ending the test


## Cerberus

For full information see [cerberus github](https://github.com/redhat-chaos/cerberus)

## Kraken

For full information see [kraken github](https://github.com/redhat-chaos/krkn)


### Configurations 

BUILD_NUMBER: Only accepts flexy built clusters, pass the flexy id number 

UPGRADE_VERSION: what version you want your cluster to upgrade to, if set to blank won't upgrade at all 

Number of iterations to run cerberus: CERBERUS_ITERATIONS

To watch all created namespaces set the following variable CERBERUS_WATCH_NAMESPACES = [^.*\$]

Set the type of chaos scenario to run by using KRAKEN_SCENARIO

Scenario types are: 
* application-outages
* container-scenarios
* namespace-scenarios
* network-scenarios
* pod-scenarios
* node-cpu-hog
* node-io-hog
* node-memory-hog
* power-outages
* pvc-scenario
* time-scenarios
* zone-outages

There are 2 ways to the run the chaos scenario on a cluster: using **python** or running kraken in a **pod** on your cluster. Set using KRAKEN_RUN_TYPE

ENV_VARS: be able to set any of the parameters in each of the above scenarios seperate than the defaults defined in each of the env.sh files in the folder of the scenario in kraken-hub
See all environment variables [here](https://github.com/redhat-chaos/krkn-hub/blob/main/docs/all_scenarios_env.md) and look at [cerberus](https://github.com/redhat-chaos/krkn-hub/blob/main/docs/cerberus.md) and the specific kraken scenario you're running docs as well 

KRAKEN_REPO: what is the url of kraken you want to use

KRAKN_REPO_BRANCH: branch of the kraken repo you set above to run (helpful with testing changes)

KRAKEN_HUB_REPO: what is the url of kraken-hub you want to use, useful when setting env vars changes

KRAKN_HUB_REPO_BRANCH: what is the branch of kraken-hub you want to use; again, useful when setting env vars changes

CERBERUS_REPO: what is the url of cerberus you want to use

CERBERUS_REPO_BRANCH: branch of the cerberus repo you set above to run (helpful with testing cerberus changes)