#!/usr/bin/env python3

import sys
import json
import yaml
import uuid
import urllib3
import pathlib
import jenkins
import logging
import argparse
import requests
import datetime
import subprocess
from elasticsearch import Elasticsearch


# disable SSL warnings
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
RESULTS = {}
DEBUG = False

# query constants
START_TIME = None
END_TIME = None
STEP = None

# benchmark env constants
JENKINS_URL = 'https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/'
JENKINS_JOB = None
JENKINS_BUILD = None
JENKINS_SERVER = None
UUID = None

# elasticsearch constants
ES_SERVER = 'https://search-ocp-qe-perf-scale-test-elk-hcm7wtsqpxy7xogbu72bor4uve.us-east-1.es.amazonaws.com:443'
DUMP = False


def process_query(query, raw_data):
	''' takes in a Prometheus query and its successful execution result
		reformats data into format desired for Elasticsearch upload
		returns dict object with post-processed data
	'''

	# intialize post-processed data object
	clean_data = {
		"metadata": {
			"uuid": UUID,
			"query": query
		},
		"values": []
	}

	try:
		# add metadata artifacts from prometheus return object
		for k, v in raw_data["data"]["result"][0]["metric"].items():
			clean_data["metadata"][k] = v

		# add value artifacts from prometheus return object
		for data_point in raw_data["data"]["result"][0]["values"]:
			clean_data["values"].append({"unix_timestamp": data_point[0], "value": data_point[1]})

	except Exception as e:
		logging.error(f"Error cleaning data from query {query}: {e}")
		logging.error(f"raw_data: {raw_data}")
		logging.error(f"Dumping partially-cleaned data to {DATA_DIR}/data.json")
		dump_data_locally()
		sys.exit(1)

	# return cleaned data
	return clean_data


def run_query(query):
	''' takes in a Prometheus query
		executes a range query based on global constants
		returns the JSON data delievered by Prometheus or an exception if the query fails
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
		logging.debug(f"Executing command '{' '.join(commands[command])}' to get {command} data")
		result = subprocess.run(commands[command], capture_output=True, text=True)

		# record command stdout if execution was succesful
		if result.returncode == 0:
			output = result.stdout[1:-1]
			logging.debug(f"Got back result: {output}")
			outputs[command] = output

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
	info = {"uuid": UUID}
	base_commands = {
		"release": ['oc', 'get', 'pods', '-l', 'app=network-observability-operator', '-o', 'jsonpath="{.items[*].spec.containers[1].env[0].value}"', '-n', 'network-observability'],
		"flp_kind": ['oc', 'get', 'flowcollector', '-o', 'jsonpath="{.items[*].spec.flowlogsPipeline.kind}"', '-n', 'network-observability'],
		"loki_pvc_cap": ['oc', 'get', 'pvc/loki-store', '-o', 'jsonpath="{.status.capacity.storage}"', '-n', 'network-observability'],
		"agent": ['oc', 'get', 'flowcollector', '-o', 'jsonpath="{.items[*].spec.agent}"']
	}

	# collect data from cluster about netobserv operator and store in info dict
	info = run_commands(base_commands, info)

	# get agent details based on detected agent (should be ebpf or ipfix)
	agent = info["agent"]
	agent_commands = {
		"sampling": ['oc', 'get', 'flowcollector', '-o', f'jsonpath="{{.items[*].spec.{agent}.sampling}}"'],
		"cache_active_time": ['oc', 'get', 'flowcollector', '-o', f'jsonpath="{{.items[*].spec.{agent}.cacheActiveTimeout}}"'],
		"cache_max_flows": ['oc', 'get', 'flowcollector', '-o', f'jsonpath="{{.items[*].spec.{agent}.cacheMaxFlows}}"']
	}

	# collect data from cluster about agent and append to info dict
	info = run_commands(agent_commands, info)

	# return all collected data
	return info


def get_jenkins_env_info():
	''' gathers information about Jenkins env
	'''

	# intialize info object
	info = {
		"uuid": UUID,
		"jenkins_job_name": JENKINS_JOB,
		"jenkins_build_num": JENKINS_BUILD
	}

	# collect data from Jenkins server
	try:
		raw_build_info = JENKINS_SERVER.get_build_info(JENKINS_JOB, JENKINS_BUILD)
		logging.debug(f"Jenkins Raw Build Info: {raw_build_info}")
		raw_build_parameters = raw_build_info['actions'][0]['parameters']
		for param in raw_build_parameters:
			del param['_class']
		info['jenkins_job_params'] = raw_build_parameters
	except Exception as e:
		logging.error(f"Failed to collect Jenkins build parameter info: {e}")

	# return all collected data
	return info


def dump_data_locally():
	''' writes captured data in RESULTS dictionary to a JSON file
		file is saved to 'data.json' in DATA_DIR system path
	'''

	# ensure data directory exists (create if not)
	pathlib.Path(DATA_DIR).mkdir(parents=True, exist_ok=True)

	# write prometheus data to data directory
	with open(DATA_DIR + '/data.json', 'w') as data_file:
		json.dump(RESULTS, data_file)

	# return if no issues
	return None


def upload_data_to_elasticsearch():
	''' uploads captured data in RESULTS dictionary to Elasticsearch
	'''

	# create Elasticsearch object and attempt index
	es = Elasticsearch(
		[ES_SERVER]
	)
	for item in RESULTS.items():
		item = {item[0]:item[1]}
		logging.debug(f"Uploading item {item} to Elasticsearch")
		response = es.index(
			index="netobserv-perf",
			body=item
		)
		logging.debug(response['result'])

	# return if no issues
	return None


def main():

	# get jenkins env data if applicable
	if JENKINS_SERVER is not None:
		RESULTS["jenkinsEnv"] = get_jenkins_env_info()

	# get netobserv env data
	RESULTS["netobservEnv"] = get_netobserv_env_info()

	# get prometheus data
	for entry in QUERIES:
		metric_name = entry['metricName']
		query = entry['query']
		raw_data = run_query(query)
		clean_data = process_query(query, raw_data)
		RESULTS[metric_name] = clean_data

	# log success if no issues
	logging.info(f"Data captured successfully")

	# either dump data locally or upload it to Elasticsearch
	if DUMP:
		dump_data_locally()
		logging.info(f"Data written to {DATA_DIR}/data.json")
	else:
		try:
			upload_data_to_elasticsearch()
			logging.info(f"Data uploaded to Elasticsearch")
		except Exception as e:
			logging.error(f"Error uploading to Elasticsearch server: {e}\nA local dump to {DATA_DIR}/data.json will be done instead")
			dump_data_locally()

	# exit if no issues
	sys.exit(0)


if __name__ == '__main__':

	# initialize argument parser
	parser = argparse.ArgumentParser(description='Network Observability Prometheus and Elasticsearch tool (NOPE)')

	# set customization flags
	parser.add_argument("--debug", default=False, action='store_true', help='Flag for additional debug messaging')
	parser.add_argument("--starttime", type=str, required=True, help='Start time for range query')
	parser.add_argument("--endtime", type=str, required=True, help='End time for range query')
	parser.add_argument("--step", type=str, default='10', help='Step time for range query')
	parser.add_argument("--jenkins-job", type=str, help='Jenkins job name to associate with run')
	parser.add_argument("--jenkins-build", type=str, help='Jenkins build number to associate with run')
	parser.add_argument("--user-workloads", default=False, action='store_true', help='Flag to query userWorkload metrics. Ensure FLP service and service-monitor are enabled and some network traffic exists.')
	parser.add_argument("--yaml-file", type=str, default='netobserv-metrics.yaml', help='YAML file from which to source Prometheus queries - defaults to "netobserv-metrics.yaml"')
	parser.add_argument("--uuid", type=str, help='UUID to associate with run - if none is provided one will be generated')
	parser.add_argument("--dump", default=False, action='store_true', help='Flag to dump data locally instead of uploading it to Elasticsearch')

	# parse arguments
	args = parser.parse_args()

	# set logging config
	DEBUG = args.debug
	if DEBUG:
		logging.basicConfig(level=logging.DEBUG)
	else:
		logging.basicConfig(level=logging.INFO)

	# sanity check that kubeconfig is set
	result = subprocess.run(['oc', 'whoami'], capture_output=True, text=True)
	if result.returncode != 0:
		logging.error("Could not connect to cluster - ensure all the Prerequisite steps in the README were followed")
		sys.exit(1)

	# log range query constants
	START_TIME = args.starttime
	END_TIME = args.endtime
	STEP = args.step
	logging.info("Parsed Start Time: " + datetime.datetime.fromtimestamp(int(START_TIME)).strftime('%I:%M%p%Z on %m/%d/%Y'))
	logging.info("Parsed End Time:   " + datetime.datetime.fromtimestamp(int(END_TIME)).strftime('%I:%M%p%Z on %m/%d/%Y'))
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
		JENKINS_JOB = f'scale-ci/e2e-benchmarking-multibranch-pipeline/{raw_jenkins_job}'
		JENKINS_BUILD = int(raw_jenkins_build)
		logging.info(f"Associating run with Jenkins job {JENKINS_JOB} build number {JENKINS_BUILD}")
		try:
			JENKINS_SERVER = jenkins.Jenkins(JENKINS_URL)
		except Exception as e:
			logging.error("Error connecting to Jenkins server: ", e)
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

	# get YAML file with queries
	YAML_FILE = args.yaml_file
	logging.info(f"YAML_FILE: {YAML_FILE}")

	# set queries constant with data from YAML file
	try:
		with open(SCRIPT_DIR + '/' + YAML_FILE, 'r') as yaml_file:
			QUERIES = yaml.safe_load(yaml_file)
	except Exception as e:
		logging.error(f'Failed to read YAML file {YAML_FILE}: {e}')
		sys.exit(1)

	# determine UUID
	UUID = args.uuid
	if UUID is None:
		UUID = str(uuid.uuid4())
	logging.info(f"UUID: {UUID}")

	# determine if data will be dumped locally or uploaded to Elasticsearch
	DUMP = args.dump
	if DUMP:
		logging.info(f"Data will be dumped locally to {DATA_DIR}")
	else:
		logging.info(f"Data will be uploaded to Elasticsearch")

	# begin main program execution
	main()
