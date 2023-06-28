#!/usr/bin/env python
import helper_uuid
import update_es_uuid

import os
from utils import *
from optparse import OptionParser

cliparser = OptionParser()

cliparser.add_option("-w", "--workload", dest="workload",
                     help="This is the workload type that was run. See kube-burner-job label in created namespace for help")


(options, args) = cliparser.parse_args()


globalvars = {}
globalvars["workload"] = options.workload

    
def current_oc_cluster_data(workload): 
    network_type= helper_uuid.get_net_type()
    oc_current_version = helper_uuid.get_oc_version()
    current_version = oc_current_version.split('.')
    worker_count = helper_uuid.get_node_count("node-role.kubernetes.io/worker=")
    var_loc = os.getenv('VARIABLES_LOCATION')
    
    find_uuid(network_type, current_version,worker_count, var_loc, workload)

def find_uuid(network_type, current_version,worker_count, var_loc, workload):

    compare_previous = os.getenv("COMPARE_PREVIOUS")
    compare_profile = os.getenv("COMPARE_WITH_PROFILE")
    if str(compare_previous) == "true":
        cur_vers_string = current_version[0] + "_"+ current_version[1]
        replace_string = current_version[0] + "_"+ str(int(current_version[1]) - 1)
        var_loc = var_loc.replace(cur_vers_string, replace_string)
        oc_current_vesion = oc_current_vesion.replace(str(current_version[1]), str(int(current_version[1]) - 1))

    if compare_profile is not None and compare_profile != "": 
        var_loc = helper_uuid.find_launcher_vars_for_profile(compare_profile,oc_current_vesion)

    search_params = {
        "metric_name": "base_line_uuids", 
        "workload": workload,
        "LAUNCHER_VARS": var_loc,
        "network_type": network_type,
        "worker_count": worker_count
    }
    
    hits = update_es_uuid.es_search(search_params)
    if len(hits) == 0: 
        search_params["LAUNCHER_VARS"] = var_loc.replace("-ci","")

        hits = update_es_uuid.es_search(search_params)
    if len(hits) != 0: 
        print(hits[0]['_source']['uuid'])


def find_uuid_metadata(workload): 

    uuid = os.getenv("UUID")
    search_params = {
        "metric_name": "jenkinsEnv",
        "uuid": uuid
    }
    hits = update_es_uuid.es_search(search_params)
    source_hit = hits[0]['_source']
    find_uuid(source_hit['network_type'], source_hit['ocp_version'],source_hit['worker_count'], source_hit['LAUNCHER_VARS'], workload)

uuid = os.getenv("UUID")
if uuid is not None and uuid == "": 
    find_uuid(globalvars["workload"])
else: 
    find_uuid_metadata(globalvars["workload"])