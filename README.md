# E2E Benchmarking CI Repo - Upgrade 

## Purpose

Upgrade a given OpenShift cluster to a new version. OpenShift cluster `kubeconfig` is fetched from given flexy job id. 

### Parameters
Set force to 'True' to set the "--force" parameter on the upgrade command being run

Set scale to 'True' to scale the nodes up by one at the end of the upgrade (if successful)

### Author
Paige Rubendall <@paigerube14 on GitHub>

