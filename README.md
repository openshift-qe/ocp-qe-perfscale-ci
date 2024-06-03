# OCM API Load test

## Overview

Some workloads doesn't need OCP environemnt. For example, ocm-api-load which tests OCM server can be run as a standalone application on a jump host. Any tool which can be run on a jump host but needed to triggered using airflow can use this mechanism. Assumptions in this approach

* tool is run from the jump host
* user has to manually setup needed packages in the jump host
* user provided script for benchmark task should handle everything like triggering the tool on jump host, scrapping metrics, pushing data to snappy and cleanup.

## Adding the new workload

* We can look at ocm as reference for adding a new workload
* New benchmark script (example run_ocm_benchmark.sh) with all commands to run on jump host
* Invoke the new benchmark script from the jenkinsfile
* Json file (example ocm.json) for providing variables to benchmark script
