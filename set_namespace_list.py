#!/usr/bin/env python

import subprocess
import argparse

all_namespaces= []

# Invokes a given command and returns the stdout
def invoke(command):
    try:
        output = subprocess.check_output(command, shell=True, universal_newlines=True)
    except subprocess.CalledProcessError as exc:
        print("Status : FAIL", exc.returncode, exc.output)
        return exc.output
    return output


def get_all_namespaces(): 
    namespaces = invoke("oc get ns --no-headers | awk '{print$1}'")
    global all_namespaces
    for n in namespaces.split(): 
        all_namespaces.append(n)

def get_kube_burner_namespaces(workload): 
    namespaces = invoke("oc get ns --no-headers -l kube-burner-job=%s | awk '{print$1}'" % workload)
    global all_namespaces
    if "no resources" in namespaces.lower():
        return
    for n in namespaces.split():
        all_namespaces.remove(n)


def get_namespace_list(workload):
    get_all_namespaces()
    if workload:
        if workload == "pod-density":
            workload = "node-density"
        get_kube_burner_namespaces(workload)
    global all_namespaces
    str_all_namespaces = '[' + ', '.join(all_namespaces) + ']'
    print(str_all_namespaces)


parser = argparse.ArgumentParser()
parser.add_argument("--workload", "-w", type=str, default='', help='Kube-burner workload type')
arg = parser.parse_args()
get_namespace_list(arg.workload)