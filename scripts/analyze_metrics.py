#!/usr/bin/env python3

import sys
import json
import numpy as np

IGNORE_DATA = ("benchmarkEnv", "netobservEnv")
AVERAGE_METRICS = (
    "cpuUsage",
    "memoryUsage",
    "nFlowsProcessedPerMinute",
    "FlowProcessingTime",
    "nPacketsProcessedPerMinute",
    "nFlowLogsProcessed",
    "nBytes",
    "ebpfCpuUsage",
    "ebpfmemoryUsage",
)
PERC_90_METRICS = (
    "nFlowsProcessedPerMinute",
    "nPacketsProcessedPerMinute",
    "FlowProcessingTime",
    "nFlowLogsProcessed",
    "nBytes",
)


def compute_avg(resource, data):
    print(f"\n======= Computing average for {resource} =======\n")
    for metrics in data:
        res = [float(values[1]) for values in metrics["values"]]
        avg = sum(res) / len(res)
        print(f"{metrics['metric']['pod']}, {avg}")


def analyze_diskutil(resource, data):
    print(
        f"\n======= Computing disk utilization over a period for {resource} =======\n"
    )
    util = float(data[0]["values"][-1][1]) - float(data[0]["values"][0][1])
    print(f"{data[0]['metric']['persistentvolumeclaim']}, {str(util)}")


def compute_90th_perc(resource, data):
    print(f"\n======= Computing 90th percentile for {resource} =======\n")
    metric_val = []
    for metrics in data:
        for values in metrics["values"]:
            metric_val.append(float(values[1]))
        perc_90th = np.nanpercentile(
            metric_val,
            90,
        )
        print(f"{metrics['metric']['pod']}, {str(perc_90th)}")


def process_metrics(file):
    with open(file) as fh:
        metrics_data = json.load(fh)
        for metric in metrics_data.keys():
            if metric in IGNORE_DATA:
                continue
            if metric in AVERAGE_METRICS:
                compute_avg(metric, metrics_data[metric]["data"]["result"])
            if metric in PERC_90_METRICS:
                compute_90th_perc(metric, metrics_data[metric]["data"]["result"])

            if metric == "lokiStorageUsage":
                analyze_diskutil(metric, metrics_data[metric]["data"]["result"])


if __name__ == "__main__":
    file = sys.argv[1]
    process_metrics(file)
