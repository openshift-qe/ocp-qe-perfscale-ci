
TOLERANCY_RULES_LIST=($TOLERANCY_RULES_PARAM)
COMPARISON_CONFIG_LIST=($COMPARISON_CONFIG_PARAM)
cd e2e-benchmark/utils

source compare.sh
for i in "${!TOLERANCY_RULES_LIST[@]}"; do
    export COMPARISON_OUTPUT=${PWD}/${WORKLOAD}-${COMPARISON_CONFIG_LIST[i]}.csv
    ls $WORKSPACE/comparison/
    ls $WORKSPACE/comparison/config/
    export COMPARISON_CONFIG=$WORKSPACE/comparison/config/${COMPARISON_CONFIG_LIST[i]}
    export TOLERANCY_RULES=$WORKSPACE/comparison/tolerancy-configs/${TOLERANCY_RULES_LIST[i]}
    env | grep TOLERANCY_RULES
    if [[ -n $BASELINE_UUID ]]; then 

    
    # compare "${ES_SERVER_BASELINE} ${ES_SERVER}" "${BASELINE_UUID} ${UUID}" "${COMPARISON_CONFIG}" "${GEN_CSV}"
    compare "${ES_SERVER}" "${BASELINE_UUID} ${UUID}" "${COMPARISON_CONFIG}" ${GEN_CSV} -vv

    else
    echo "UUID was not found for $WORKLOAD with cluster set up type $VARIABLES_LOCATION with the same worker count"
    exit 1
    fi
done
cd ../..