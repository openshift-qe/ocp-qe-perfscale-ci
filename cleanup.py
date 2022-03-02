#!/usr/bin/env python

import time
import yaml
import subprocess
import sys
import json

# Invokes a given command and returns the stdout
def invoke(command):
    try:

        output = subprocess.check_output(command, shell=True, universal_newlines=True)
    except subprocess.CalledProcessError as exc:
        print("Status : FAIL", exc.returncode, exc.output)
        return exc.returncode, exc.output
    print("Status : ",  output)
    return 0, output

def delete_all_benchmarks():
    invoke("oc delete benchmark -n benchmark-operator --all")

def delete_all_jobs():
    invoke("oc delete jobs -n benchmark-operator --all")

def delete_all_namespaces(job):
    # make sure all namespaces are gone
    print("job type " + str(job))
    if job.lower() == "pod-density":
        job = "node-density"
    invoke("oc delete ns --wait=false -l kube-burner-job=" + job)
    wait_for_all_deleted_ns(job)

def wait_for_all_deleted_ns(job, wait_num=300):
    counter = 0
    ns_left = 1000  # starting at random high number
    while int(ns_left) > 0:
        returncode, ns_left = invoke("oc get ns --no-headers | grep Terminating | wc -l")
        ns_left = ns_left.strip()
        print(ns_left + " namespaces are left to still terminate")
        if counter > wait_num:
            print("Namespaces created by kube burner job " + job + " still have not terminated properly")
            return 1
        counter += 1
        print("waiting 10 seconds and repolling")
        time.sleep(10)
    invoke("oc get ns")
    return 0

