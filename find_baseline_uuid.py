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

def find_uuid(network_type, current_version,worker_count, cloud, workload):
    #print('find uuid')
    compare_previous = os.getenv("COMPARE_PREVIOUS")
    if str(compare_previous) == "true":
        oc_current_version =  current_version[0] + "."+ str(int(current_version[1]) - 1)
    else:
        oc_current_version = current_version[0] + "."+ current_version[1]

    search_params = {
        "metric_name": "base_line_uuids", 
        "workload": workload,
        "network_type": network_type,
        "worker_count": worker_count,
        "platform": cloud
    }
    search_wildcard = {
        "ocp_version": str(oc_current_version) + "*"
    }
    hits = update_es_uuid.es_search(search_params, search_wildcard)
    # print('hits ' + str(hits))
    if len(hits) != 0: 
        print(hits[0]['_source']['uuid'])

def find_uuid_metadata(workload): 

    try: 
        uuid = os.getenv("UUID")
        search_params = {
            "metricName": "clusterMetadata",
            "uuid": uuid
        }
        hits = update_es_uuid.es_search(search_params, index="ripsaw-kube-burner")
        source_hit = hits[0]['_source']
        #print('source hit' + str(source_hit))
        version_list = source_hit['ocpMajorVersion'].split(".")
        find_uuid(source_hit['sdnType'], version_list,source_hit['workerNodesCount'],source_hit['platform'], workload)

        #will need to add clusterType for self-managed in future
    except Exception as e:
        return ""


find_uuid_metadata(globalvars["workload"])