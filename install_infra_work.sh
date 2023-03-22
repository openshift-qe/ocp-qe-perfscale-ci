#!/bin/sh


function print_node_machine_info() {

    label=$1

    for node in $(oc get nodes --no-headers -l node-role.kubernetes.io/$label= | egrep -e "NotReady|SchedulingDisabled" | awk '{print $1}'); do
        oc describe node $node
    done

    for machine in $(oc get machines -n openshift-machine-api --no-headers -l machine.openshift.io/cluster-api-machine-type=$label| grep -v "Running" | awk '{print $1}'); do
        oc describe machine $machine -n openshift-machine-api
    done
}

function set_storage_class() {

    storage_class_found=false
    default_storage_class=""
    # need to verify passed storage class exists 
    for s_class in $(oc get storageclass -A --no-headers | awk '{print $1}'); do
        if [ "$s_class" != ${OPENSHIFT_PROMETHEUS_STORAGE_CLASS} ]; then 
            s_class_annotations=$(oc get storageclass $s_class -o jsonpath='{.metadata.annotations}')
            default_status=$(echo $s_class_annotations | jq '."storageclass.kubernetes.io/is-default-class"')
            if [ "$default_status" = '"true"' ]; then
                default_storage_class=$s_class
            fi 
        else 
            storage_class_found=true
        fi
    done
    if [[ $storage_class_found == false ]]; then 
        echo "setting new storage classes to $default_storage_class"
        OPENSHIFT_PROMETHEUS_STORAGE_CLASS=$default_storage_class
        OPENSHIFT_ALERTMANAGER_STORAGE_CLASS=$default_storage_class
    fi
}

function wait_for_prometheus_status() {
    token=$(oc create token -n openshift-monitoring prometheus-k8s --duration=6h)
 
    URL=https://$(oc get route -n openshift-monitoring prometheus-k8s -o jsonpath="{.spec.host}")
    prom_status="not_started"
    sleep 30
    while [[ "$prom_status" != "success" ]]; do
        prom_status=$(curl -s -g -k -X GET -H "Authorization: Bearer $token" -H 'Accept: application/json' -H 'Content-Type: application/json' "$URL/api/v1/query?query=up" | jq -r '.status')
        sleep 5
        echo "Prometheus status not ready yet, retrying in 5s..."
    done 
}

set_storage_class

if [[ $(oc get machineset -n openshift-machine-api $(oc get machinesets -A  -o custom-columns=:.metadata.name | shuf -n 1) -o=jsonpath='{.metadata.annotations}' | grep -c "machine.openshift.io") -ge 1 ]]; then
    export MACHINESET_METADATA_LABEL_PREFIX=machine.openshift.io
else
    export MACHINESET_METADATA_LABEL_PREFIX=sigs.k8s.io
fi
export CLUSTER_NAME=$(oc get machineset -n openshift-machine-api -o=go-template='{{(index (index .items 0).metadata.labels "machine.openshift.io/cluster-api-cluster" )}}')

if [[ $(echo $VARIABLES_LOCATION | grep aws -c) > 0 ]]; then
    export AMI_ID=$(oc get machineset -n openshift-machine-api -o=go-template='{{(index .items 0).spec.template.spec.providerSpec.value.ami.id}}')
    export CLUSTER_REGION=$(oc get machineset -n openshift-machine-api -o=go-template='{{(index .items 0).spec.template.spec.providerSpec.value.placement.region}}')
    export SUBNET=$(oc get machineset -n openshift-machine-api -o=go-template='{{(index (index .items 1).spec.template.spec.providerSpec.value.subnet)}}')

    if [[ $(echo $SUBNET | grep Name -c) > 0  ]]; then
        envsubst < infra-node-machineset-aws.yaml | oc apply -f -
        envsubst < workload-node-machineset-aws.yaml | oc apply -f -
    else
        # for customer vpc cluster
        export SUBNET_ID_1=$(oc get machineset -n openshift-machine-api -o=go-template='{{(index (index .items 0).spec.template.spec.providerSpec.value.subnet.id)}}')
        export SUBNET_ID_2=$(oc get machineset -n openshift-machine-api -o=go-template='{{(index (index .items 1).spec.template.spec.providerSpec.value.subnet.id)}}')
        if [[ -n $SUBNET_ID_1 &&  -n $SUBNET_ID_2 ]]; then
            envsubst < infra-node-machineset-aws-customervpc.yaml | oc apply -f -
            envsubst < workload-node-machineset-aws-customervpc.yaml | oc apply -f -
        else
            echo "error: subnet id not found."
        fi             
    fi
elif [[ $(echo $VARIABLES_LOCATION | grep azure -c) > 0 ]]; then
    export AZURE_LOCATION=$(oc get machineset -n openshift-machine-api -o=go-template='{{(index .items 0).spec.template.spec.providerSpec.value.location}}')
    # Below variables are needed for verification if we are working with vpc cluster.
    export NETWORK_RESOURCE_GROUP_ID=$(oc get machineset -n openshift-machine-api -o=go-template='{{(index .items 0).spec.template.spec.providerSpec.value.networkResourceGroup}}')
    export VNET_ID=$(oc get machineset -n openshift-machine-api -o=go-template='{{(index .items 0).spec.template.spec.providerSpec.value.vnet}}')
    export SUBNET_ID=$(oc get machineset -n openshift-machine-api -o=go-template='{{(index (index .items 0).spec.template.spec.providerSpec.value.subnet)}}')
    export RESOURCE_ID=$(oc get machineset -n openshift-machine-api -o=go-template='{{(index (index .items 0).spec.template.spec.providerSpec.value.image.resourceID)}}')
    if [[ $(echo $NETWORK_RESOURCE_GROUP_ID | grep $CLUSTER_NAME -c) > 0 ]]; then
        envsubst < infra-node-machineset-azure.yaml | oc apply -f -
        envsubst < workload-node-machineset-azure.yaml | oc apply -f -
    else
        # for customer vpc cluster
        envsubst < infra-node-machineset-azure-customervpc.yaml | oc apply -f -
        envsubst < workload-node-machineset-azure-customervpc.yaml | oc apply -f -
    fi
elif [[ $(echo $VARIABLES_LOCATION | grep gcp -c) > 0 ]]; then

    echo $NETWORK_NAME
    # login to service account
    gcloud auth activate-service-account `cat $OCP_GCP | jq -r '.client_email'`  --key-file=$OCP_GCP --project=`cat $OCP_GCP | jq -r '.project_id'`
    gcloud auth list
    gcloud config set account `cat $OCP_GCP | jq -r '.client_email'`
    export NETWORK_NAME=$(gcloud compute networks list  | grep $CLUSTER_NAME | awk '{print $1}')
    if [[ $NETWORK_NAME == "" ]]; then
        sub_cluster_name=$(echo ${CLUSTER_NAME%-*})
        export NETWORK_NAME=$(gcloud compute networks list | grep $sub_cluster_name | awk '{print $1}')
    fi
    echo $NETWORK_NAME
    export SUBNET_NETWORK_NAME=$(gcloud compute networks subnets list --network=$NETWORK_NAME | grep worker | awk '{print $1}')

    export WORKER_NODE_MACHINESET=$(oc get machinesets --no-headers -n openshift-machine-api | awk {'print $1'} | awk 'NR==1{print $1}')
    export WORKER_MACHINESET_IMAGE=$(oc get machineset ${WORKER_NODE_MACHINESET} -n openshift-machine-api -o jsonpath='{.spec.template.spec.providerSpec.value.disks[0].image}')
    first_worker_node=$(oc get nodes -l 'node-role.kubernetes.io/worker=' --no-headers -o name | head -n 1)

    export GCP_REGION=$(oc get ${first_worker_node} -o=jsonpath='{.metadata.labels}' |  jq '."topology.kubernetes.io/region"' | sed 's/"//g' )

    oc apply -f gcp-sc-pd-ssd.yaml
    envsubst < infra-node-machineset-gcp.yaml | oc apply -f -
    envsubst < workload-node-machineset-gcp.yaml | oc apply -f -
elif [[ $(echo $VARIABLES_LOCATION | grep vsphere -c) > 0 ]]; then
    export WORKER_NODE_MACHINESET=$(oc get machinesets --no-headers -n openshift-machine-api | awk {'print $1'} | awk 'NR==1{print $1}')
    export WORKER_MACHINESET_IMAGE=$(oc get machineset ${WORKER_NODE_MACHINESET} -n openshift-machine-api -o jsonpath='{.spec.template.spec.providerSpec.value.disks[0].image}')
    export TEMPLATE_NAME=$(oc get machineset -n openshift-machine-api $(oc get machinesets --no-headers -A -o custom-columns=:.metadata.name | head -1) -o=jsonpath='{.spec.template.spec.providerSpec.value.template}')
    export DATACENTER=$(oc get machineset -n openshift-machine-api $(oc get machinesets --no-headers -A -o custom-columns=:.metadata.name | head -1) -o=jsonpath='{.spec.template.spec.providerSpec.value.workspace.datacenter}')
    export DATASTORE=$(oc get machineset -n openshift-machine-api $(oc get machinesets --no-headers -A -o custom-columns=:.metadata.name | head -1) -o=jsonpath='{.spec.template.spec.providerSpec.value.workspace.datastore}')
    export FOLDER=$(oc get machineset -n openshift-machine-api $(oc get machinesets --no-headers -A -o custom-columns=:.metadata.name | head -1) -o=jsonpath='{.spec.template.spec.providerSpec.value.workspace.folder}')
    export RESOURCE_POOL=$(oc get machineset -n openshift-machine-api $(oc get machinesets --no-headers -A -o custom-columns=:.metadata.name | head -1) -o=jsonpath='{.spec.template.spec.providerSpec.value.workspace.resourcePool}')
    export VSPHERE_SERVER=$(oc get machineset -n openshift-machine-api $(oc get machinesets --no-headers -A -o custom-columns=:.metadata.name | head -1) -o=jsonpath='{.spec.template.spec.providerSpec.value.workspace.server}')
    envsubst < infra-node-machineset-vsphere.yaml | oc apply -f -
    envsubst < workload-node-machineset-vsphere.yaml | oc apply -f -
elif [[ $(echo $VARIABLES_LOCATION | grep alicloud -c) > 0 ]]; then
    export WORKER_NODE_MACHINESET=$(oc get machinesets --no-headers -n openshift-machine-api | awk {'print $1'} | awk 'NR==1{print $1}')
    export WORKER_MACHINESET_IMAGE=$(oc get machineset ${WORKER_NODE_MACHINESET} -n openshift-machine-api -o jsonpath='{.spec.template.spec.providerSpec.value.imageId}')
    export CLUSTER_REGION=$(oc get machineset -n openshift-machine-api -o=go-template='{{(index .items 0).spec.template.spec.providerSpec.value.regionId}}')

    envsubst < infra-node-machineset-alicloud.yaml | oc apply -f -
    envsubst < workload-node-machineset-alicloud.yaml | oc apply -f -

elif [[ $(echo $VARIABLES_LOCATION | grep ibmcloud -c) > 0 ]]; then
    export WORKER_NODE_MACHINESET=$(oc get machinesets --no-headers -n openshift-machine-api | awk {'print $1'} | awk 'NR==1{print $1}')
    export CLUSTER_REGION=$(oc get machineset -n openshift-machine-api -o=go-template='{{(index .items 0).spec.template.spec.providerSpec.value.region}}')
    envsubst < infra-node-machineset-ibmcloud.yaml | oc apply -f -
    envsubst < workload-node-machineset-ibmcloud.yaml | oc apply -f -
elif [[ $(echo $VARIABLES_LOCATION | grep osp -c) > 0 ]]; then
    envsubst < infra-node-machineset-osp.yaml | oc apply -f -
    envsubst < workload-node-machineset-osp.yaml | oc apply -f -
elif [[ $(echo $VARIABLES_LOCATION | grep nutanix -c) > 0 ]]; then
    export CLUSTER_UUID=$(oc get machineset -n openshift-machine-api -o=go-template='{{(index (index .items 0).spec.template.spec.providerSpec.value.cluster.uuid)}}')
    export SUBNET_UUID=$(oc get machineset -n openshift-machine-api -o=go-template='{{((index (index .items 0).spec.template.spec.providerSpec.value.subnets 0).uuid)}}')
    if [[ -n $CLUSTER_UUID &&  -n $SUBNET_UUID ]]; then
        envsubst < infra-node-machineset-nutanix.yaml | oc apply -f -
        envsubst < workload-node-machineset-nutanix.yaml | oc apply -f -
    else
        echo "error: cluster uuid or subnet uuid not found."
    fi  
fi
retries=0
attempts=60
while [[ $(oc get nodes -l 'node-role.kubernetes.io/infra=' --no-headers -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' | grep True | wc -l ) -lt 3 ]]; do
    oc get nodes -l 'node-role.kubernetes.io/infra=' --no-headers -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' | grep True | wc -l 

    oc get nodes -l 'node-role.kubernetes.io/infra='
    oc get machines -A
    oc get machinesets -A
    sleep 30
    ((retries += 1))
    if [[ ${retries} -gt ${attempts} ]]; then
        echo "error: infra nodes didn't become READY in time, failing"
        print_node_machine_info "infra"
        exit 1
    fi
done
retries=0
while [[ $(oc get nodes -l 'node-role.kubernetes.io/workload=' --no-headers -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' | grep True | wc -l ) -lt 1 ]]; do
    oc get nodes -l 'node-role.kubernetes.io/workload=' --no-headers -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' | grep True | wc -l 
    oc get nodes -l 'node-role.kubernetes.io/workload='
    oc get machines -A
    oc get machinesets -A
    sleep 30
    ((retries += 1))
    if [[ ${retries} -gt ${attempts} ]]; then
        echo "error: workload nodes didn't become READY in time, failing"
        print_node_machine_info "workload"
        exit 1
    fi
done
oc get nodes
# this infra node will not be managed by any default MCP after removing the default worker role,
# it will leads to some configs cannot be applied to this infra node, such as, ICSP, details: https://issues.redhat.com/browse/OCPBUGS-10596
oc label nodes --overwrite -l 'node-role.kubernetes.io/infra=' node-role.kubernetes.io/worker-
# create a infra MCP here inherit machine configs from the worker pool.
cat mcp-infra.yaml | oc apply -f -

oc label nodes --overwrite -l 'node-role.kubernetes.io/workload=' node-role.kubernetes.io/worker-
# add a workload MCP too
cat mcp-workload.yaml |oc apply -f -

echo "Moving ingress pods to infra nodes"
oc patch -n openshift-ingress-operator ingresscontrollers.operator.openshift.io default -p '{"spec": {"nodePlacement": {"nodeSelector": {"matchLabels": {"node-role.kubernetes.io/infra": ""}}}}}' --type merge
echo "Moving monitoring to infra nodes"
if [[ $(cat $WORKSPACE/flexy-artifacts/workdir/install-dir/metadata.json | grep vsphere -c) > 0 ]]; then
    envsubst < monitoring-config-no-pvc.yaml | oc apply -f -
elif [[ $(echo $VARIABLES_LOCATION | grep nutanix | grep pvc -c) > 0 ]]; then
    envsubst < monitoring-config.yaml | oc apply -f -
elif [[ $(echo $VARIABLES_LOCATION | grep nutanix | grep -v pvc -c) > 0 ]]; then
    envsubst < monitoring-config-no-pvc.yaml | oc apply -f -
else
    envsubst < monitoring-config.yaml | oc apply -f -
fi

sleep 10 

infra_nodes=$(oc get nodes -l 'node-role.kubernetes.io/infra=' --no-headers | awk '{print $1}' |  tr '\n' '|')
infra_nodes=${infra_nodes:0:-1}

echo "$infra_nodes"
## wait for monitoring pods to go running
attempts=30

## need to get number of runnig pods in statefulsets 
for statefulset in $(oc get statefulsets --no-headers -n openshift-monitoring | awk '{print $1}'); do 
    ready_replicas=$(oc get statefulsets $statefulset -n openshift-monitoring -o jsonpath='{.status.availableReplicas}')
    wanted_replicas=2
    retries=0
    monitoring_pods=$(oc get pods -n openshift-monitoring --no-headers -o wide | grep -E "$infra_nodes"| grep "$statefulset")
    echo "pods $monitoring_pods"
    infra_pods=$(oc get pods -n openshift-monitoring --no-headers -o wide | grep -E "$infra_nodes" | grep Running | grep "$statefulset" | wc -l  | xargs)
    echo "current replicas in $statefulset: wanted--$wanted_replicas, current ready--$ready_replicas!"
    echo "current replicas in $statefulset: wanted--$wanted_replicas, current infra running--$infra_pods!"
    while [[ $ready_replicas != $wanted_replicas ]] ||  [[ $infra_pods != $wanted_replicas ]]; do
        sleep 30
        ((retries += 1))
        ready_replicas=$(oc get statefulsets $statefulset -n openshift-monitoring -o jsonpath='{.status.availableReplicas}')
        echo "retries printing: $retries"
        monitoring_pods=$(oc get pods -n openshift-monitoring --no-headers -o wide | grep -E "$infra_nodes"| grep "$statefulset")
        echo "pods $monitoring_pods"

        infra_pods=$(oc get pods -n openshift-monitoring --no-headers -o wide | grep -E "$infra_nodes" | grep Running| grep "$statefulset" | wc -l |xargs )
        echo "current replicas in $statefulset: wanted--$wanted_replicas, current ready--$ready_replicas!"
        echo "current replicas in $statefulset: wanted--$wanted_replicas, current infra running--$infra_pods!"
        if [[ ${retries} -gt ${attempts} ]]; then
            oc describe statefulsets $statefulset -n openshift-monitoring
            for pod in $(oc get pods -n openshift-monitoring --no-headers | grep -v Running | awk '{print $1}'); do
                oc describe pod $pod -n openshift-monitoring
            done
            echo "error: monitoring statefulsets/pods didn't become Running in time, failing"
            exit 1
        fi
    done
done

wait_for_prometheus_status