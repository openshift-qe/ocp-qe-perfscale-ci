
TOLERANCY_RULES_LIST=($TOLERANCY_RULES_PARAM)
COMPARISON_CONFIG_LIST=($COMPARISON_CONFIG_PARAM)
cd e2e-benchmark/utils

source compare.sh
mkdir results
cd results
failed_comparison=0
if [[ -n $BASELINE_UUID ]]; then 
    for i in "${!TOLERANCY_RULES_LIST[@]}"; do
        export COMPARISON_OUTPUT=${PWD}/${WORKLOAD}-${COMPARISON_CONFIG_LIST[i]}.csv
        export COMPARISON_CONFIG=$WORKSPACE/configs/${COMPARISON_CONFIG_LIST[i]}
        export TOLERANCY_RULES=$WORKSPACE/tolerancy-configs/${TOLERANCY_RULES_LIST[i]}

        compare "${ES_SERVER}" "${BASELINE_UUID} ${UUID}" "${COMPARISON_CONFIG}" ${GEN_CSV} -vv
        result=$?
        cat $COMPARISON_OUTPUT
        if  [[ $result -ne 0 ]]; then
            failed_comparison=$((failed_comparison + 1))
        fi
    done
fi
cd ../../..

echo "failed comparisons: $failed_comparison"
if [[ $failed_comparison -ne 0 ]]; then
    exit 1
else 
    exit 0
fi