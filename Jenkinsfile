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
        string(name: 'ES_SERVER', defaultValue:'', description:'Make sure to include OCP-QE ES server, talk to Mike Fiedler or Kedar Kulkarni')
        string(name: 'ES_INDEX', defaultValue:'router-test-results', description:'Elasticsearch index name')
        string(name: 'RUNTIME', defaultValue: '60', description: 'Workload duration in seconds')
        string(name: 'SAMPLES', defaultValue:'2', description:'Number of samples to perform of each test')
        string(name: 'TERMINATIONS', defaultValue:'http edge passthrough reencrypt mix', description:'List of HTTP terminations to test')
        string(name: 'KEEPALIVE_REQUESTS', defaultValue:'0 1 50', description:'List with the number of keep alive requests to perform in the same HTTP session')
        string(name: 'HOST_NETWORK', defaultValue:'true', description:'Enable hostNetwork in the mb client')
        string(name: 'NODE_SELECTOR', defaultValue:'{node-role.kubernetes.io/workload: }', description:'Node selector of the mb client')
        string(name: 'LARGE_SCALE_THRESHOLD', defaultValue:'24', description: 'Number of worker nodes required to consider a large scale scenario')
        string(name: 'LARGE_SCALE_ROUTES', defaultValue: '500', description: 'Number of routes of each termination to create in the large scale scenario')
        string(name: 'LARGE_SCALE_CLIENTS', defaultValue: '1 20 80', description: 'Threads/route to use in the large scale scenario')
        string(name: 'LARGE_SCALE_CLIENTS_MIX', defaultValue:'1 10 20', description: 'Threads/route to use in the large scale scenario with mix termination')
        string(name: 'SMALL_SCALE_ROUTES', defaultValue: '100', description:'Number of routes of each termination to create in the small scale scenario')
        string(name: 'SMALL_SCALE_CLIENTS', defaultValue: '1 40 200', description: 'Threads/route to use in the small scale scenario')
        string(name: 'SMALL_SCALE_CLIENTS_MIX', defaultValue: '1 20 80', description: 'Threads/route to use in the small scale scenario with mix termination')
        text(name: 'ENV_VARS', defaultValue: '', description:'''<p>
               Enter list of additional (optional) Env Vars you'd want to pass to the script, one pair on each line. <br>
               e.g.<br>
               SOMEVAR1='env-test'<br>
               SOMEVAR2='env2-test'<br>
               ...<br>
               SOMEVARn='envn-test'<br>
               </p><br>
               check <a href="https://github.com/cloud-bulldozer/e2e-benchmarking/tree/master/workloads/router-perf-v2">Router perf readme</a> for more env vars you can set'''
            )
    }

  stages {
    stage('Run Router perf tests'){
      agent { label 'oc45' }
      steps{
        deleteDir()
        checkout([
          $class: 'GitSCM', 
          branches: [[name: '*/master']], 
          doGenerateSubmoduleConfigurations: false, 
          userRemoteConfigs: [[url: 'https://github.com/cloud-bulldozer/e2e-benchmarking']
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
        ansiColor('xterm') {
        sh label: '', script: '''
        # Get ENV VARS Supplied by the user to this job and store in .env_override
        echo "$ENV_VARS" > .env_override
        # Export those env vars so they could be used by CI Job
        set -a && source .env_override && set +a
        mkdir ~/.kube
        cp $WORKSPACE/flexy-artifacts/workdir/install-dir/auth/kubeconfig ~/.kube/config
        oc config view
        oc projects
        ls -ls ~/.kube/
        env
        cd workloads/router-perf-v2
        ./ingress-performance.sh
        '''
        }
      }
        
    }
}
}

