#!/usr/bin/env python3

import sys
import json
import pathlib
import argparse
import requests


CLUSTER_URL = ''
TOKEN = ''
CPU_QUERY = 'pod:container_cpu_usage:sum{namespace="network-observability"}'
MEM_QUERY = 'sum(container_memory_working_set_bytes{namespace="network-observability",container="",}) BY (pod)'
LOKI_QUERY = 'kubelet_volume_stats_used_bytes{namespace="network-observability", persistentvolumeclaim="loki-store"}'


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
		return
	
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
	parser.add_argument("--url", type=str, help='Cluster URL', required=True)
	parser.add_argument("--token", type=str, help='Token for Bearer auth', required=True)

	# parse arguments
	args = parser.parse_args()
	CLUSTER_URL = args.url
	TOKEN = args.token

	# clean arguments
	CLUSTER_URL = CLUSTER_URL.removeprefix('https://')

	# begin main program execution
	main()
