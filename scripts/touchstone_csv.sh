#!/bin/bash

if [ ! $# -eq 1 ]; then
  echo "Usage: ./touchstone_csv.sh [uuid] - Get stats from QE Elasticsearch instance via UUID and output in CSV format"
  exit 1
else
  touchstone_compare \
    --database elasticsearch \
    -url https://$ES_USERNAME:$ES_PASSWORD@search-ocp-qe-perf-scale-test-elk-hcm7wtsqpxy7xogbu72bor4uve.us-east-1.es.amazonaws.com:443 \
    --uuid $1 \
    --config=$WORKSPACE/ocp-qe-perfscale-ci/scripts/netobserv_touchstone.json \
    -o csv
  exit 0
fi
