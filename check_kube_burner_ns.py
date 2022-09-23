#!/usr/bin/env python

import subprocess

all_namespaces= []

# Invokes a given command and returns the stdout
def invoke(command):
    try:
        output = subprocess.check_output(command, shell=True, universal_newlines=True)
    except subprocess.CalledProcessError as exc:
        print("Status : FAIL", exc.returncode, exc.output)
        return exc.output
    return output

def get_kube_burner_namespaces(workload): 
    namespaces = invoke("oc get ns --no-headers -l kube-burner-job=%s | awk '{print$1}'" % workload)
    global all_namespaces
    for n in namespaces.split():
        all_namespaces.append(n)

def get_failed_pods(namespace): 
    pod_names = invoke("oc get pods -n %s --no-headers | grep -v Running | awk '{print$1}'" % namespace)
    if pod_names:
        print('make namespace')
        invoke("mkdir failed_pods/" + str(namespace))
    for p in pod_names.split():
        invoke("oc logs %s -n %s >> failed_pods/%s/%s_logs.out" % (p, namespace, namespace, p))

def check_namespaces(workload):
    if not workload:
        return
    invoke('mkdir failed_pods')
    if workload == "pod-density":
        workload = "node-density"
    get_kube_burner_namespaces(workload)
    for n in all_namespaces:
        get_failed_pods(n)