#!/bin/bash

if [ ! $# -eq 1 ]; then
  echo "Usage: ./touchstone.sh [uuid] - Get stats from QE Elasticsearch instance via UUID"
  exit 1
else
  touchstone_compare \
    --database elasticsearch \
    -url https://$ES_USERNAME:$ES_PASSWORD@search-ocp-qe-perf-scale-test-elk-hcm7wtsqpxy7xogbu72bor4uve.us-east-1.es.amazonaws.com:443 \
    --uuid $1 \
    --config=$WORKSPACE/ocp-qe-perfscale-ci/scripts/netobserv_touchstone.json
  exit 0
fi
