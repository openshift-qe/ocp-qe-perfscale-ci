import json
import subprocess
from datetime import datetime
import get_es_data

def run(command):
    try:
        output = subprocess.check_output(command, shell=True, universal_newlines=True)
    except subprocess.CalledProcessError as exc:
        print("Status : FAIL", exc.returncode, exc.output)
        return exc.returncode, exc.output
    return 0, output

def get_upgrade_duration():
    return_code, version_str = run("oc get clusterversion -o json")
    all_versions = []
    if return_code == 0:
        version_json = json.loads(version_str)
        earliesetStartingTime = datetime.max
        latestCompletiontime = datetime.min
        for item in version_json['items']:
            lastVersion = True
            counter = 0
            for hist in item['status']['history']:
                if (counter != 0) and ((len(item['status']['history']) - 1) == counter):
                    lastVersion = False
                counter += 1
                all_versions.append(hist['version'])
                start_time = hist['startedTime']
                if not hist['completionTime']:
                    latestCompletiontime = datetime.now()

                else:
                    end_time = hist['completionTime']
                    end_date_time = datetime.strptime(end_time[:-1], "%Y-%m-%dT%H:%M:%S")
                    if end_date_time > latestCompletiontime:

                        latestCompletiontime = end_date_time

                start_date_time = datetime.strptime(start_time[:-1], "%Y-%m-%dT%H:%M:%S")
                if (start_date_time < earliesetStartingTime) and lastVersion:
                    earliesetStartingTime = start_date_time

        time_elapsed = latestCompletiontime - earliesetStartingTime
        all_versions.reverse()
        return str(time_elapsed), all_versions
    return get_oc_version(), ""

def get_pod_latencies(uuid):
    if uuid != "":
        # In the form of [[json_data['quantileName'], json_data['avg'], json_data['P99']...]
        pod_latencies_list = get_es_data.get_pod_latency_data(uuid)
        if len(pod_latencies_list) != 0:
            avg_list = []
            p99_list = []

            for pod_info in pod_latencies_list:
                if len(pod_info) > 0:
                    avg_list.append(pod_info[1])
                    p99_list.append(pod_info[2])
            return avg_list
    return ["", "", "", ""]


def get_uperf_uuid():
    # In the form of [[json_data['quantileName'], json_data['avg'], json_data['P99']...]
    pod_latencies_list = get_es_data.get_pod_latency_data()
    if len(pod_latencies_list) != 0:
        avg_list = []
        p99_list = []
        for pod_info in pod_latencies_list:
            avg_list.append(pod_info[1])
            p99_list.append(pod_info[2])
        return avg_list
    return ["", "", "", ""]

def get_oc_version():
    return_code, cluster_version_str = run("oc get clusterversion -o json")
    if return_code == 0:
        cluster_version_json = json.loads(cluster_version_str)
        for item in cluster_version_json['items']:
            for status in item['status']['conditions']:
                if status['type'] == "Progressing":
                    version = status['message'].split(" ")[-1]
                    return version
    else:
        print("Error getting clusterversion")

def flexy_install_type(flexy_url):
    return_code, version_type_string = run('curl -s {}/consoleFull | grep "run_installer template -c private-templates/functionality-testing/aos-"'.format(flexy_url))
    if return_code == 0:
        version_lists = version_type_string.split("-on-")
        install_type = version_lists[0].split('/')[-1]
        cloud_type = version_lists[1].split('/')[0]
        if "ovn" in version_type_string:
            network_type = "OVN"
        else:
            network_type = "SDN"

        return cloud_type, install_type, network_type
    else:
        print("Error getting flexy installtion")
        return "", "", ""

def get_worker_num(scale="false"):
    return_code, worker_count = run("oc get nodes | grep worker | wc -l | xargs")
    if return_code != 0:
        worker_count = "ERROR"
    print("scale " + str(scale))
    if scale == "true":
        worker_count = str(int(worker_count.strip()) - 1)
    else:
        worker_count = worker_count.strip()
    return worker_count
#flexy_install_type("https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/job/ocp-common/job/Flexy-install/54597")
