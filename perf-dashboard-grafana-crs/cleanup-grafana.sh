#!/bin/bash

echo -e "\033[32mCleaning up dashboards \n\033[0m"
oc delete -f dashboards/


echo -e "\033[32mCleaning up datasources\n\033[0m"

oc delete -f datasources/

echo -e "\033[32mCleaning up grafana instance\n\033[0m"
oc delete -f .

oc delete clusterserviceversion -l operators.coreos.com/grafana-operator.default