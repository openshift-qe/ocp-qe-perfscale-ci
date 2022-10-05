#!/usr/bin/env python3

import re
import sys
import time
import json
import pathlib
import argparse
import datetime

# constants 
ROOT_DIR = str(pathlib.Path(__file__).parent.parent)
DATA_DIR = ROOT_DIR + '/data'
WORKLOAD_OUT_FILE = ''

def main():

    # read workload out file
    with open(WORKLOAD_OUT_FILE, 'r') as out_file:
        workload_logs = out_file.read()

    # initialize regexs
    if "kube-burner" in WORKLOAD_OUT_FILE:
        base_regex = 'time="(\d+-\d+-\d+ \d+:\d+:\d+)".*'
        starttime_regex = base_regex + 'Starting'
        endtime_regex = base_regex + 'Exiting'
        strptime_filter = '%Y-%m-%d %H:%M:%S'
    elif "ingress_router" in WORKLOAD_OUT_FILE:
        base_regex = '([a-zA-z]{3}\s+\d+ \d+:\d+:\d+ [a-zA-z]{3} \d+).*'
        starttime_regex = base_regex + 'Testing'
        endtime_regex = base_regex + 'Enabling'
        strptime_filter = '%b %d %H:%M:%S %Z %Y'
    uuid_regex = 'UUID: (.*)"'

    # capture and log strings representations of start and end times
    starttime_string = re.findall(starttime_regex, workload_logs)[0]
    endtime_string = re.findall(endtime_regex, workload_logs)[0]
    uuid = re.findall(uuid_regex, workload_logs)[0]
    print(f"uuid: {uuid}")
    print(f"starttime_string: {starttime_string}")
    print(f"endtime_string: {endtime_string}")

    # convert string times to unix timestamps
    starttime_timestamp = int(datetime.datetime.strptime(starttime_string, strptime_filter).replace(tzinfo=datetime.timezone.utc).timestamp())
    endtime_timestamp = int(datetime.datetime.strptime(endtime_string, strptime_filter).replace(tzinfo=datetime.timezone.utc).timestamp())
    print(f"starttime_timestamp: {starttime_timestamp}")
    print(f"endtime_timestamp: {endtime_timestamp}")

    # construct JSON of workload data
    workload_data = {
        "uuid": str(uuid),
        "starttime_string": str(starttime_string),
        "endtime_string": str(endtime_string),
        "starttime_timestamp": str(starttime_timestamp),
        "endtime_timestamp": str(endtime_timestamp)
    }

    # ensure data directory exists (create if not)
    pathlib.Path(DATA_DIR).mkdir(parents=True, exist_ok=True)

    # write timestamp data to data directory
    with open(DATA_DIR + f'/workload.json', 'w') as data_file:
        json.dump(workload_data, data_file)

    # exit if no issues
    sys.exit(0)

if __name__ == '__main__':

    # initialize argument parser
    parser = argparse.ArgumentParser(description='Mr. Sandman')

    # set logging flags
    parser.add_argument("--file", type=str, required=True, help='File to parse')

    # parse arguments
    args = parser.parse_args()
    WORKLOAD_OUT_FILE = args.file

    # begin main program execution
    main()
