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
        string(name: 'JOB', defaultValue: '', description: '''Type of job you ran and want to write output for ex <br>
               e.g.<br>
               loaded-upgrade
               upgrade
               cluster-density
               ...
        ''')
        string(name: 'UPGRADE_JOB_URL', defaultValue: '', description: 'Upgrade job url')
        string(name: 'JOB_TYPE', defaultValue: '', description: 'Scale-ci job type')
        string(name: 'CI_JOB_ID', defaultValue: '', description: 'Scale-ci job id')
        string(name: 'CI_JOB_URL', defaultValue: '', description: 'Upgrade job url')
        string(name: 'LOADED_JOB_URL', defaultValue: '', description: 'Upgrade job url')
        string(name: 'CI_STATUS', defaultValue: 'FAIL', description: 'Upgrade job ending status')
        booleanParam(name: 'ENABLE_FORCE', defaultValue: true, description: 'This variable will force the upgrade or not')
        booleanParam(name: 'SCALE', defaultValue: false, description: 'This variable will scale the cluster up one node at the end up the ugprade')
        string(name:'JENKINS_AGENT_LABEL',defaultValue:'oc45',description:
        '''
        scale-ci-static: for static agent that is specific to scale-ci, useful when the jenkins dynamic agent isn't stable
        <br>
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
        string(name: 'UPGRADE_REPO', defaultValue:'https://github.com/paigerube14/svt.git', description:'You can change this to point to your fork if needed.')
        string(name: 'UPGRADE_BRANCH', defaultValue:'upgrade', description:'You can change this to point to a branch on your fork if needed.')
   }

  stages {
    stage('Run Write to Sheets'){
      agent { label params['JENKINS_AGENT_LABEL'] }
      steps{
        deleteDir()
        checkout([
          $class: 'GitSCM',
          branches: [[name: params.UPGRADE_BRANCH ]],
          doGenerateSubmoduleConfigurations: false,
          userRemoteConfigs: [[url: params.UPGRADE_REPO ]
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
          withCredentials([file(credentialsId: 'sa-google-sheet', variable: 'GSHEET_KEY_LOCATION')]) {
            sh label: '', script: """
            # Get ENV VARS Supplied by the user to this job and store in .env_override
            echo "$ENV_VARS" > .env_override
            cp $GSHEET_KEY_LOCATION $WORKSPACE/.gsheet.json
            export GSHEET_KEY_LOCATION=$WORKSPACE/.gsheet.json
            # Export those env vars so they could be used by CI Job
            set -a && source .env_override && set +a
            mkdir -p ~/.kube
            cp $WORKSPACE/flexy-artifacts/workdir/install-dir/auth/kubeconfig ~/.kube/config
            oc config view
            oc projects
            ls -ls ~/.kube/
            env
            cd upgrade
            ls
            python3 --version
            python3 -m venv venv3
            source venv3/bin/activate
            pip --version
            pip install --upgrade pip
            pip install -U gspread oauth2client datetime pytz pyyaml
            if [ $JOB == "loaded-upgrade"]; then
                python -c "import write_loaded_results; write_loaded_results.write_to_sheet('$GSHEET_KEY_LOCATION', ${params.BUILD_NUMBER}, '${params.CI_JOB_URL}', '${params.UPGRADE_JOB_URL}','${params.LOADED_JOB_URL}', '${params.CI_STATUS}', '${params.SCALE}', '${params.ENABLE_FORCE}')"
            elif [ $JOB == 'upgrade']; then
                python -c "import write_to_sheet; write_to_sheet.write_to_sheet('$GSHEET_KEY_LOCATION', ${params.BUILD_NUMBER}, '${params.UPGRADE_JOB_URL}', '${params.CI_STATUS}', '${params.SCALE}', '${params.ENABLE_FORCE}')"
            else
                python -c "import write_scale_results_sheet; write_scale_results_sheet.write_to_sheet('$GSHEET_KEY_LOCATION', ${params.BUILD_NUMBER},  '${params.CI_JOB_ID}', '${params.JOB_TYPE}', '${params.CI_JOB_URL}', '${params.CI_STATUS}')"
            fi
            rm -rf ~/.kube
            """
          }

        }
      }
    }
  }
}