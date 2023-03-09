import subprocess

def run(command):
    try:
        output = subprocess.check_output(command, shell=True, universal_newlines=True)
    except subprocess.CalledProcessError as exc:
        return exc.returncode, exc.output
    return 0, output.strip()

def split_flexy_temp(flexy_template):

    template_folders = flexy_template.split("/")

    for folder in template_folders: 
        if "4_" in folder: 
            version = folder.replace('_',".").split("-")[-1]
            break

    split_temp = template_folders[-2].split("-")

    # 0 ipi or upi
    # 2 cloud type 
    # 3 could be ovn or other specifier 
    
    platform = split_temp[-1]

    net_status, net_type = run("oc get network cluster -o jsonpath='{.status.networkType}'")
    # print('version ' + str(version))
    # print('platform ' + str(platform))
    # print('net_type ' + str(net_type))
    return version, platform, net_type

def get_worker_num():
    return_code, worker_count = run("oc get nodes | grep worker | wc -l | xargs")
    if return_code != 0:
        worker_count = "ERROR"
    return worker_count

def get_arch_type():
    
    node_ret_code, node_name = run("oc get node --no-headers | grep master| head -1| awk '{print $1}'")
    if node_ret_code != 0: 
        return  ""
    node_name = node_name
    arch_ret_code, arch_name = run("oc get node " + node_name + " -o jsonpath='{.status.nodeInfo.architecture}'")
    return arch_name

def find_uuid(read_json, ocp_version, cluster_worker_count, network_type_string, cluster_arch_type):

    for json_versions, sub_vers_json in read_json.items(): 
        if str(json_versions) == str(ocp_version):
            for worker_count, sub_worker_json in sub_vers_json.items():
                if str(cluster_worker_count) == str(worker_count):
                    if "ovn" in network_type_string.lower():
                        network_type = "OVN"
                    else:
                        network_type = "SDN"
                    return sub_worker_json[network_type][cluster_arch_type]
