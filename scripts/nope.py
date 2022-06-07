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
IS_RANGE = False
START_TIME = None
END_TIME = None
STEP = None

# benchmark env constants
JENKINS_URL = 'https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/'
JENKINS_JOB = None
JENKINS_BUILD = None
JENKINS_SERVER = None
UUID = None


def run_query(query):
	''' takes in a Prometheus query
		executes either regular or range query based on global constants
		returns the JSON data delievered by Prometheus or an exception if the query fails
	'''

	# construct request
	headers = {"Authorization": f"Bearer {TOKEN}"}
	if IS_RANGE:
		endpoint = f"{THANOS_URL}/api/v1/query_range"
		params = {
			'query': query,
			'start': START_TIME,
			'end': END_TIME,
			'step': STEP
		}
	else:
		endpoint = f"{THANOS_URL}/api/v1/query"
		params = {
			'query': query
		}

	# make request and return data
	data = requests.get(endpoint, headers=headers, params=params, verify=False)
	if data.status_code != 200:
		raise Exception("Query to fetch Prometheus data failed. Try again using `--user-workloads` argument for Prometheus user workloads if you did not already.") 
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
	info = {}
	base_commands = {
		"release": ['oc', 'get', 'pods', '-l', 'app=network-observability-operator', '-o', 'jsonpath="{.items[0].metadata.labels.version}"', '-n', 'network-observability'],
		"flp_kind": ['oc', 'get', 'flowcollector', '-o', 'jsonpath="{.items[*].spec.flowlogsPipeline.kind}"', '-n', 'network-observability'],
		"loki_pvc_cap": ['oc', 'get', 'pvc/loki-store', '-o', 'jsonpath="{.status.capacity.storage}"', '-n', 'network-observability'],
		"agent": ['oc', 'get', 'flowcollector', '-o', 'jsonpath="{.items[*].spec.agent}"']
	}

	# collect data from cluster about netobserv operator and store in info dict
	info = run_commands(base_commands)

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


def get_benchmark_env_info():
	''' gathers information about benchmark env
	'''

	# intialize info object
	info = {}

	# get passed or generated UUID
	info['uuid'] = UUID

	# collect data from Jenkins server if applicable
	if JENKINS_SERVER is not None:
		raw_build_info = JENKINS_SERVER.get_build_info(JENKINS_JOB, JENKINS_BUILD)
		raw_build_parameters = raw_build_info['actions'][1]['parameters']
		for param in raw_build_parameters:
			del param['_class']
		info['jenkins_job_params'] = raw_build_parameters

	# return all collected data
	return info


def main():

	# get benchmark env data
	RESULTS["benchmarkEnv"] = get_benchmark_env_info()

	# get netobserv env data
	RESULTS["netobservEnv"] = get_netobserv_env_info()

	# get prometheus data
	for entry in QUERIES:
		metric_name = entry['metricName']
		query = entry['query']
		RESULTS[metric_name] = run_query(query)

	# ensure data directory exists (create if not)
	pathlib.Path(DATA_DIR).mkdir(parents=True, exist_ok=True)

	# write prometheus data to data directory
	with open(DATA_DIR + '/data.json', 'w') as data_file:
		json.dump(RESULTS, data_file)

	# exit if no issues
	logging.info(f"Data captured successfully and written to {DATA_DIR}")
	sys.exit(0)


if __name__ == '__main__':

	# initialize argument parser
	parser = argparse.ArgumentParser(description='Network Observability Prometheus and Elasticsearch tool (NOPE)')

	# set customization flags
	parser.add_argument("--debug", default=False, action='store_true', help='Flag for additional debug messaging')
	parser.add_argument("--starttime", type=str, help='Start time for range query - must be used in conjuncture with --endtime and --step')
	parser.add_argument("--endtime", type=str, help='End time for range query - must be used in conjuncture with --starttime and --step')
	parser.add_argument("--step", type=str, help='Step time for range query - must be used in conjuncture with --starttime and --endtime')
	parser.add_argument("--jenkins-job", type=str, help='Jenkins job name to associate with run')
	parser.add_argument("--jenkins-build", type=str, help='Jenkins build number to associate with run')
	parser.add_argument("--user-workloads", default=False, action='store_true', help='Flag to query userWorkload metrics. Ensure FLP service and service-monitor are enabled and some network traffic exists.')
	parser.add_argument("--yaml-file", type=str, default='netobserv-metrics.yaml', help='YAML file from which to source Prometheus queries - defaults to "netobserv-metrics.yaml"')
	parser.add_argument("--uuid", type=str, help='UUID to associate with run - if none is provided one will be generated')

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

	# check if range query arguments are valid and if so set constants
	START_TIME = args.starttime
	END_TIME = args.endtime
	STEP = args.step
	if all(v is None for v in [START_TIME, END_TIME, STEP]):
		IS_RANGE = False
	elif any(v is None for v in [START_TIME, END_TIME, STEP]):
		logging.error("START_TIME, END_TIME, and STEP must all be used together or not at all")
		sys.exit(1)
	else:
		logging.info("Parsed Start Time: " + datetime.datetime.fromtimestamp(int(START_TIME)).strftime('%I:%M%p%Z on %m/%d/%Y'))
		logging.info("Parsed End Time:   " + datetime.datetime.fromtimestamp(int(END_TIME)).strftime('%I:%M%p%Z on %m/%d/%Y'))
		IS_RANGE = True

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
		TOKEN = subprocess.run(['oc', 'sa', 'get-token', 'prometheus-user-workload', '-n', 'openshift-user-workload-monitoring'], capture_output=True, text=True).stdout
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

	# begin main program execution
	main()
