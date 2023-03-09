#!/usr/bin/env python
import json
import helper_uuid

import subprocess, json, os, yaml, sys
from utils import *
from optparse import OptionParser

cliparser = OptionParser()

cliparser.add_option("-f", "--flexy_template", dest="flexy_template",
                     help="This is the template type of what built the cluster.",
                     )
cliparser.add_option("-w", "--workload", dest="workload",
                     help="This is the workload type that was run. See kube-burner-job label in created namespace for help")


(options, args) = cliparser.parse_args()


globalvars = {}
globalvars["flexy_template"] = options.flexy_template
globalvars["workload"] = options.workload

def find_uuid(workload, flexy_template):
    
    split_temp = helper_uuid.split_flexy_temp(flexy_template)
    
    platform = split_temp[1]

    with open(workload + "/" + platform + ".json", "r") as fr:
        read_str =fr.read()
        read_json = json.loads(read_str)

    ocp_version = split_temp[0]
    network_type = split_temp[2]
    cluster_worker_count = helper_uuid.get_worker_num() 
    cluster_arch_type = helper_uuid.get_arch_type()
    found_uuid = helper_uuid.find_uuid(read_json, ocp_version, cluster_worker_count, network_type, cluster_arch_type)
    print(str(found_uuid))

find_uuid(globalvars["workload"], globalvars["flexy_template"])

