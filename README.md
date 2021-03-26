# E2E Benchmarking CI Repo - Node Density Heavy


## Purpose

Run NodeDensity Heavy workload on a given OpenShift cluster. OpenShift cluster `kubeconfig` is fetched from given flexy job id.

Creates a single namespace with a number of applications proportional to the calculated number of pods / 2. This application consists on two deployments (a postgresql database and a simple client that generates some CPU load) and a service that is used by the client to reach the database. Each iteration of this workload can be broken down in:

    1 deployment holding a postgresql database
    1 deployment holding a client application for the previous database
    1 service pointing to the postgresl database


### Author
Kedar Kulkarni <@kedark3 on Github>