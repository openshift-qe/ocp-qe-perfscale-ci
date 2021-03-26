# E2E Benchmarking CI Repo - Maximum Services


## Purpose

Run Max-Services workload on a given OpenShift cluster. OpenShift cluster `kubeconfig` is fetched from given flexy job id.
It creates n-replicas of an application deployment (hello-openshift) and a service in a single namespace as defined by the environment variable `JOB_ITERATIONS`.

### Author
Kedar Kulkarni <@kedark3 on Github>