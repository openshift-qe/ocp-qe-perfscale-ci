#!/bin/bash
oc project default

echo "=== Removing OpenTelemetry Operator ==="
oc delete subscription opentelemetry-product -n openshift-opentelemetry-operator
oc delete operatorgroups openshift-opentelemetry-operator -n openshift-opentelemetry-operator
oc delete project openshift-opentelemetry-operator
echo "=== DONE ==="