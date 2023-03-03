@Library('flexy') _

// rename build
def userCause = currentBuild.rawBuild.getCause(Cause.UserIdCause)
def upstreamCause = currentBuild.rawBuild.getCause(Cause.UpstreamCause)

userId = "prubenda"
if (userCause) {
    userId = userCause.getUserId()
}
else if (upstreamCause) {
    def upstreamJob = Jenkins.getInstance().getItemByFullName(upstreamCause.getUpstreamProject(), hudson.model.Job.class)
    if (upstreamJob) {
        def upstreamBuild = upstreamJob.getBuildByNumber(upstreamCause.getUpstreamBuild())
        if (upstreamBuild) {
            def realUpstreamCause = upstreamBuild.getCause(Cause.UserIdCause)
            if (realUpstreamCause) {
                userId = realUpstreamCause.getUserId()
            }
        }
    }
}
if (userId) {
    currentBuild.displayName = userId
}

println "user id $userId"
def RETURNSTATUS = "default"
def output = ""
def cerberus_job = ""
def status = "FAIL"
pipeline {
  agent none
  parameters {
      string(
          name: 'BUILD_NUMBER',
          defaultValue: '',
          description: 'Build number of job that has installed the cluster.'
      )
      choice(
          name: 'WORKLOAD',
          choices: ["cluster-density", "cluster-density-v2", "node-density", "node-density-heavy","node-density-cni"],
          description: 'Type of kube-burner job to run'
      )
      booleanParam(
          name: 'WRITE_TO_FILE',
          defaultValue: false,
          description: 'Value to write to google sheet (will run <a href=https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/job/scale-ci/job/e2e-benchmarking-multibranch-pipeline/job/write-scale-ci-results>write-scale-ci-results</a>)'
      )
      booleanParam(
          name: 'CLEANUP',
          defaultValue: false,
          description: 'Cleanup namespaces (and all sub-objects) created from workload (will run <a href=https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/job/scale-ci/job/e2e-benchmarking-multibranch-pipeline/job/benchmark-cleaner/>benchmark-cleaner</a>)'
      )
      booleanParam(
          name: 'CERBERUS_CHECK',
          defaultValue: false,
          description: 'Check cluster health status pass (will run <a href=https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/job/scale-ci/job/e2e-benchmarking-multibranch-pipeline/job/cerberus/>cerberus</a>)'
      )
      booleanParam(
          name: 'CHURN',
          defaultValue: false,
          description: '''Run churn at end of original iterations. <a href=https://github.com/cloud-bulldozer/e2e-benchmarking/tree/master/workloads/kube-burner#churn>Churning</a> allows you to scale down and then up a percentage of JOB_ITERATIONS after the objects have been created <br>
          Use the following variables in ENV_VARS to set specifics of churn. Otherwise the below will run as default <br>
          CHURN_DURATION=10m  <br>
          CHURN_PERCENT=10 <br>
          CHURN_DELAY=60s'''
      )
      string(
          name: 'VARIABLE',
          defaultValue: '1000', 
          description: '''
          This variable configures parameter needed for each type of workload. By default 1000.<br>
          cluster-density: This will export JOB_ITERATIONS env variable, set to 9 * num_workers. This variable sets the number of iterations to perform (1 namespace per iteration).<br>
          cluster-density-v2: This will export JOB_ITERATIONS env variable, set to 9 * num_workers. This variable sets the number of iterations to perform (1 namespace per iteration).<br>
          node-density: This will export JOB_ITERATIONS env variable; set to 200, work up to 250. Creates as many "sleep" pods as configured in this variable - existing number of pods on node.<br>
          node-density-heavy: This will export JOB_ITERATIONS env variable; set to 200, work up to 250. Creates this number of applications proportional to the calculated number of pods / 2<br>
          node-density-cni: This will export JOB_ITERATIONS env variable; set to 200, work up to 250. Creates this number of applications proportional to the calculated number of pods / 2<br>
          Read <a href=https://github.com/openshift-qe/ocp-qe-perfscale-ci/tree/kube-burner/README.md>here</a> for details about each variable
          '''
      )
      string(
          name: 'JENKINS_AGENT_LABEL',
          defaultValue: 'oc413',
          description: '''
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
          description: '''
          Enter list of additional (optional) Env Vars you'd want to pass to the script, one pair on each line.<br>
          e.g.<br>
          SOMEVAR1='env-test'<br>
          SOMEVAR2='env2-test'<br>
          ...<br>
          SOMEVARn='envn-test'<br>
          '''
      )
      booleanParam(
          name: "SEND_SLACK",
          defaultValue: false,
          description: "Check this box to send a Slack notification to #ocp-qe-scale-ci-results upon the job's completion"
      )
      booleanParam(
          name: 'INFRA_WORKLOAD_INSTALL',
          defaultValue: false,
          description: '''
          Install workload and infrastructure nodes even if less than 50 nodes.<br>
          Checking this parameter box is valid only when SCALE_UP is greater than 0.
          '''
      )
      string(
          name: 'SCALE_UP',
          defaultValue: '0',
          description: 'If value is set to anything greater than 0, cluster will be scaled up before executing the workload.'
      )
      string(
          name: 'SCALE_DOWN',
          defaultValue: '0',
          description: '''
          If value is set to anything greater than 0, cluster will be scaled down after the execution of the workload is complete,<br>
          if the build fails, scale down may not happen, user should review and decide if cluster is ready for scale down or re-run the job on same cluster.
          '''
      )
      string(
          name: 'KUBE_BURNER_BINARY',
          defaultValue: 'https://github.com/cloud-bulldozer/kube-burner/releases/download/v1.3/kube-burner-1.3-Linux-x86_64.tar.gz',
          description: 'You can change this to point to your own kube burner binary file if needed.'
      )
  }
  stages {  
    stage('Scale up cluster') {
      agent { label params['JENKINS_AGENT_LABEL'] }
        when {
            expression { params.SCALE_UP.toInteger() > 0 || params.INFRA_WORKLOAD_INSTALL == true}
        }
        steps {
            script {
                build job: 'scale-ci/e2e-benchmarking-multibranch-pipeline/cluster-workers-scaling/',
                    parameters: [
                        string(name: 'BUILD_NUMBER', value: BUILD_NUMBER), text(name: "ENV_VARS", value: ENV_VARS),
                        string(name: 'WORKER_COUNT', value: SCALE_UP), string(name: 'JENKINS_AGENT_LABEL', value: JENKINS_AGENT_LABEL),
                        booleanParam(name: 'INFRA_WORKLOAD_INSTALL', value: INFRA_WORKLOAD_INSTALL)
                    ]
            }
      }
    }
    stage('Run Kube-Burner Test'){    
        agent {
          kubernetes {
            cloud 'PSI OCP-C1 agents'
            yaml """\
              apiVersion: v1
              kind: Pod
              metadata:
                labels:
                  label: ${JENKINS_AGENT_LABEL}
              spec:
                containers:
                - name: "jnlp"
                  image: "quay.io/openshift-qe-optional-operators/cucushift:${JENKINS_AGENT_LABEL}-rhel8"
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
                imagePullSecrets:
                - name: "docker-config-quay.io"
              """.stripIndent()
          }
        }
        steps {
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
                currentBuild.displayName = "${currentBuild.displayName}-${params.BUILD_NUMBER}-${params.WORKLOAD}"
                currentBuild.description = "Copying Artifact from Flexy-install build <a href=\"${buildinfo.buildUrl}\">Flexy-install#${params.BUILD_NUMBER}</a>"
                buildinfo.params.each { env.setProperty(it.key, it.value) }
            }
            script {
                if (params.EMAIL_ID_OVERRIDE != '') {
                    env.EMAIL_ID_FOR_RESULTS_SHEET = params.EMAIL_ID_OVERRIDE
                }
                else {
                    env.EMAIL_ID_FOR_RESULTS_SHEET = "${userId}@redhat.com"
                }
                withCredentials([usernamePassword(credentialsId: 'elasticsearch-perfscale-ocp-qe', usernameVariable: 'ES_USERNAME', passwordVariable: 'ES_PASSWORD'),
                    file(credentialsId: 'sa-google-sheet', variable: 'GSHEET_KEY_LOCATION')]) {
                    RETURNSTATUS = sh(returnStatus: true, script: '''
                        # Get ENV VARS Supplied by the user to this job and store in .env_override
                        echo "$ENV_VARS" > .env_override
                        # Export those env vars so they could be used by CI Job
                        set -a && source .env_override && set +a
                        cp $GSHEET_KEY_LOCATION $WORKSPACE/.gsheet.json
                        export GSHEET_KEY_LOCATION=$WORKSPACE/.gsheet.json
                        export EMAIL_ID_FOR_RESULTS_SHEET=$EMAIL_ID_FOR_RESULTS_SHEET
                        export ES_SERVER="https://$ES_USERNAME:$ES_PASSWORD@search-ocp-qe-perf-scale-test-elk-hcm7wtsqpxy7xogbu72bor4uve.us-east-1.es.amazonaws.com"
                        mkdir -p ~/.kube
                        cp $WORKSPACE/flexy-artifacts/workdir/install-dir/auth/kubeconfig ~/.kube/config
                        ls -ls ~/.kube/
                        
                        export CHURN_DURATION=${CHURN_DURATION:-10m}
                        export CHURN_DELAY=${CHURN_DELAY:-60s}
                        export CHURN_PERCENT=${CHURN_PERCENT:-10}
                        python3.9 --version
                        python3.9 -m pip install virtualenv
                        python3.9 -m virtualenv venv3
                        source venv3/bin/activate
                        python --version
                        
                        set -o pipefail
                        pwd
                        echo "workspace $WORKSPACE"
                        KUBE_DIR=$(mktemp -d)
 
                        curl -sS -L ${KUBE_BURNER_BINARY} | tar -xzC ${KUBE_DIR}/ kube-burner

                        if [[ $CHURN ]]; then
                            churn_val="--churn=true --churn-delay=${CHURN_DELAY} --churn-duration=${CHURN_DURATION} --churn-percent=${CHURN_PERCENT}"
                        fi
                        pwd
                        ${KUBE_DIR}/kube-burner ocp $WORKLOAD --iterations=$VARIABLE --timeout=6h --es-server=$ES_SERVER --es-index=ripsaw-kube-burner $churn_val |& tee "kube-burner.out"

                    ''')
                    output = sh(returnStdout: true, script: 'cat kube-burner.out')
                    archiveArtifacts(
                        artifacts: 'kube-burner.out',
                        allowEmptyArchive: true,
                        fingerprint: true
                    )
                    if (RETURNSTATUS.toInteger() == 0) {
                        status = "PASS"
                    }
                    else { 
                        currentBuild.result = "FAILURE"
                    }
                }
            }
        }
    }
    stage("Check cluster health") {
        agent { label params['JENKINS_AGENT_LABEL'] }
        when {
            expression { params.CERBERUS_CHECK == true }
        }
        steps {
            script {
                cerberus_job = build job: 'scale-ci/e2e-benchmarking-multibranch-pipeline/cerberus',
                    parameters: [
                        string(name: 'BUILD_NUMBER', value: BUILD_NUMBER),text(name: "ENV_VARS", value: ENV_VARS),
                        string(name: "CERBERUS_ITERATIONS", value: "1"), string(name: "CERBERUS_WATCH_NAMESPACES", value: "[^.*\$]"),
                        string(name: 'CERBERUS_IGNORE_PODS', value: "[^installer*, ^kube-burner*, ^redhat-operators*, ^certified-operators*]"),
                        string(name: 'JENKINS_AGENT_LABEL', value: JENKINS_AGENT_LABEL),booleanParam(name: "INSPECT_COMPONENTS", value: true),
                        string(name: "WORKLOAD", value: WORKLOAD)
                    ],
                    propagate: false
                if (status == "PASS") {
                    if (cerberus_job.result.toString() != "SUCCESS") {
                        status = "Cerberus check failed"
                        currentBuild.result = "FAILURE"
                    }
                }
                else {
                    if (cerberus_job.result.toString() != "SUCCESS") {
                        status += "Cerberus check failed"
                        currentBuild.result = "FAILURE"
                    }
                }
            }
        }
    }
    stage("Write out results") {
      agent { label params['JENKINS_AGENT_LABEL'] }
      when {
          expression { params.WRITE_TO_FILE == true }
      }
        steps {
          script {
              if (status != "PASS") {
                  currentBuild.result = "FAILURE"
              }
              def parameter_to_pass = VARIABLE
              if (params.WORKLOAD == "node-density" || params.WORKLOAD == "node-density-heavy") {
                  parameter_to_pass += "," + NODE_COUNT
              }
              else if (params.WORKLOAD == "concurrent-builds") {
                  parameter_to_pass = APP_LIST + "," + BUILD_LIST
              }
              build job: 'scale-ci/e2e-benchmarking-multibranch-pipeline/write-scale-ci-results',
                  parameters: [
                      string(name: 'BUILD_NUMBER', value: BUILD_NUMBER),text(name: "ENV_VARS", value: ENV_VARS),
                      string(name: 'CI_JOB_ID', value: BUILD_ID), string(name: 'CI_JOB_URL', value: BUILD_URL),
                      string(name: 'JENKINS_AGENT_LABEL', value: JENKINS_AGENT_LABEL), string(name: "CI_STATUS", value: "${status}"),
                      string(name: "JOB", value: WORKLOAD), string(name: "JOB_PARAMETERS", value: "${parameter_to_pass}" ),
                      text(name: "JOB_OUTPUT", value: "${output}")
                  ],
                  propagate: false
            }
        }
    }
    stage("Cleanup cluster of objects created in workload") {
      agent { label params['JENKINS_AGENT_LABEL'] }
      when {
          expression { params.CLEANUP == true}
      }
        steps {
          script {
              // if the build fails, cleaning and scale down will not happen, letting user review and decide if cluster is ready for scale down or re-run the job on same cluster
              build job: 'scale-ci/e2e-benchmarking-multibranch-pipeline/benchmark-cleaner',
                  parameters: [
                      string(name: 'BUILD_NUMBER', value: BUILD_NUMBER),text(name: "ENV_VARS", value: ENV_VARS),
                      string(name: 'JENKINS_AGENT_LABEL', value: JENKINS_AGENT_LABEL),
                      string(name: "CI_TYPE", value: WORKLOAD)
                  ],
                  propagate: false
              }
          }
    }
    stage("Scale down workers") {
      agent { label params['JENKINS_AGENT_LABEL'] }
      when {
          expression { params.SCALE_DOWN.toInteger() > 0 }
      }
        steps {
          script {
              build job: 'scale-ci/e2e-benchmarking-multibranch-pipeline/cluster-workers-scaling',
                  parameters: [
                      string(name: 'BUILD_NUMBER', value: BUILD_NUMBER), string(name: 'WORKER_COUNT', value: SCALE_DOWN),
                      text(name: "ENV_VARS", value: ENV_VARS), string(name: 'JENKINS_AGENT_LABEL', value: JENKINS_AGENT_LABEL)
                  ]
          }
      }
    }
  }
    post {
        always {
            script {
                if (params.SEND_SLACK == true ) {
                        build job: 'scale-ci/e2e-benchmarking-multibranch-pipeline/post-to-slack',
                        parameters: [
                            string(name: 'BUILD_NUMBER', value: BUILD_NUMBER), string(name: 'WORKLOAD', value: WORKLOAD),
                            text(name: "BUILD_URL", value: env.BUILD_URL), string(name: 'BUILD_ID', value: currentBuild.number.toString()),string(name: 'RESULT', value:currentBuild.currentResult)
                        ], propagate: false
                }
            }
        }
    }
}

