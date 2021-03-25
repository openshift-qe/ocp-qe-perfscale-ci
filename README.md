# ocp-qe-perfscale-ci


## Purpose

This repo would contain `Jenkinsfile` and any other pertaining contents that would be used by a multi-branch pipeline in our Jenkins.

## Structure

There are multiple orphan branches present in this repos, each of them are supposed to house one kind of workload for [E2E-benchmarking](https://github.com/cloud-bulldozer/e2e-benchmarking/). Each branch should contain one `Jenkinsfile`

You can create a new orphan branch simply by `git checkout --orphan BRANCHNAME` for new workload.

Jenkins multi-branch pipeline job will look at the `Jenkinsfile` on each of these branches and create a new workload job for you to execute in your Jenkins.

### Author
Kedar Kulkarni <@kedark3 on Github>
