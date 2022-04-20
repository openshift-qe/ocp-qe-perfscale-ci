#/!/bin/bash

# pass $name_identifier $number
# e.g. wait_for_job_completion "job-" 100
function wait_for_completion() {
  COUNTER=0
  pod_name=$1
  completed=$(oc get $pod_name -o jsonpath='{.status.phase}')
  while [ $completed != "Succeeded" ]; do
    sleep 1
    completed=$(oc get $pod_name -o jsonpath='{.status.phase}')
    echo "$completed jobs are completed"
    COUNTER=$((COUNTER + 1))
    if [ $completed == "Failed" ]; then
      get_error_pods_logs $pod_name
      exit 1
    fi
    if [ $COUNTER -ge 600 ]; then
      get_error_pods_logs $pod_name
      echo "$pod_name are still not complete after 10 minutes"
      exit 1
    fi
  done
  get_error_pods_logs $pod_name
}

function get_error_pods_logs()
{
    oc logs $1 >> logs.out
}

if [[ ! -z $(kubectl get ns kraken) ]]; then 
  kubectl delete ns kraken
fi
kubectl create ns kraken
kubectl config set-context --current --namespace=kraken

kubectl create configmap kube-config --from-file=$1

cd kraken 
kubectl create configmap kraken-config --from-file=./config.yaml
kubectl create configmap scenarios-config --from-file=./scenarios
kubectl create configmap scenarios-openshift-config --from-file=./scenarios/openshift
kubectl create configmap scenarios-kube-config --from-file=./scenarios/kube

kubectl create serviceaccount useroot

oc adm policy add-scc-to-user privileged -z useroot
kubectl apply -f containers/kraken.yml

first_pod=$(oc get pods --sort-by '{.metadata.creationTimestamp}' -o name | tail -1)

wait_for_completion $first_pod