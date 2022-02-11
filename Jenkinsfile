@Library('flexy') _

// rename build
def userId = currentBuild.rawBuild.getCause(hudson.model.Cause$UserIdCause)?.userId ?: "memodi"
if (userId) {
  currentBuild.displayName = userId
}

pipeline {
  agent none

  parameters {
        string(name: 'BUILD_NUMBER', defaultValue: '', description: 'Build number of job that has installed the cluster.')
        string(name: 'SCALE_UP', defaultValue: '0', description: 'If value is set to anything greater than 0, cluster will be scaled up before executing the workload.')
        string(name: 'SCALE_DOWN', defaultValue: '0', description:
        '''If value is set to anything greater than 0, cluster will be scaled down after the execution of the workload is complete,<br>
        if the build fails, scale down may not happen, user should review and decide if cluster is ready for scale down or re-run the job on same cluster.'''
        )
        string(name:'JENKINS_AGENT', defaultValue:'goc48',description:
        '''
        scale-ci-static: for static agent that is specific to scale-ci, useful when the jenkins dynamic agen
 isn't stable<br>
        4.y: oc4y || mac-installer || rhel8-installer-4y || <br/>
            e.g, for 4.8, use oc48 || mac-installer || rhel8-installer-48 <br/>
            for agents with go tools, use goc48, goc49 etc. <br/> 
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
        string(name: 'E2E_BENCHMARKING_REPO', defaultValue:'https://github.com/memodi/e2e-benchmarking', description:'You can change this to point to your fork if needed.')
        string(name: 'E2E_BENCHMARKING_REPO_BRANCH', defaultValue:'netobserv-per-test', description:'You can change this to point to a branch on your fork if needed.')
        choice(name: 'NETWORKING_VARIANT', choices: ['POD_NETWORK', 'SERVICEIP_NETWORK', 'MULTUS_NETWORK'], description: 'Specify which networking variant')
        string(name: 'UPERF_RUNTIME', defaultValue:'60', description:'Specify uperf workload runtime')
    }

  stages {
    stage('Run Network Pod Perf Tests'){
      // agent { label params['JENKINS_AGENT'] }
      agent {
        kubernetes {
        cloud 'PSI OCP-C1 agents'
        yaml """\
          apiVersion: v1
          kind: Pod
          metadata:
            labels:
              label: ${JENKINS_AGENT}
          spec:
            containers:
            - name: "jnlp"
              image: "docker-registry.upshift.redhat.com/aosqe/cucushift:${JENKINS_AGENT}"
              resources:
                requests:
                  memory: "8Gi"
                  cpu: "2"
                limits:
                  memory: "8Gi"
                  cpu: "2"
              imagePullPolicy: Always
              workingDir: "/home/jenkins/ws"
              tty: true
          """.stripIndent()
        }
      }

      environment{
          EMAIL_ID_FOR_RESULTS_SHEET = "${userId}@redhat.com"
      }
      steps{
        script{
          if(params.SCALE_UP.toInteger() > 0) {
            build job: 'scale-ci/e2e-benchmarking-multibranch-pipeline/cluster-workers-scaling', parameters: [string(name: 'BUILD_NUMBER', value: BUILD_NUMBER), string(name: 'WORKER_COUNT', value: SCALE_UP), string(name: 'JENKINS_AGENT_LABEL', value: JENKINS_AGENT_LABEL)]
          }
        }
        deleteDir()
        checkout([
          $class: 'GitSCM', 
          branches: [[name: params.E2E_BENCHMARKING_REPO_BRANCH ]],
          doGenerateSubmoduleConfigurations: false, 
          userRemoteConfigs: [[url: params.E2E_BENCHMARKING_REPO ]
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
            sh label: '', script: '''
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
            cd workloads/netobserv
            wget https://www.python.org/ftp/python/3.8.12/Python-3.8.12.tgz
            tar -zxvf Python-3.8.12.tgz
            cd Python-3.8.12
            newdirname=~/.localpython
            if [ -d "$newdirname" ]; then
              echo "Directory already exists"
            else
              mkdir -p $newdirname
              ./configure --prefix=$HOME/.localpython
              make
              make install
            fi
            /home/jenkins/.localpython/bin/python3 --version
            python3 -m pip install virtualenv
            python3 -m virtualenv venv3 -p $HOME/.localpython/bin/python3
            source venv3/bin/activate
            python --version
            cd ..
            ./run_netobserv_perf_comparison_tests.sh $NETWORKING_VARIANT
            rm -rf ~/.kube
            '''
          }
        }
        script{
        //  if the build fails, scale down will not happen, letting user review and decide if cluster is ready for scale down or re-run the job on same cluster
         if(params.SCALE_DOWN.toInteger() > 0) {
           build job: 'scale-ci/e2e-benchmarking-multibranch-pipeline/cluster-workers-scaling', parameters: [string(name: 'BUILD_NUMBER', value: BUILD_NUMBER), string(name: 'WORKER_COUNT', value: SCALE_DOWN), string(name: 'JENKINS_AGENT_LABEL', value: JENKINS_AGENT_LABEL)]
           }
        }

      }
        
    }
}
}
