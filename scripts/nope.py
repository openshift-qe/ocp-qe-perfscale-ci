#!/usr/bin/env python3

import sys
import json
import yaml
import pathlib
import subprocess
import argparse
import requests


# directory constants 
ROOT_DIR = str(pathlib.Path(__file__).parent.parent)
SCRIPT_DIR = ROOT_DIR + '/scripts'
DATA_DIR = ROOT_DIR + '/data'

# NOPE constants
CLUSTER_URL = ''
TOKEN = ''
YAML_FILE = ''
QUERIES = {}
RESULTS = {}


def run_query(query):

	# intialize request vars
	endpoint = f"https://prometheus-k8s-openshift-monitoring.apps.{CLUSTER_URL}/api/v1/query"
	headers = {"Authorization": f"Bearer {TOKEN}"}
	params = {
		'query': query
	}

	# make request and return data
	data = requests.get(endpoint, headers=headers, params=params, verify=False)
	return data.json()


def main():

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
	print(f"Data captured successfully and written to {DATA_DIR}")
	sys.exit(0)


if __name__ == '__main__':

	# initialize argument parser
	parser = argparse.ArgumentParser(description='Network Observability Prometheus and Elasticsearch tool (NOPE)')

	# set customization flags
	parser.add_argument("--url", type=str, help='Override for Cluster URL', required=False)
	parser.add_argument("--token", type=str, help='Override for Bearer auth token', required=False)
	parser.add_argument("--yaml_file", type=str, default='netobserv-metrics.yaml', help='YAML file from which to source Prometheus queries - defaults to "netobserv-metrics.yaml"', required=False)

	# parse arguments
	args = parser.parse_args()

	CLUSTER_URL = args.url
	if CLUSTER_URL is None:
		CLUSTER_URL = subprocess.run(['oc', 'get', 'infrastructure', 'cluster', '-o', 'jsonpath="{.status.apiServerURL}"'], capture_output=True, text=True).stdout
		print(f"CLUSTER_URL (raw): {CLUSTER_URL}")

	TOKEN = args.token
	if TOKEN is None:
		TOKEN = subprocess.run(['oc', 'whoami', '-t'], capture_output=True, text=True).stdout
		print(f"TOKEN (raw): {TOKEN}")

	YAML_FILE = args.yaml_file
	print(f"YAML_FILE: {YAML_FILE}")

	# clean arguments
	CLUSTER_URL = CLUSTER_URL.removeprefix('"https://api.')
	CLUSTER_URL = CLUSTER_URL.removesuffix(':6443"')
	print(f"CLUSTER_URL (cleaned): {CLUSTER_URL}")

	TOKEN = TOKEN[:-1]
	print(f"TOKEN (cleaned): {TOKEN}")

	# set queries
	try:
		with open(SCRIPT_DIR + '/' + YAML_FILE, 'r') as yaml_file:
			QUERIES = yaml.safe_load(yaml_file)
	except Exception as e:
		print(f'Failed to read YAML file {YAML_FILE}: {e}')
		sys.exit(1)

	# begin main program execution
	main()
