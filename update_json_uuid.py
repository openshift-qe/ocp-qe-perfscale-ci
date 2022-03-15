import json
import helper_uuid


def update_with_current_uuid(uuid, workload, flexy_template ): 
    split_temp =helper_uuid.split_flexy_temp(flexy_template)
    
    platform = split_temp[1]
    # use helper functions from write to get data of interst
    with open(workload + "/" + platform + ".json", "r") as fr:
        read_str =fr.read()
        read_json = json.loads(read_str)

    ocp_version = split_temp[0]
    cluster_worker_count = helper_uuid.get_worker_num() 
    cluster_arch_type = helper_uuid.get_arch_type()
    found_uuid = helper_uuid.find_uuid(read_json, ocp_version, cluster_worker_count, cluster_arch_type)
    if found_uuid == "":
        read_json[ocp_version][cluster_worker_count][cluster_arch_type] = uuid
    
    with open(workload + "/" + platform + ".json", "w") as f:
        f.write(json.dumps(read_json))


update_with_current_uuid("uuid","cluster-density","../4.12/P1/IPI-on-Azure-fully-private.install.yaml")