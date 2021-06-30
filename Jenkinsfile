@Library('flexy') _

// rename build
def userId = currentBuild.rawBuild.getCause(hudson.model.Cause$UserIdCause)?.userId
if (userId) {
  currentBuild.displayName = userId
}

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
        cp $WORKSPACE/flexy-artifacts/workdir/install-dir/auth/kubeconfig ~/.kube/config
        oc config view
        oc projects
        ls -ls ~/.kube/
        env
        log(){
          echo -e "\033[1m$(date "+%d-%m-%YT%H:%M:%S") ${@}\033[0m"
        }
        function scaleMachineSets(){
          scale_size=$(($1/3))
          set -x
          for machineset in $(oc get --no-headers machinesets -A | awk '{print $2}' | head -3); do
              oc scale machinesets -n openshift-machine-api $machineset --replicas $scale_size
          done
          if [[ $(($1%3)) != 0 ]]; then
            oc scale machinesets -n openshift-machine-api  $(oc get --no-headers machinesets -A | awk '{print $2}' | head -1) --replicas $(($scale_size+$(($1%3))))
          fi
          set +x
          local retries=0
          local attempts=180
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
      }
        
    }
}
}

