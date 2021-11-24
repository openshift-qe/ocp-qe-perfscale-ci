#!/usr/bin/env python

import time
import yaml
import subprocess
import sys


# Invokes a given command and returns the stdout
def invoke(command):
    try:
        output = subprocess.check_output(command, shell=True, universal_newlines=True)
    except subprocess.CalledProcessError as exc:
        print("Status : FAIL", exc.returncode, exc.output)
        return exc.returncode, exc.output
    return 0, output


def set_max_unavailable(max_unavailable):

    merge_json = '{"spec":{"maxUnavailable": %s }}' % str(max_unavailable)
    return_code, output = invoke("oc patch machineconfigpool/worker --type='merge' -p='%s'" % (merge_json))
    if return_code != 0:
        print("Error occured trying to set maxUnavialble nodes")



def check_cluster_version():

    return_code, output = invoke("oc get clusterversion -o yaml")
    if return_code == 0:
        #parse output to get cluster version and status?
        output = yaml.load(output, Loader=yaml.FullLoader)

        for condition in output['items'][0]['status']['conditions']:
            if condition['type'] == "Progressing":
                print("Progressing status {}".format(condition['message']))
                break
        for status_history in output['items'][0]['status']['history']:
            if status_history['state'] == "Completed":
                print("actual version {}".format(status_history['version']))
                return status_history['version']
            else:
                print("State of version: {} {}".format(status_history['state'], status_history['version']))
        return output
    else:
        print()
    return ""

# Main function
def check_upgrade(expected_cluster_version, wait_num=240):
    print("Starting upgrade check to {}".format(expected_cluster_version))
    upgrade_version = check_cluster_version()
    j = 0
    # Will wait for up to 2 hours.. might need to increase
    while j < wait_num:
        if upgrade_version == expected_cluster_version:
            wait_for_nodes_ready()
            wait_for_co_ready()
            return 0
        upgrade_version = check_cluster_version()
        time.sleep(30)
        j += 1
    return 1

def wait_for_co_ready(wait_num=30):

    counter = 0
    while counter < wait_num:
        return_code, count_not_ready = invoke("oc get co |sed '1d'|grep -v 'openshift-samples'|grep -v '.*True.*False.*False' | wc -l | xargs")
        if return_code == 0:
            if str(count_not_ready).strip() == "0":
                return
        print("Waiting 10 seconds for co to not be available")
        time.sleep(10)
        counter += 1
    print("ERROR: Co were still available and not progressing after 5 minutes")

def wait_for_nodes_ready(wait_num=60):
    counter = 0
    while counter < wait_num:
        return_code, count_not_ready = invoke("oc get nodes | grep 'NotReady\|SchedulingDisabled' | wc -l | xargs")
        if return_code == 0:
            count_str = str(count_not_ready).strip()
            print('count not ready {}'.format(count_str))
            if count_str == "0":
                return
        print("Waiting 30 seconds for nodes to become ready and scheduling enabled")
        time.sleep(30)
        counter += 1
    print("ERROR: Nodes were still not ready and scheduling enabled after 30 minutes")

def wait_for_replicas(machine_replicas, machine_name, wait_num=60):
    counter = 0
    return_code, replicas = invoke("oc get machineset {} -n openshift-machine-api -o jsonpath={{.status.availableReplicas}}".format(machine_name))
    while replicas != machine_replicas:
        time.sleep(5)
        return_code, replicas = invoke("oc get machineset {} -n openshift-machine-api -o jsonpath={{.status.availableReplicas}}".format(machine_name))
        print("Replicas didn't match, waiting 5 seconds")
        counter += 1
        if counter >= wait_num:
            print("ERROR, replica count doesn't match expected after 5 minutes")
            sys.exit(1)

    counter = 0
    return_code, not_ready_node = invoke("oc get nodes | grep 'NotReady' | wc -l | xargs")
    while int(not_ready_node) != 0:
        time.sleep(5)
        print("Nodes not ready yet, waiting 5 seconds")
        return_code, not_ready_node = invoke("oc get nodes | grep 'NotReady' | wc -l | xargs")
        counter += 1
        if counter >= wait_num:
            print("ERROR, nodes are still not ready after 5 minutes")
            sys.exit(1)
    print("Machine sets have correct replica count and all nodes are ready")
