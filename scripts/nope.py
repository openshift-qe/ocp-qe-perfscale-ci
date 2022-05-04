#!/usr/bin/env python3

import sys
import json
import pathlib
import subprocess
import argparse
import requests


CLUSTER_URL = ''
TOKEN = ''
NAMESPACE = ''
CPU_QUERY = ''
MEM_QUERY = ''
LOKI_QUERY = ''


def run_query(query_type=''):

	# intialize request vars
	headers = {"Authorization": f"Bearer {TOKEN}"}
	params = {}
	endpoint = f"https://prometheus-k8s-openshift-monitoring.apps.{CLUSTER_URL}/api/v1/query"

	# build payload based on query type
	if query_type == "cpu":
		params = {
			'query': CPU_QUERY
		}
	elif query_type == "mem":
		params = {
			'query': MEM_QUERY
		}
	elif query_type == "loki":
		params = {
			'query': LOKI_QUERY
		}
	else:
		print(f"invalid query_type: {query_type}")
		sys.exit(1)
	
	# make request and return data
	data = requests.get(endpoint, headers=headers, params=params, verify=False)
	return data.json()


def get_cpu_usage():
	cpu_data = run_query('cpu')
	return cpu_data


def get_mem_usage():
	mem_data = run_query('mem')
	return mem_data


def get_loki_store():
	loki_data = run_query('loki')
	return loki_data


def main():

	# get prometheus data
	cpu_data = get_cpu_usage()
	mem_data = get_mem_usage()
	loki_data = get_loki_store()

	# ensure data directory exists (create if not)
	data_dir = str(pathlib.Path(__file__).parent.parent) + '/data'
	pathlib.Path(data_dir).mkdir(parents=True, exist_ok=True)

	# write prometheus data to data directory
	with open(data_dir + '/cpu_data.json', 'w') as cpu_file:
		json.dump(cpu_data, cpu_file)

	with open(data_dir + '/mem_data.json', 'w') as mem_file:
		json.dump(mem_data, mem_file)

	with open(data_dir + '/loki_data.json', 'w') as loki_file:
		json.dump(loki_data, loki_file)

	# exit if no issues
	print(f"Data captured successfully and written to {data_dir}")
	sys.exit(0)


if __name__ == '__main__':

	# initialize argument parser
	parser = argparse.ArgumentParser(description='Network Observability Prometheus and Elasticsearch tool (NOPE)')

	# set customization flags
	parser.add_argument("--url", type=str, help='Override for Cluster URL', required=False)
	parser.add_argument("--token", type=str, help='Override for Bearer auth token', required=False)
	parser.add_argument("--namespace", type=str, default='network-observability', help='Namespace for query - defaults to "network-observability"', required=False)

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

	NAMESPACE = args.namespace
	print(f"NAMESPACE: {NAMESPACE}")

	# clean arguments
	CLUSTER_URL = CLUSTER_URL.removeprefix('"https://api.')
	CLUSTER_URL = CLUSTER_URL.removesuffix(':6443"')
	print(f"CLUSTER_URL (cleaned): {CLUSTER_URL}")

	TOKEN = TOKEN[:-1]
	print(f"TOKEN (cleaned): {TOKEN}")

	# set query constants
	CPU_QUERY = f'pod:container_cpu_usage:sum{{namespace="{NAMESPACE}"}}'
	MEM_QUERY = f'sum(container_memory_working_set_bytes{{namespace="{NAMESPACE}",container="",}}) BY (pod)'
	LOKI_QUERY = f'kubelet_volume_stats_used_bytes{{namespace="{NAMESPACE}", persistentvolumeclaim="loki-store"}}'

	# begin main program execution
	main()
