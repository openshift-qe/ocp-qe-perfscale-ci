#!/bin/bash
oc project default

echo "=== Removing Tempo Operator ==="
oc delete subscription tempo-product -n openshift-tempo-operator
oc delete operatorgroups openshift-tempo-operator -n openshift-tempo-operator
oc delete project openshift-tempo-operator
echo "=== DONE ==="