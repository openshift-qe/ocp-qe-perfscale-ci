#!/bin/bash

echo -e "Cleaning up dashboards \n"
oc delete -f dashboards/

echo -e "Cleaning up datasources\n"

oc delete -f datasources/

echo -e "Cleaning up grafana instance\n"
oc delete -f .