#/!/bin/bash

kube_config_location_2=$1



ls
cd kraken-hub
ls
source env.sh
source common_run.sh

cp config.yaml.template ../kraken/config.yaml.template

cd ${KRAKEN_SCENARIO}
ls

source env.sh
echo "scenario type ${SCENARIO_TYPE}"
scenario_no_s=${SCENARIO_TYPE%?}

kraken_s=$(echo "$KRAKEN_SCENARIO" | tr '-' '_')
echo "kraken_s $kraken_s"
k_scenario_no_s=${kraken_s%?}
echo "no s $scenario_no_s"
ls
file_name=""
echo "SCENARIO_TYPE $SCENARIO_TYPE"

kraken_path="../../kraken"
scenario_path_base="scenarios"
scenario_path="openshift"

if [[ -z "$POD_LABEL" ]] && [[ ${kraken_s} == "pod_scenarios" ]]; then
    file_name=${k_scenario_no_s}_namespace.yaml.template
elif [[ ${kraken_s} == "network_chaos" ]]; then
    if [[ ${TRAFFIC_TYPE} == "egress" ]]; then
        file_name=${kraken_s}_egress.yaml.template
    elif [[ ${TRAFFIC_TYPE} == "ingress" ]]; then
        file_name=${kraken_s}_ingress.yaml.template
    fi 
elif [ -f "${SCENARIO_TYPE}.yaml.template" ]; then
    file_name=${SCENARIO_TYPE}.yaml.template
elif [ -f "${scenario_no_s}.yaml.template" ]; then 
    file_name=${scenario_no_s}.yaml.template
elif [ -f "${kraken_s}.yaml.template" ]; then
  file_name=${kraken_s}.yaml.template
elif [ -f "${k_scenario_no_s}.yaml.template" ]; then
  file_name=${k_scenario_no_s}.yaml.template
elif [ -f "input.yaml.template" ]; then
  file_name=input.yaml
  kraken_s=${KRAKEN_SCENARIO#*-}  
  scenario_path="arcaflow/$kraken_s"
  export NODE_SELECTORS="node-role.kubernetes.io/worker="
  export SCENARIO_FOLDER="$kraken_path/$scenario_path_base/$scenario_path"
  ls $SCENARIO_FOLDER
  setup_arcaflow_env "$SCENARIO_FOLDER"
  cat input.yaml
fi

#Scenario under arca or openshift sub folder
scenario_full_path="$scenario_path_base/$scenario_path"

# copy template file from kraken-hub to kraken
# Need kraken path only here since we are under kraken-hub folder
cp $file_name $kraken_path/$scenario_full_path

# See all files in kraken that just copied over
echo "full path $scenario_full_path" 
ls $kraken_path/$scenario_full_path

echo "file name $file_name"

# Moving into kraken repo
cd ../../kraken

suffix='.template'
file_name_yaml=${file_name/%$suffix}

# need to excahnge name 
export SCENARIO_FILE=$scenario_full_path/${file_name_yaml}
echo "SCENARIO FILE Loc $SCENARIO_FILE"

# Overwrite template file using env variables 
echo "file nme yaml $file_name_yaml \n\n\n\n"
envsubst < $scenario_full_path/${file_name} > $SCENARIO_FILE

ls $scenario_full_path

cat $scenario_full_path/workflow.yaml

cat $SCENARIO_FILE

envsubst < config.yaml.template > config2.yaml