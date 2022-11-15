#!/usr/bin/env bash

export UUID=$(uuidgen | tr "[:upper:]" "[:lower:]")
export server=$(oc get nodes -l "node-role.kubernetes.io/worker" -o custom-columns=NAME:".metadata.name" --no-headers | head -1)
export client=$(oc get nodes -l "node-role.kubernetes.io/worker" -o custom-columns=NAME:".metadata.name" --no-headers | tail -1)
export CLUSTER_NAME=$(oc get infrastructure cluster -o jsonpath="{.status.infrastructureName}")
export RUNTIME=$1
