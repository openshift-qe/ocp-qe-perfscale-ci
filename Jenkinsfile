@Library('flexy') _

// rename build
def userId = currentBuild.rawBuild.getCause(hudson.model.Cause$UserIdCause)?.userId
if (userId) {
  currentBuild.displayName = userId
}

def RETURNSTATUS = "default"
def output = ""
def status = "FAIL"
pipeline {
    agent none
    parameters {
        string(
            name: 'BUILD_NUMBER', 
            defaultValue: '', 
            description: 'Build number of job that has installed the cluster.'
        )
        string(
            name: 'CERBERUS_ITERATIONS', 
            defaultValue: '', 
            description: 'Number of iterations to run of cerberus.'
        )
        booleanParam(
            name: 'CERBERUS_DAEMON_MODE', 
            defaultValue: false, 
            description: 'This variable will set cerberus to run forever (only way to stop is abort job)'
        )
        booleanParam(
            name: 'INSPECT_COMPONENTS', 
            defaultValue: false, 
            description: 'This variable will set cerberus to inspect failing components'
        )
        string(
            name: "CERBERUS_WATCH_NAMESPACES", 
            defaultValue: "[openshift-etcd, openshift-apiserver, openshift-kube-apiserver, openshift-monitoring, openshift-kube-controller-manager, openshift-machine-api, openshift-kube-scheduler, openshift-ingress, openshift-sdn]",
            description: "Which specific namespaces you want to watch any failing components, use [^.*\$] if you want to watch all namespaces"
        )
        string(
            name: "CERBERUS_IGNORE_PODS",
            defaultValue: "[^installer*]", 
            description: "Which specific pod names regex patterns you want to ignore in the namespaces you defined above"
        )
        string(
            name: 'JENKINS_AGENT_LABEL',
            defaultValue: 'oc411',
            description:
            '''
            scale-ci-static: for static agent that is specific to scale-ci, useful when the jenkins dynamic agent isn't stable<br>
            4.y: oc4y || mac-installer || rhel8-installer-4y <br/>
                e.g, for 4.8, use oc48 || mac-installer || rhel8-installer-48 <br/>
            3.11: ansible-2.6 <br/>
            3.9~3.10: ansible-2.4 <br/>
            3.4~3.7: ansible-2.4-extra || ansible-2.3 <br/>
            '''
        )
        text(
            name: 'ENV_VARS', 
            defaultValue: '', 
            description:'''<p>
              Enter list of additional (optional) Env Vars you'd want to pass to the script, one pair on each line. <br>
              See https://github.com/cloud-bulldozer/kraken-hub/blob/main/docs/cerberus.md for list of variables to pass <br>
              e.g.<br>
              SOMEVAR1='env-test'<br>
              SOMEVAR2='env2-test'<br>
              ...<br>
              SOMEVARn='envn-test'<br>
              </p>
            '''
        )
        string(
            name: 'CERBERUS_REPO',
            defaultValue: 'https://github.com/redhat-chaos/cerberus',
            description: 'You can change this to point to your fork if needed.'
        )
        string(
            name: 'CERBERUS_REPO_BRANCH',
            defaultValue:'main', 
            description:'You can change this to point to a branch on your fork if needed.'
        )
     }

  stages {
    stage('Cerberus Run'){
      agent { label params['JENKINS_AGENT_LABEL'] }
      steps{
        deleteDir()
        checkout([
          $class: 'GitSCM',
          branches: [[name: params.CERBERUS_REPO_BRANCH ]],
          doGenerateSubmoduleConfigurations: false,
          userRemoteConfigs: [[url: params.CERBERUS_REPO ]
         ]])
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

        script {
          RETURNSTATUS = sh(returnStatus: true, script: '''
          wget https://raw.githubusercontent.com/redhat-chaos/krkn-hub/main/cerberus/env.sh
          source env.sh
          # Get ENV VARS Supplied by the user to this job and store in .env_override
          echo "$ENV_VARS" > .env_override
          # Export those env vars so they could be used by CI Job
          set -a && source .env_override && set +a
          mkdir -p ~/.kube
          cp $WORKSPACE/flexy-artifacts/workdir/install-dir/auth/kubeconfig ~/.kube/config
          export CERBERUS_KUBECONFIG=~/.kube/config
          project_count=$(oc get project | wc -l)
          if [[ $project_count -ge 250 ]]; then 
              export CERBERUS_CORES=.1
          elif [[ $project_count -gt 100 ]]; then 
              export CERBERUS_CORES=.3
          else  
              export CERBERUS_CORES=.5
          fi
          env
          wget https://raw.githubusercontent.com/redhat-chaos/krkn-hub/main/cerberus/cerberus.yaml.template
          envsubst <cerberus.yaml.template > cerberus.yaml
          python3 --version
          python3 -m venv venv3
          source venv3/bin/activate
          pip --version
          pip install --upgrade pip
          pip install -U -r requirements.txt
          python start_cerberus.py --config cerberus.yaml
          replaced_json=$(less -XF final_cerberus_info.json | sed "s/True/0/g" | sed "s/False/1/g" )
          value=${replaced_json#*:*:}   # remove prefix ending at second ":"
          final_health=${value%,*}  # remove suffix starting with ","
          echo "health $final_health"
          exit $final_health

          ''')
            
            sh "echo $RETURNSTATUS"
            if( RETURNSTATUS.toString() == "0") {
                status = "PASS"
            }else {
                currentBuild.result = "FAILURE"
           }
      }
      script {
          if (status != "PASS" && fileExists("inspect_data")) {
             archiveArtifacts artifacts: 'inspect_data/*,inspect_data/**', fingerprint: false
          }
       }

     }
   }
  }
}