@Library('flexy') _

// rename build
def userId = currentBuild.rawBuild.getCause(hudson.model.Cause$UserIdCause)?.userId
if (userId) {
  currentBuild.displayName = userId
}
def scale_num = 3

pipeline {
  agent none

  parameters {
        string(name: 'BUILD_NUMBER', defaultValue: '', description: 'Build number of job that has installed the cluster.')
        string(name:'JENKINS_AGENT_LABEL',defaultValue:'oc45',description:
        '''
        scale-ci-static: for static agent that is specific to scale-ci, useful when the jenkins dynamic agen
 isn't stable<br>
        4.y: oc4y || mac-installer || rhel8-installer-4y <br/>
            e.g, for 4.8, use oc48 || mac-installer || rhel8-installer-48 <br/>
        3.11: ansible-2.6 <br/>
        3.9~3.10: ansible-2.4 <br/>
        3.4~3.7: ansible-2.4-extra || ansible-2.3 <br/>
        '''
        )
        string(name: 'WORKER_COUNT', defaultValue: '', description:'Total Worker count desired in the cluster')
        text(name: 'ENV_VARS', defaultValue: '', description:'''<p>
               Enter list of additional (optional) Env Vars you'd want to pass to the script, one pair on each line. <br>
               e.g.<br>
               SOMEVAR1='env-test'<br>
               SOMEVAR2='env2-test'<br>
               ...<br>
               SOMEVARn='envn-test'<br>
               </p>'''
            )
    }

  stages {
    stage('Scale Workers in OCP Cluster'){
      agent { label params['JENKINS_AGENT_LABEL'] }
      steps{
        deleteDir()
        copyArtifacts(
            filter: '', 
            fingerprintArtifacts: true, 
            projectName: 'ocp-common/Flexy-install', 
            selector: specific(params.BUILD_NUMBER),
            target: 'flexy-artifacts'
        )
        script {
          buildinfo = readYaml file: "flexy-artifacts/BUILDINFO.yml"
          currentBuild.displayName = "${currentBuild.displayName}-${params.BUILD_NUMBER}"
          currentBuild.description = "Copying Artifact from Flexy-install build <a href=\"${buildinfo.buildUrl}\">Flexy-install#${params.BUILD_NUMBER}</a>"
          buildinfo.params.each { env.setProperty(it.key, it.value) }
        }
        ansiColor('xterm') {
        sh label: '', script: '''
        mkdir -p ~/.kube
        # Get ENV VARS Supplied by the user to this job and store in .env_override
        echo "$ENV_VARS" > .env_override
        # Export those env vars so they could be used by CI Job
        set -a && source .env_override && set +a
        cp $WORKSPACE/flexy-artifacts/workdir/install-dir/auth/kubeconfig ~/.kube/config
        oc config view
        oc projects
        ls -ls ~/.kube/
        env
        log(){
          echo -e "\033[1m$(date "+%d-%m-%YT%H:%M:%S") ${@}\033[0m"
        }
        function scaleMachineSets(){
          scale_num=$(oc get --no-headers machinesets -A | awk '{print $2}' | wc -l | xargs)
          scale_size=$(($1/$scale_num))
          set -x
          for machineset in $(oc get --no-headers machinesets -A | awk '{print $2}'); do
              oc scale machinesets -n openshift-machine-api $machineset --replicas $scale_size
          done
          if [[ $(($1%$scale_num)) != 0 ]]; then
            oc scale machinesets -n openshift-machine-api  $(oc get --no-headers machinesets -A | awk '{print $2}' | head -1) --replicas $(($scale_size+$(($1%$scale_num))))
          fi
          set +x
          local retries=0
          local attempts=100
          while [[ $(oc get nodes --no-headers -l node-role.kubernetes.io/worker | grep -v "NotReady\\|SchedulingDisabled" | grep worker -c) != $1 ]]; do
              log "Following nodes are currently present, waiting for desired count $1 to be met."
              log "Machinesets:"
              oc get machinesets -A
              log "Nodes:"
              oc get nodes --no-headers -l node-role.kubernetes.io/worker | cat -n
              log "Sleeping for 60 seconds"
              sleep 60
              ((retries += 1))
              if [[ "${retries}" -gt ${attempts} ]]; then

                for node in $(oc get nodes --no-headers -l node-role.kubernetes.io/worker | egrep -e "NotReady|SchedulingDisabled" | awk '{print $1}'); do
                    oc describe node $node
                done

                for machine in $(oc get machines -n openshift-machine-api --no-headers | grep -v "master" | grep -v "Running" | awk '{print $1}'); do
                    oc describe machine $machine -n openshift-machine-api
                done

                echo "error: all $1 nodes didn't become READY in time, failing"
                exit 1
              fi
          done;
          log "All nodes seem to be ready"
          oc get nodes --no-headers -l node-role.kubernetes.io/worker | cat -n
        }

        scaleMachineSets $WORKER_COUNT
        rm -rf ~/.kube
        '''
        }
        script{
          if(params.WORKER_COUNT.toInteger() > 50) {
            if(env.VARIABLES_LOCATION.indexOf("aws") != -1){
              build job: 'scale-ci/e2e-benchmarking-multibranch-pipeline/cluster-post-config', parameters: [
              string(name: 'BUILD_NUMBER', value: BUILD_NUMBER), string(name: 'HOST_NETWORK_CONFIGS', value:'false'),
              string(name: 'PROVISION_OR_TEARDOWN', value: 'PROVISION'),
              string(name: 'JENKINS_AGENT_LABEL', value: JENKINS_AGENT_LABEL),
              string(name: 'INFRA_NODES', value: 'true'),
              text(name: 'ENV_VARS', value: '''
OPENSHIFT_INFRA_NODE_VOLUME_IOPS=0
OPENSHIFT_INFRA_NODE_VOLUME_TYPE=gp2
OPENSHIFT_INFRA_NODE_VOLUME_SIZE=100
OPENSHIFT_PROMETHEUS_STORAGE_CLASS=gp2
OPENSHIFT_ALERTMANAGER_STORAGE_CLASS=gp2
OPENSHIFT_INFRA_NODE_INSTANCE_TYPE=m5.12xlarge
OPENSHIFT_PROMETHEUS_RETENTION_PERIOD=15d
OPENSHIFT_PROMETHEUS_STORAGE_SIZE=500Gi
OPENSHIFT_ALERTMANAGER_STORAGE_SIZE=20Gi
OPENSHIFT_WORKLOAD_NODE_VOLUME_IOPS=0
OPENSHIFT_WORKLOAD_NODE_VOLUME_TYPE=gp2
OPENSHIFT_WORKLOAD_NODE_VOLUME_SIZE=500
OPENSHIFT_WORKLOAD_NODE_INSTANCE_TYPE=m5.8xlarge
              ''')]
            }else if(env.VARIABLES_LOCATION.indexOf("azure") != -1){
              build job: 'scale-ci/e2e-benchmarking-multibranch-pipeline/cluster-post-config', parameters: [
              string(name: 'BUILD_NUMBER', value: BUILD_NUMBER), string(name: 'HOST_NETWORK_CONFIGS', value:'false'),
              string(name: 'PROVISION_OR_TEARDOWN', value: 'PROVISION'),
              string(name: 'JENKINS_AGENT_LABEL', value: JENKINS_AGENT_LABEL),
              string(name: 'INFRA_NODES', value: 'true'),
              text(name: 'ENV_VARS', value: '''
OPENSHIFT_INFRA_NODE_VOLUME_SIZE=128
OPENSHIFT_INFRA_NODE_VOLUME_TYPE=Premium_LRS
OPENSHIFT_INFRA_NODE_VM_SIZE=Standard_D48s_v3
OPENSHIFT_PROMETHEUS_STORAGE_CLASS=Premium_LRS
OPENSHIFT_ALERTMANAGER_STORAGE_CLASS=Premium_LRS
OPENSHIFT_PROMETHEUS_RETENTION_PERIOD=15d
OPENSHIFT_PROMETHEUS_STORAGE_SIZE=500Gi
OPENSHIFT_ALERTMANAGER_STORAGE_SIZE=20Gi
OPENSHIFT_WORKLOAD_NODE_VOLUME_SIZE=500
OPENSHIFT_WORKLOAD_NODE_VOLUME_TYPE=Premium_LRS
OPENSHIFT_WORKLOAD_NODE_VM_SIZE=Standard_D32s_v3
              ''')]
            }else if(env.VARIABLES_LOCATION.indexOf("gcp") != -1){
              build job: 'scale-ci/e2e-benchmarking-multibranch-pipeline/cluster-post-config', parameters: [
              string(name: 'BUILD_NUMBER', value: BUILD_NUMBER), string(name: 'HOST_NETWORK_CONFIGS', value:'false'),
              string(name: 'PROVISION_OR_TEARDOWN', value: 'PROVISION'),
              string(name: 'JENKINS_AGENT_LABEL', value: JENKINS_AGENT_LABEL),
              string(name: 'INFRA_NODES', value: 'true'),
              text(name: 'ENV_VARS', value: '''
OPENSHIFT_INFRA_NODE_VOLUME_SIZE=100
OPENSHIFT_INFRA_NODE_VOLUME_TYPE=pd-ssd
OPENSHIFT_INFRA_NODE_INSTANCE_TYPE=n1-standard-64
GCP_PROJECT=openshift-qe
GCP_SERVICE_ACCOUNT_EMAIL=openshift-qe.iam.gserviceaccount.com
OPENSHIFT_PROMETHEUS_RETENTION_PERIOD=15d
OPENSHIFT_PROMETHEUS_STORAGE_SIZE=500Gi
OPENSHIFT_ALERTMANAGER_STORAGE_SIZE=20Gi
OPENSHIFT_WORKLOAD_NODE_VOLUME_SIZE=500
OPENSHIFT_WORKLOAD_NODE_VOLUME_TYPE=pd-ssd
OPENSHIFT_WORKLOAD_NODE_INSTANCE_TYPE=n1-standard-32
              ''')]
            }else if(env.VARIABLES_LOCATION.indexOf("vsphere") != -1){
              build job: 'scale-ci/e2e-benchmarking-multibranch-pipeline/cluster-post-config', parameters: [
              string(name: 'BUILD_NUMBER', value: BUILD_NUMBER), string(name: 'HOST_NETWORK_CONFIGS', value:'false'),
              string(name: 'PROVISION_OR_TEARDOWN', value: 'PROVISION'),
              string(name: 'JENKINS_AGENT_LABEL', value: JENKINS_AGENT_LABEL),
              string(name: 'INFRA_NODES', value: 'true'),
              text(name: 'ENV_VARS', value: ENV_VARS + '''
OPENSHIFT_INFRA_NODE_VOLUME_SIZE=120
OPENSHIFT_INFRA_NODE_CPU_COUNT=48
OPENSHIFT_INFRA_NODE_MEMORY_SIZE=196608
OPENSHIFT_INFRA_NODE_CPU_CORE_PER_SOCKET_COUNT=2
OPENSHIFT_INFRA_NODE_NETWORK_NAME=qe-segment
OPENSHIFT_WORKLOAD_NODE_VOLUME_SIZE=500
OPENSHIFT_WORKLOAD_NODE_CPU_COUNT=32
OPENSHIFT_WORKLOAD_NODE_MEMORY_SIZE=131072
OPENSHIFT_WORKLOAD_NODE_CPU_CORE_PER_SOCKET_COUNT=2
OPENSHIFT_WORKLOAD_NODE_NETWORK_NAME=qe-segment
              ''')]
            } else if(env.VARIABLES_LOCATION.indexOf("alicloud") != -1){
              build job: 'scale-ci/e2e-benchmarking-multibranch-pipeline/cluster-post-config', parameters: [
              string(name: 'BUILD_NUMBER', value: BUILD_NUMBER), string(name: 'HOST_NETWORK_CONFIGS', value:'false'),
              string(name: 'PROVISION_OR_TEARDOWN', value: 'PROVISION'),
              string(name: 'JENKINS_AGENT_LABEL', value: JENKINS_AGENT_LABEL),
              string(name: 'INFRA_NODES', value: 'true'),
              text(name: 'ENV_VARS', value: ENV_VARS + '''
OPENSHIFT_INFRA_NODE_VOLUME_SIZE=100
OPENSHIFT_INFRA_NODE_INSTANCE_TYPE=ecs.g6.13xlarge
OPENSHIFT_WORKLOAD_NODE_VOLUME_SIZE=500
OPENSHIFT_WORKLOAD_NODE_INSTANCE_TYPE=ecs.g6.8xlarge
OPENSHIFT_PROMETHEUS_STORAGE_CLASS=alicloud-disk
OPENSHIFT_ALERTMANAGER_STORAGE_CLASS=alicloud-disk
OPENSHIFT_PROMETHEUS_RETENTION_PERIOD=15d
OPENSHIFT_PROMETHEUS_STORAGE_SIZE=500Gi
OPENSHIFT_ALERTMANAGER_STORAGE_SIZE=20Gi
              ''')]
            } else {
            echo "Cloud type is not set up yet"
            }
          }
        }
      }
        
    }
}
}

