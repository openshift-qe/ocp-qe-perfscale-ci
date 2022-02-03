import write_helper
import yaml

def get_output(job_type):
    if job_type == "etcd-perf":
        return get_99_latency()
    else:
        return 0

# No longer need to get job iterations, going to pass from kube-burner job
def get_kube_burner_config():
    return_code, configmap_name = write_helper.run('oc get configmap -n benchmark-operator -o name --sort-by "{.metadata.creationTimestamp}" --no-headers| grep "kube-burner" | tail -n 1')
    return_code, config_yaml = write_helper.run("oc get %s -n benchmark-operator -o jsonpath='{.data.config\.yml}'" % configmap_name.strip())
    config_jobs = config_yaml.split("jobs")
    print('jobs ' +str(config_jobs[1]))
    config_job_yaml = yaml.safe_load(config_jobs[1][2:])
    print("jobIterations" + str(config_job_yaml[0]['jobIterations']))
    return config_job_yaml[0]['jobIterations']

def get_99_latency():
    return_code, str_uuid = write_helper.run("oc get benchmark -n benchmark-operator etcd-fio -o 'jsonpath={.status.uuid}'")
    uuid = str_uuid.split("=")[-1]
    json_to_find = '{"_source": false, "aggs": {"max-fsync-lat-99th": {"max": {"field": "fio.sync.lat_ns.percentile.99.000000"}}}}'

    return_code, es_url = write_helper.run("oc get benchmark -n benchmark-operator etcd-fio -o 'jsonpath={.spec.elasticsearch.url}'")
    return_code, latency = write_helper.run(f"curl -s '{es_url}/ripsaw-fio-results/_search?q=uuid:{uuid}' -H 'Content-Type: application/json' -d '{json_to_find}'")
    latency_yaml = yaml.safe_load(latency)
    val_99 = latency_yaml['aggregations']['max-fsync-lat-99th']["value"]
    return val_99

