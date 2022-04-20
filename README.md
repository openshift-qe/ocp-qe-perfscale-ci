# Kraken

This jenkinsfile tests the clusters ability to withstand chaotic scenarios and show it's recovery

For full information see [kraken github](https://github.com/redhat-chaos/krkn)

### Configurations 

BUILD_NUMBER: Only accepts flexy built clusters, pass the flexy id number 

Set the type of chaos scenario to run by using SCENARIO

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

ENV_VARS: be able to set any of the parameters in each of the above scenarios seperate than the defaults defined in each of the env.sh files in the folder of the scenario in kraken-hub

KRAKEN_REPO: what is the url of kraken you want to use

KRAKN_REPO_BRANCH: branch of the kraken repo you set above to run (helpful with testing changes)

KRAKEN_HUB_REPO: what is the url of kraken-hub you want to use, useful when setting env vars changes

KRAKN_HUB_REPO_BRANCH: what is the branch of kraken-hub you want to use; again, useful when setting env vars changes
