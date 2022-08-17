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
    base_regex = '([a-zA-z]{3}\s+\d+ \d+:\d+:\d+ [a-zA-z]{3} \d+).*'
    if "kube-burner" in WORKLOAD_OUT_FILE:
        starttime_regex = base_regex + 'Deploying'
        endtime_regex = base_regex + 'Indexing'
    elif "ingress_router" in WORKLOAD_OUT_FILE:
        starttime_regex = base_regex + 'Testing'
        endtime_regex = base_regex + 'Enabling'
    uuid_regex = 'UUID: (.*)\n'

    # capture and log strings representations of start and end times
    start_stringtime = re.findall(starttime_regex, workload_logs)[0]
    end_stringtime = re.findall(endtime_regex, workload_logs)[0]
    uuid = re.findall(uuid_regex, workload_logs)[-1]
    print(f"start_stringtime: {start_stringtime}")
    print(f"end_stringtime: {end_stringtime}")
    print(f"uuid: {uuid}")

    # convert string times to unix timestamps
    strptime_filter = '%b %d %H:%M:%S %Z %Y'
    start_timestamp = int(datetime.datetime.strptime(start_stringtime, strptime_filter).replace(tzinfo=datetime.timezone.utc).timestamp())
    end_timestamp = int(datetime.datetime.strptime(end_stringtime, strptime_filter).replace(tzinfo=datetime.timezone.utc).timestamp())
    print(f"start_datetime: {start_timestamp}")
    print(f"end_datetime: {end_timestamp}")

    # construct JSON of workload data
    workload_data = {
        "starttime": str(start_timestamp),
        "endtime": str(end_timestamp),
        "uuid": str(uuid)
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
