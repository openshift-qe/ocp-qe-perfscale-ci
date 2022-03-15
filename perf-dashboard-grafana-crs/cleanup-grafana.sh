#!/bin/bash

echo -e "\033[32mCleaning up dashboards \n\033[0m"
oc -n default delete -f dashboards/


echo -e "\033[32mCleaning up datasources\n\033[0m"

oc -n default delete -f datasources/

echo -e "\033[32mCleaning up grafana instance\n\033[0m"
oc -n default delete -f .

oc -n default delete clusterserviceversion -l operators.coreos.com/grafana-operator.default
