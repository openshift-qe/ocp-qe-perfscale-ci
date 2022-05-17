# Cerberus

This jenkinsfile tests the state of the cluster by checking on common cluster components such as 
* Node Ready Status
* Cluster Operators not degraded
* Failed/Terminating pods
* Etc


For full information see [cerberus github](https://github.com/cloud-bulldozer/cerberus)

### Configurations 

BUILD_NUMBER: Only accepts flexy built clusters, pass the flexy id number 

Number of iterations to run cerberus: CERBERUS_ITERATIONS

To watch all created namespaces set the following variable
```CERBERUS_WATCH_NAMESPACES = [^.*\$]```

If you want cerberus to continually run set CERBERUS_DAEMON_MODE to `true`, but you'll have to manually abort the job

Ability to inspect any failed components by setting INSPECT_COMPONENTS to `true`

CERBERUS_REPO: what is the url of cerberus you want to use

CERBERUS_REPO_BRANCH: branch of the cerberus repo you set above to run (helpful with testing cerberus changes)
