@Library('flexy') _

// rename build
def userId = currentBuild.rawBuild.getCause(hudson.model.Cause$UserIdCause)?.userId
if (userId) {
  currentBuild.displayName = userId
}

def RETURNSTATUS = "default"
def output = ""

pipeline {
  agent none

  parameters {
    string(name: 'BUILD_NUMBER', defaultValue: '', description: 'Build number of job that has installed the cluster.')
    choice(choices: ["conc_jobs","large_network_policy"], name: 'TEST_CASE',description:'''<p>
                    Select the test case you want to run.<br>
                    This job will search the TEST_CASE.sh file under svt repo <a href="https://github.com/openshift/svt/blob/master/perfscale_regression_ci/scripts">perfscale_regression_ci/scripts</a> folder and sub folders<br>
                    If SCRIPT is specified TEST_CASER will be overwritten.
                    </p>''')
    string(name: 'SCRIPT', defaultValue: '', description: '''<p>
                  Relative path to the script of the TEST_CASE under <a href="https://github.com/openshift/svt">svt repo</a>.<br>
                  e.g.<br>
                  For large_network_policy test case: perfscale_regression_ci/scripts/network/large_network_policy.sh<br>
                  If TEST_CASE is specified, SCRIPT will overwrite the TEST_CASE.
                  </p>''')
    string(name: 'PARAMETERS', defaultValue: '', description: '''<p>
                  Parameter or an array of parameters to pass to the TEST_CASE script<p>
                  e.g.<br>
                  For conc_jobs: 100 500 1000 2000<br>
                  For large_network_policy: 5000<br>
                  </p>''')
    string(name: 'SVT_REPO', defaultValue:'https://github.com/openshift/svt', description:'''<p>
                  Repository to get regression test scripts and artifacts.<br>
                  You can change this to point to your fork if needed.
                  </p>''')
    string(name: 'SVT_REPO_BRANCH', defaultValue:'master', description:'You can change this to point to a branch on your branch if needed.')
    string(name:'JENKINS_AGENT_LABEL',defaultValue:'oc411',description:'')
    text(name: 'ENV_VARS', defaultValue: '', description:'''<p>
               Enter list of additional (optional) Env vars you'd want to pass to the script, one pair on each line. <br>
               e.g.<br>
               SOMEVAR1='env-test'<br>
               SOMEVAR2='env2-test'<br>
               ...<br>
               SOMEVARn='envn-test'<br>
               </p>'''
            )
  }

  stages {
    stage('Run Regression Test'){
      agent { label params['JENKINS_AGENT_LABEL'] }
      steps{
        deleteDir()

        checkout([
          $class: 'GitSCM',
          branches: [[name: params.SVT_REPO_BRANCH ]],
          doGenerateSubmoduleConfigurations: false,
          userRemoteConfigs: [[url: params.SVT_REPO ]
          ]])

        copyArtifacts(
          filter: '',
          fingerprintArtifacts: true,
          projectName: 'ocp-common/Flexy-install',
          selector: specific(params.BUILD_NUMBER),
          target: 'flexy-artifacts'
        )

        script{
          buildinfo = readYaml file: "flexy-artifacts/BUILDINFO.yml"
          currentBuild.displayName = "${currentBuild.displayName}-${params.BUILD_NUMBER}"
          currentBuild.description = "Copying Artifact from Flexy-install build <a href=\"${buildinfo.buildUrl}\">Flexy-install#${params.BUILD_NUMBER}</a>"
          buildinfo.params.each { env.setProperty(it.key, it.value) }
        }

        script{
            RETURNSTATUS = sh(returnStatus: true, script: '''
              # Get ENV VARS Supplied by the user to this job and store in .env_override
              echo "$ENV_VARS" > .env_override
              # Export those env vars so they could be used by CI Job
              set -a && source .env_override && set +a
              
              mkdir -p ~/.kube
              cp $WORKSPACE/flexy-artifacts/workdir/install-dir/auth/kubeconfig ~/.kube/config
              ls -ls ~/.kube/

              python3.9 --version
              python3.9 -m pip install virtualenv
              python3.9 -m virtualenv venv3
              source venv3/bin/activate
              python --version
              # If SCRIPT is not specified, fine the script by the TEST_CASE.
              if [[ $SCRIPT == "" ]]
              then
                SCRIPT=$(find perfscale_regression_ci -name $TEST_CASE.sh)
                if [[ $SCRIPT == "" ]]
                then
                  echo "$TEST_CASE.sh is not found under svt repo perfscale_regression_ci/scripts folder. Please check."
                  exit 1
                fi
              fi
              export folder=${SCRIPT%/*}
              export script=${SCRIPT##*/} 
              cd ${folder}
              set -o pipefail
              ./${script} $PARAMETERS | tee $WORKSPACE/output.out
            ''')
            output = sh(returnStdout: true, script: 'cat $WORKSPACE/output.out')
            if (RETURNSTATUS.toInteger() != 0) {
              currentBuild.result = "FAILURE"
            }
        }
      }
    }
  }
}