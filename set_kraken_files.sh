#/!/bin/bash

ls
cd kraken-hub
ls
source env.sh
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

fi

cp $file_name ../../kraken/scenarios/

echo "file name $file_name"
cd ../../kraken

suffix='.template'
file_name_yaml=${file_name/%$suffix}

suffix='.template'

# need to excahnge name 

export SCENARIO_FILE=$(echo $SCENARIO_FILE | sed "s/scenarios\/.*/scenarios\/$file_name_yaml/g")

echo "file nme yaml $file_name_yaml \n\n\n\n"
envsubst < scenarios/${file_name} > scenarios/${file_name_yaml}

ls scenarios

cat scenarios/${file_name_yaml}
envsubst < config.yaml.template > config.yaml
