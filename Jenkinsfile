@Library('flexy') _

// rename build
def userId = currentBuild.rawBuild.getCause(hudson.model.Cause$UserIdCause)?.userId
if (userId) {
  currentBuild.displayName = userId
}

def RETURNSTATUS = "default"

pipeline {
  agent none

  parameters {
        string(name: 'BUILD_NUMBER', defaultValue: '', description: 'Build number of job that has installed the cluster.')
        string(name: 'CI_TYPE', defaultValue: '', description: 'Type of job you ran and want to cleanup. Ex. node-density')
        booleanParam(name: 'UNINSTALL_BENCHMARK_OP', defaultValue: false, description: 'This variable will uninstall the benchmark-operator if true')
        string(name:'JENKINS_AGENT_LABEL',defaultValue:'oc45',description:
        '''
        scale-ci-static: for static agent that is specific to scale-ci, useful when the jenkins dynamic agent isn't stable<br>
        4.y: oc4y || mac-installer || rhel8-installer-4y <br/>
            e.g, for 4.8, use oc48 || mac-installer || rhel8-installer-48 <br/>
        3.11: ansible-2.6 <br/>
        3.9~3.10: ansible-2.4 <br/>
        3.4~3.7: ansible-2.4-extra || ansible-2.3 <br/>
        '''
        )
       text(name: 'ENV_VARS', defaultValue: '', description:'''<p>
               Enter list of additional (optional) Env Vars you'd want to pass to the script, one pair on each line. <br>
               e.g.<br>
               SOMEVAR1='env-test'<br>
               SOMEVAR2='env2-test'<br>
               ...<br>
               SOMEVARn='envn-test'<br>
               </p>'''
            )
        string(name: 'BENCHMARK_OP_REPO', defaultValue:'https://github.com/cloud-bulldozer/benchmark-operator.git', description:'You can change this to point to your fork if needed.')
        string(name: 'BENCHMARK_OP_REPO_BRANCH', defaultValue:'master', description:'You can change this to point to a branch on your fork if needed.')
    }

  stages {
    stage('Run CI Cleanup'){
      agent { label params['JENKINS_AGENT_LABEL'] }
      steps{
        deleteDir()
        checkout([
          $class: 'GitSCM',
          branches: [[name: GIT_BRANCH ]],
          doGenerateSubmoduleConfigurations: false,
          userRemoteConfigs: [[url: GIT_URL ]
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
          sh(script: '''
          # Get ENV VARS Supplied by the user to this job and store in .env_override
          echo "$ENV_VARS" > .env_override
          # Export those env vars so they could be used by CI Job
          set -a && source .env_override && set +a
          mkdir -p ~/.kube
          cp $WORKSPACE/flexy-artifacts/workdir/install-dir/auth/kubeconfig ~/.kube/config
          oc config view
          oc projects
          ls -ls ~/.kube/
          env
          echo "$OSTYPE"
          export PYTHONUNBUFFERED=1
          python -c "import cleanup; cleanup.delete_all_namespaces('$CI_TYPE')"
          if [ $UNINSTALL_BENCHMARK_OP == true ]; then
              python3.9 -m pip install virtualenv
              python3.9 -m virtualenv venv3
              source venv3/bin/activate
              python --version
              pip install -U "git+https://github.com/cloud-bulldozer/benchmark-operator.git/#egg=ripsaw-cli&subdirectory=cli"
              ripsaw operator delete --repo=$BENCHMARK_OP_REPO --branch=$BENCHMARK_OP_REPO_BRANCH
          else
            python3 -c "import cleanup; cleanup.delete_all_jobs()"
            python3 -c "import cleanup; cleanup.delete_all_benchmarks()"
          fi

          ''')
        }

     }
  }
}
}