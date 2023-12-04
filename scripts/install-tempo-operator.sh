#!/bin/bash
sleep_time=10
num_of_retries=12

function wait_for_operator_pods() {
    namespace=$1
    container0_ready=false
    container1_ready=false
    try=1

    while [ "$container0_ready" != "true" ] && [ "$container1_ready" != "true" ]
    do
        if [ $try -gt $num_of_retries ]
        then
            echo -e "Reached max number of $num_of_retries retries. Exit!"
            exit 62
        fi
        echo -e "Waiting for pod to be ready. Retry $try/$num_of_retries in $sleep_time seconds"
        sleep $sleep_time
        container0_ready=$(oc get pods -n $namespace -o jsonpath={.items[0].status.containerStatuses[0].ready})
        container1_ready=$(oc get pods -n $namespace -o jsonpath={.items[0].status.containerStatuses[1].ready})
        ((try+=1))
    done
    echo -e "Red Hat OpenShift distributed tracing data collection operator is ready!"
}

### Start here ###

# Installing Tempo Operator
echo "############ Installing Tempo Operator ############"
oc create -f tempo/open-tempo-namespace.yaml
oc create -f tempo/open-tempo-operator-group.yaml
cat tempo/open-tempo-subscription.yaml | sed "s/%VERSION%/$TEMPO_OPERATOR_VERSION/g" | oc create -f -
wait_for_operator_pods openshift-tempo-operator
echo "############ Tempo Operator installed #############"