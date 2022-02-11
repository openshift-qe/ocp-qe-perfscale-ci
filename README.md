# ocp-qe-perfscale-ci


## Purpose

This repo would contain `Jenkinsfile` and any other pertaining contents that would be used by a multi-branch pipeline in our Jenkins.

## Structure

There are multiple orphan branches present in this repos, each of them are supposed to house one kind of workload for [E2E-benchmarking](https://github.com/cloud-bulldozer/e2e-benchmarking/). Each branch should contain one `Jenkinsfile`

You can create a new orphan branch simply by `git checkout --orphan BRANCHNAME` for new workload.

Jenkins multi-branch pipeline job will look at the `Jenkinsfile` on each of these branches and create a new workload job for you to execute in your Jenkins.

This repository also hosting the `perf-dashboard-grafana-crs` directory, that includes all the Custom Resources and relevant files that you need to deploy a fully functional perf-scale dashboard.
This deployment uses grafana operator to enable grafana operator on your cluster, create an instance, create required datasources(in this case Prometheus and ElasticSearch) and dashboards.

See `launch-grafana.sh` for env variables we need. And, `cleanup-grafana.sh` could be used to cleanup everything created by the `launch-grafana.sh` script.

**PREREQUISITE:** is to have `KUBECONFIG` env variable configured that can access your OpenShift cluster. 

### Author
Kedar Kulkarni <@kedark3 on Github>
