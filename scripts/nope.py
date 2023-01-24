#!/usr/bin/env python3

import os
import sys
import json
import yaml
import uuid
import time
import urllib3
import pathlib
import jenkins
import logging
import argparse
import requests
import datetime
import subprocess
import coloredlogs
from elasticsearch import Elasticsearch


# disable SSL and warnings
os.environ['PYTHONHTTPSVERIFY'] = '0'
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# directory constants 
ROOT_DIR = str(pathlib.Path(__file__).parent.parent)
SCRIPT_DIR = ROOT_DIR + '/scripts'
DATA_DIR = ROOT_DIR + '/data'

# NOPE constants
THANOS_URL = ''
TOKEN = ''
YAML_FILE = ''
QUERIES = {}
RESULTS = {"data": []}
DEBUG = False

# prometheus query constants
START_TIME = None
END_TIME = None
STEP = None

# jenkins env constants
JENKINS_URL = 'https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/'
JENKINS_JOB = None
JENKINS_BUILD = None
JENKINS_SERVER = None
UUID = None

# elasticsearch constants
ES_URL = 'search-ocp-qe-perf-scale-test-elk-hcm7wtsqpxy7xogbu72bor4uve.us-east-1.es.amazonaws.com'
ES_USERNAME = os.getenv('ES_USERNAME')
ES_PASSWORD = os.getenv('ES_PASSWORD')
DUMP = False
UPLOAD_FILE = ''

def process_query(metric_name, query, raw_data):
    ''' takes in a Prometheus metric name, query and its successful execution result
        reformats data into format desired for Elasticsearch upload
        returns dict object with post-processed data
    '''

    # intialize post-processing data object
    clean_data = []

    # capture metadata and value artifacts from prometheus return object
    try:
        for result in raw_data["data"]["result"]:
            for data_point in result["values"]:
                metadata = result["metric"]
                metadata["query"] = query
                iso_timestamp = datetime.datetime.utcfromtimestamp(data_point[0]).isoformat() + 'Z'
                clean_data.append(
                    {
                        "uuid": UUID,
                        "metric_name": metric_name,
                        "data_type": "datapoint",
                        "iso_timestamp": iso_timestamp,
                        "unix_timestamp": data_point[0],
                        "value": float(data_point[1]),
                        "metadata": metadata
                    }
                )

    except Exception as e:
        timestamp = datetime.datetime.now().strftime('%Y-%m-%d_%H-%M-%S')
        logging.error(f"Error cleaning {metric_name} data from query {query}: {e}")
        logging.error(f"raw_data: {raw_data}")
        logging.error(f"Dumping partially-cleaned data to {DATA_DIR}/partial_data_{timestamp}.json")
        dump_data_locally(timestamp, partial=True)
        sys.exit(1)

    # return cleaned data
    return clean_data


def run_query(query):
    ''' takes in a Prometheus query
        executes a range query based on global constants
        returns the JSON data delivered by Prometheus or an exception if the query fails
    '''

    # construct request
    headers = {"Authorization": f"Bearer {TOKEN}"}
    endpoint = f"{THANOS_URL}/api/v1/query_range"
    params = {
        'query': query,
        'start': START_TIME,
        'end': END_TIME,
        'step': STEP
    }

    # make request and return data
    data = requests.get(endpoint, headers=headers, params=params, verify=False)
    if data.status_code != 200:
        raise Exception(f"Query to fetch Prometheus data failed: {data.reason}\nTry again using `--user-workloads` argument for Prometheus user workloads if you did not already.") 
    return data.json()


def run_commands(commands, outputs={}):
    ''' executes dictionary of commands where key is identifier and value is command
        raises Exception if command fails
        returns outputs dictionary, either new or appended to passed dict
    '''

    # iterate through commands dictionary
    for command in commands:
        logging.debug(f"Executing command '{commands[command]}' to get {command} data")
        result = subprocess.run(commands[command], capture_output=True, text=True, shell=True, timeout=600)

        # record command stdout if execution was succesful
        if result.returncode == 0:
            output = result.stdout
            logging.debug(f"Got back result: {output}")

            # if aws_s3_bucket_usage command, split up the data to two different metadata fields
            if command == 'aws_s3_bucket_usage':
                aws_data = output.replace(" ","").splitlines()
                aws_buckets = aws_data[0].split(':', 1)[1]
                aws_size = aws_data[1].split(':', 1)[1]
                logging.debug(f"aws_s3_bucket_objects calculated as {aws_buckets}")
                outputs['aws_s3_bucket_objects'] = aws_buckets
                logging.debug(f"aws_s3_bucket_size calculated as {aws_size}")
                outputs['aws_s3_bucket_size'] = aws_size
            # otherwise map command output to dict entry
            else:
                outputs[command] = output

        # if command failed but was AWS-specific, don't block, just continue
        elif 'aws' in command:
            output = result.stdout
            logging.debug(f"Got back result: {output} from AWS command - skipping...")
            outputs[command] = "N/A"

        # otherwise raise an Exception with stderr
        else:
            raise Exception(f"Command '{command}' execution resulted in stderr output: {result.stderr}")

    # if all commands were successful return outputs dictionary
    return outputs


def get_netobserv_env_info():
    ''' gathers information about netobserv operator env
        returns info dictionary where key is identifier and value is command output
    '''

    # intialize info and base_commands objects
    iso_timestamp = datetime.datetime.utcfromtimestamp(int(START_TIME)).isoformat() + 'Z'
    info = {
        "uuid": UUID,
        "metric_name": "netobservEnv",
        "data_type": "metadata",
        "iso_timestamp": iso_timestamp,
    }
    base_commands = {
        "release": 'oc get pods -l app=netobserv-operator -o jsonpath="{.items[*].spec.containers[1].env[0].value}" -A',
        "loki": 'oc get sub -n openshift-operators-redhat loki-operator -o jsonpath="{.status.currentCSV}"',
        "deploymentModel": 'oc get flowcollector -o jsonpath="{.items[*].spec.deploymentModel}" -n netobserv',
        "agent": 'oc get flowcollector -o jsonpath="{.items[*].spec.agent.type}"',
        "aws_s3_bucket_name": 'oc extract cm/lokistack-config -n netobserv --keys=config.yaml --confirm --to=/tmp | xargs -I {} egrep bucketnames {} | cut -d: -f 2 | xargs echo -n'
    }

    # collect data from cluster about netobserv operator and store in info dict
    info = run_commands(base_commands, info)

    # get flp_kind data from kafka data
    deploymentModel = info["deploymentModel"].lower()
    logging.debug(f"Found deployment model {deploymentModel}")
    if deploymentModel == 'kafka':
        logging.debug("Kafka is enabled - flp_kind is 'Deployment'")
        info["flp_kind"] = "Deployment"
    else:
        logging.debug("Kafka is disabled - flp_kind is 'DaemonSet'")
        info["flp_kind"] = "DaemonSet"

    # run any additional commands needed and append data to info dictionary
    agent = info["agent"].lower()
    logging.debug(f"Found collector agent {agent}")
    s3_bucket_name = info["aws_s3_bucket_name"]
    logging.debug(f"Found AWS S3 bucket name {s3_bucket_name}")
    additional_commands = {
        "sampling": f'oc get flowcollector -o jsonpath="{{.items[*].spec.agent.{agent}.sampling}}"',
        "cache_active_time": f'oc get flowcollector -o jsonpath="{{.items[*].spec.agent.{agent}.cacheActiveTimeout}}"',
        "cache_max_flows": f'oc get flowcollector -o jsonpath="{{.items[*].spec.agent.{agent}.cacheMaxFlows}}"',
        "aws_s3_bucket_usage": f'aws s3 ls --summarize --human-readable --recursive s3://{s3_bucket_name} | tail -2'
    }
    if deploymentModel == 'kafka':
        additional_commands["kafka_replicas"] = f'oc get flowcollector -o jsonpath="{{.items[*].spec.processor.kafkaConsumerReplicas}}"'
        additional_commands["kafka_brokers"] = f'oc get Kafka -o jsonpath="{{.items[*].spec.kafka.replicas}}" -n netobserv'
    else:
        info["kafka_replicas"] = "N/A"
        info["kafka_brokers"] = "N/A"
    info = run_commands(additional_commands, info)

    # return all collected data
    return info


def get_jenkins_env_info():
    ''' gathers information about Jenkins env
        if build parameter data cannot be collected, only command line data will be included
    '''

    # intialize info object
    iso_timestamp = datetime.datetime.utcfromtimestamp(int(START_TIME)).isoformat() + 'Z'
    info = {
        "uuid": UUID,
        "metric_name": "jenkinsEnv",
        "data_type": "metadata",
        "iso_timestamp": iso_timestamp,
        "jenkins_job_name": JENKINS_JOB,
        "jenkins_build_num": JENKINS_BUILD
    }

    # collect data from Jenkins server
    try:
        build_info = JENKINS_SERVER.get_build_info(JENKINS_JOB, JENKINS_BUILD)
        logging.debug(f"Jenkins Build Info: {build_info}")
        build_actions = build_info['actions']
        build_parameters = None
        for action in build_actions:
            if action.get('_class') == 'hudson.model.ParametersAction':
                build_parameters = action['parameters']
                break
        if build_parameters is None:
            raise Exception("No build parameters could be found.")
        for param in build_parameters:
            del param['_class']
            if param.get('name') == 'WORKLOAD':
                info['workload'] = str(param.get('value'))
            if param.get('name') == 'VARIABLE':
                info['variable'] = int(param.get('value'))
    except Exception as e:
        logging.error(f"Failed to collect Jenkins build parameter info: {e}")

    # return all collected data
    return info


def dump_data_locally(timestamp, partial=False):
    ''' writes captured data in RESULTS dictionary to a JSON file
        file is saved to 'data_{timestamp}.json' in DATA_DIR system path if data is complete
        file is saved to 'partial_data_{timestamp}.json' in DATA_DIR system path if data is incomplete
    '''

    # ensure data directory exists (create if not)
    pathlib.Path(DATA_DIR).mkdir(parents=True, exist_ok=True)

    # write prometheus data to data directory
    if not partial:
        with open(DATA_DIR + f'/data_{timestamp}.json', 'w') as data_file:
            json.dump(RESULTS, data_file)
    else:
        with open(DATA_DIR + f'/partial_data_{timestamp}.json', 'w') as data_file:
            json.dump(RESULTS, data_file)

    # return if no issues
    return None


def upload_data_to_elasticsearch():
    ''' uploads captured data in RESULTS dictionary to Elasticsearch
    '''

    # create Elasticsearch object and attempt index
    es = Elasticsearch(
        [f'https://{ES_USERNAME}:{ES_PASSWORD}@{ES_URL}:443']
    )

    start = time.time()
    for item in RESULTS['data']:
        metric_name = item.get('metric_name')
        if metric_name == 'netobservEnv':
            index = 'prod-netobserv-operator-metadata'
        elif metric_name == 'jenkinsEnv':
            index = 'prod-netobserv-jenkins-metadata'
        else:
            index = 'prod-netobserv-datapoints'
        logging.debug(f"Uploading item {item} to index {index} in Elasticsearch")
        response = es.index(
            index=index,
            body=item
        )
        logging.debug(f"Response back was {response}")
    end = time.time()
    elapsed_time = end - start

    # return elapsed time for upload if no issues
    return elapsed_time


def main():

    # get jenkins env data if applicable
    if JENKINS_SERVER is not None:
        RESULTS["data"].append(get_jenkins_env_info())

    # get netobserv env data
    RESULTS["data"].append(get_netobserv_env_info())

    # get prometheus data
    for entry in QUERIES:
        metric_name = entry['metricName']
        query = entry['query']
        raw_data = run_query(query)
        clean_data = process_query(metric_name, query, raw_data)
        RESULTS["data"].extend(clean_data)

    # log success if no issues
    logging.info(f"Data captured successfully")

    # either dump data locally or upload it to Elasticsearch
    timestamp = datetime.datetime.now().strftime('%Y-%m-%d_%H-%M-%S')
    if DUMP:
        dump_data_locally(timestamp)
        logging.info(f"Data written to {DATA_DIR}/data_{timestamp}.json")
    else:
        try:
            elapsed_time = upload_data_to_elasticsearch()
            logging.info(f"Elasticsearch upload completed in {elapsed_time} seconds")
        except Exception as e:
            logging.error(f"Error uploading to Elasticsearch server: {e}\nA local dump to {DATA_DIR}/data_{timestamp}.json will be done instead")
            dump_data_locally(timestamp)
            # using exit code of 2 here so that Jenkins pipeline can unqiuely identify this error
            sys.exit(2)

    # exit if no issues
    sys.exit(0)


if __name__ == '__main__':

    # initialize argument parser
    parser = argparse.ArgumentParser(description='Network Observability Prometheus and Elasticsearch tool (NOPE)')

    # set logging flags
    parser.add_argument("--debug", default=False, action='store_true', help='Flag for additional debug messaging')

    # set standard mode flags
    standard = parser.add_argument_group("Standard Mode", "Connect to an OCP cluster and gather data via Prometheus queries")
    standard.add_argument("--yaml-file", type=str, default='netobserv_queries_ebpf.yaml', help='YAML file from which to source Prometheus queries - defaults to "netobserv_queries_ebpf.yaml"')
    standard.add_argument("--user-workloads", default=False, action='store_true', help='Flag to query userWorkload metrics. Ensure FLP service and service-monitor are enabled and some network traffic exists.')
    standard.add_argument("--starttime", type=str, help='Start time for range query')
    standard.add_argument("--endtime", type=str, help='End time for range query')
    standard.add_argument("--step", type=str, default='60', help='Step time for range query')
    standard.add_argument("--jenkins-job", type=str, help='Jenkins job name to associate with run')
    standard.add_argument("--jenkins-build", type=str, help='Jenkins build number to associate with run')
    standard.add_argument("--uuid", type=str, help='UUID to associate with run - if none is provided one will be generated')
    standard.add_argument("--dump", default=False, action='store_true', help='Flag to dump data locally instead of uploading it to Elasticsearch')

    # set upload mode flags
    upload = parser.add_argument_group("Upload Mode", "Directly upload data from a previously generated JSON file to Elasticsearch")
    upload.add_argument("--upload-file", type=str, default='', help='JSON file to upload to Elasticsearch. Must be in the "data" directory. Note this flag runs the NOPE tool in Upload mode and causes all flags other than --debug to be IGNORED.')

    # parse arguments
    args = parser.parse_args()

    # set logging config
    DEBUG = args.debug
    if DEBUG:
        logging.basicConfig(level=logging.DEBUG)
        coloredlogs.install(level='DEBUG', isatty=True)
    else:
        logging.basicConfig(level=logging.INFO)
        coloredlogs.install(level='INFO', isatty=True)

    # if running in upload mode - immediately load JSON, upload, and exit
    UPLOAD_FILE = args.upload_file
    if UPLOAD_FILE != '':
        upload_file_path = DATA_DIR + '/' + UPLOAD_FILE
        logging.info(f"Running NOPE tool in Upload mode - data from {upload_file_path} will be uploaded to Elasticsearch")

        # read data json file
        with open(upload_file_path) as json_file:
            RESULTS = json.load(json_file)

        # upload data to elasticsearch
        try:
            elapsed_time = upload_data_to_elasticsearch()
            logging.info(f"Elasticsearch upload completed in {elapsed_time} seconds")
            sys.exit(0)
        except Exception as e:
            logging.error(f"Error uploading to Elasticsearch server: {e}")
            sys.exit(1)

    # sanity check that kubeconfig is set
    result = subprocess.run(['oc', 'whoami'], capture_output=True, text=True)
    if result.returncode != 0:
        logging.error("Could not connect to cluster - ensure all the Prerequisite steps in the README were followed")
        sys.exit(1)

    # log prometheus range query constants
    START_TIME = args.starttime
    END_TIME = args.endtime
    STEP = args.step
    if START_TIME == '' or END_TIME == '':
        logging.error("START_TIME and END_TIME are needed to proceed")
        sys.exit(1)
    else:
        logging.info("Parsed Start Time: " + datetime.datetime.utcfromtimestamp(int(START_TIME)).strftime('%I:%M%p%Z UTC on %m/%d/%Y'))
        logging.info("Parsed End Time:   " + datetime.datetime.utcfromtimestamp(int(END_TIME)).strftime('%I:%M%p%Z UTC on %m/%d/%Y'))
        logging.info("Step is:           " + STEP)

    # check if Jenkins arguments are valid and if so set constants
    raw_jenkins_job = args.jenkins_job
    raw_jenkins_build = args.jenkins_build
    if all(v is None for v in [raw_jenkins_job, raw_jenkins_build]):
        JENKINS_SERVER = None
    elif any(v is None for v in [raw_jenkins_job, raw_jenkins_build]):
        logging.error("JENKINS_JOB and JENKINS_BUILD must all be used together or not at all")
        sys.exit(1)
    else:
        JENKINS_JOB = raw_jenkins_job
        JENKINS_BUILD = int(raw_jenkins_build)
        logging.info(f"Associating run with Jenkins job {JENKINS_JOB} build number {JENKINS_BUILD}")
        try:
            JENKINS_SERVER = jenkins.Jenkins(JENKINS_URL)
        except Exception as e:
            logging.error("Error connecting to Jenkins server: ", e)
            sys.exit(1)

    # determine UUID
    UUID = args.uuid
    if UUID is None:
        UUID = str(uuid.uuid4())
    logging.info(f"UUID: {UUID}")

    # get YAML file with queries and set queries constant with data from YAML file
    YAML_FILE = args.yaml_file
    logging.info(f"YAML_FILE: {YAML_FILE}")
    try:
        with open(SCRIPT_DIR + '/queries/' + YAML_FILE, 'r') as yaml_file:
            QUERIES = yaml.safe_load(yaml_file)
    except Exception as e:
        logging.error(f'Failed to read YAML file {YAML_FILE}: {e}')
        sys.exit(1)

    # get thanos URL from cluster
    raw_thanos_url = subprocess.run(['oc', 'get', 'route', 'thanos-querier', '-n', 'openshift-monitoring', '-o', 'jsonpath="{.spec.host}"'], capture_output=True, text=True).stdout
    THANOS_URL = "https://" + raw_thanos_url[1:-1]
    logging.info(f"THANOS_URL: {THANOS_URL}")

    # get token from cluster
    user_workloads = args.user_workloads
    if user_workloads:
        TOKEN = subprocess.run(['oc', 'sa', 'new-token', 'prometheus-user-workload', '-n', 'openshift-user-workload-monitoring'], capture_output=True, text=True).stdout
        if TOKEN == '':
            logging.error("No token could be found - ensure all the Prerequisite steps in the README were followed")
            sys.exit(1)
    else:
        raw_token = subprocess.run(['oc', 'whoami', '-t'], capture_output=True, text=True).stdout
        TOKEN = raw_token[:-1]
    logging.info(f"TOKEN: {TOKEN}")

    # determine if data will be dumped locally or uploaded to Elasticsearch
    DUMP = args.dump
    if DUMP:
        logging.info(f"Data will be dumped locally to {DATA_DIR}")
    else:
        if (ES_USERNAME is None) or (ES_PASSWORD is None):
            logging.error("Credentials need to be set to upload data to Elasticsearch")
            sys.exit(1)
        logging.info(f"Data will be uploaded to Elasticsearch")

    # begin main program execution
    main()
