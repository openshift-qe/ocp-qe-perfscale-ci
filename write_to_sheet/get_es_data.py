import yaml
import json
import subprocess
import datetime
from pytz import timezone

def run(command):
    try:
        output = subprocess.check_output(command, shell=True, universal_newlines=True)
    except subprocess.CalledProcessError as exc:
        print("Status : FAIL", exc.returncode, exc.output)
        return exc.returncode, exc.output
    return 0, output


def find_key_to_overwrite(json_file, find_key, new_value):
    counter = 0
    for filters_list in json_file['query']['bool']['filter']:
        for filters, values in filters_list.items():
            for k, v in values.items():
                if k == find_key:
                    json_file['query']['bool']['filter'][counter][filters][k] = new_value
                    return json_file
                if type(v) is dict:
                    for k2, v2 in v.items():
                        if k2 == find_key:
                            json_file['query']['bool']['filter'][counter][filters][k][k2] = new_value
                            return json_file
        counter += 1


def print_new_json(new_value, find_key, fileName):
    # append to file
    with open(fileName, "r") as f:
        json_file = json.loads(f.read())

    new_json_file = find_key_to_overwrite(json_file, find_key, new_value)
    with open(fileName, "w+") as f:
        json.dump(new_json_file, f, indent=4)

def get_benchmark_data(uuid):

    return_code, benchmark_str = run("oc get benchmark -n benchmark-operator -o yaml")
    if return_code == 0:
        benchmark_yaml_all = yaml.safe_load(benchmark_str)
        if len(benchmark_yaml_all['items']) > 0:
            for benchmark_item in benchmark_yaml_all['items']:
                if uuid == benchmark_item['spec']['uuid']:
                    es_url = benchmark_item['spec']['elasticsearch']['url']
                    creation_time = benchmark_item['metadata']['creationTimestamp'][:-1] + ".000Z"
                    return es_url, creation_time
    return "https://search-perfscale-dev-chmf5l4sh66lvxbnadi4bznl3a.us-west-2.es.amazonaws.com:443", get_project_creation_time(uuid)

def rewrite_data(start_time, uuid, file_name):

    print_new_json(start_time,"gte", file_name)
    print_new_json(uuid, "uuid", file_name)
    # rewrite lte with current date
    tz = timezone('UTC')
    end_time = datetime.datetime.now(tz).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"
    print_new_json(end_time, "lte", file_name)

def execute_command(es_url, fileName):
    with open(fileName, "r") as f:
        data_json = f.read()
    return_code, str_response = run(f"curl -X GET {es_url}/_search?pretty -H 'Content-Type: application/json' -d'{data_json}'")
    if return_code == 0:
        json_response = json.loads(str_response)
        return json_response
    else:
        return {}


def get_data_from_json(json_data):
    return [json_data['quantileName'], json_data['avg'], json_data['P99']]


def get_pod_latency_data(uuid):
    file_name = "get_es_data.json"
    es_url, creation_time = get_benchmark_data(uuid)
    if es_url != "":
        rewrite_data(creation_time, uuid, file_name)
        json_response = execute_command(es_url, file_name)
        data_info = []
        if "hits" in json_response['hits'].keys():
            for hits in json_response['hits']['hits']:
                data_info.append(get_data_from_json(hits['_source']))
            if len(data_info) > 0:
                sorted_data = sorted(data_info, key=lambda kv:(kv[0], kv[1], kv[2]), reverse=True)
                return sorted_data
    return []

def get_project_creation_time(uuid=""):
    return_code, start_time = run("oc get project benchmark-operator -o jsonpath='{.metadata.creationTimestamp}'")
    if return_code == 0:
        return start_time

    if uuid != "":
        return_code, start_time = run("oc get project -l kube-burner-uuid=%s  -o jsonpath='{.items[0].metadata.creationTimestamp}'" % uuid)
        if return_code == 0:
            return start_time
    return ""

def get_uuid_uperf(cluster_name):
    file_name = "uperf_find_uuid.json"

    start_time = get_project_creation_time()

    #start time to be when benchmark-operator was created
    print_new_json(start_time, "gte", file_name)
    print_new_json(cluster_name, "cluster_name", file_name)
    # rewrite lte with current date
    tz = timezone('UTC')
    end_time = datetime.datetime.now(tz).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"
    print_new_json(end_time, "lte", file_name)
    es_url = "https://search-perfscale-dev-chmf5l4sh66lvxbnadi4bznl3a.us-west-2.es.amazonaws.com:443"
    json_response = execute_command(es_url, file_name)
    # want to find most recent, list should already be ordered
    if "hits" in json_response['hits'].keys():
        for hits in json_response['hits']['hits']:
            if "_source" not in hits and "uuid" not in hits['_source']:
                return ""
            return hits['_source']['uuid']
    return ""
