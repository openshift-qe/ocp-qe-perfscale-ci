@Library('flexy') _

// rename build
def userCause = currentBuild.rawBuild.getCause(Cause.UserIdCause)
def upstreamCause = currentBuild.rawBuild.getCause(Cause.UpstreamCause)

userId = "ocp-perfscale-qe"
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
def status = ""

def JENKINS_JOB_NUMBER = currentBuild.number.toString()
println "JENKINS_JOB_NUMBER $JENKINS_JOB_NUMBER"

pipeline {
    agent { label params['JENKINS_AGENT_LABEL'] }
    parameters {
        string(
            name: 'BUILD_NUMBER',
            defaultValue: '',
            description: 'Build number of job that has installed the cluster.'
        )
        string(
            name: "CONFIG",
            defaultValue: "config/standard.yml",
            description: "Config file to run, will auto set folder to under e2e-benchmark/ingress-perf"
        )
        string(
            name: "VERSION",
            defaultValue: "",
            description: "Version of ingress perf to run, default will be set in e2e-benchmark"
        )
        booleanParam(
            name: 'WRITE_TO_FILE',
            defaultValue: false,
            description: 'Value to write to google sheet (will run <a href=https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/job/scale-ci/job/e2e-benchmarking-multibranch-pipeline/job/write-scale-ci-results/>write-scale-ci-results</a>)'
        )
        booleanParam(
            name: 'WRITE_TO_ES',
            defaultValue: false,
            description: 'Value to write to elastic seach under metricName: jenkinsEnv'
        )
        booleanParam(
            name: 'CERBERUS_CHECK',
            defaultValue: false,
            description: 'Check cluster health status pass'
        )
        booleanParam(
            name: 'MUST_GATHER', 
            defaultValue: true, 
            description: 'This variable will run must-gather if any cerberus components fail'
        )
        string(
          name: 'IMAGE_STREAM', 
          defaultValue: 'openshift/must-gather', 
          description: 'Base image stream of data to gather for the must-gather.'
        )
        string(
          name: 'IMAGE', 
          defaultValue: '', 
          description: 'Optional image to help get must-gather information on non default areas. See <a href="https://docs.openshift.com/container-platform/4.12/support/gathering-cluster-data.html">docs</a> for more information and options.'
        )
        string(
            name: 'JENKINS_AGENT_LABEL',
            defaultValue: 'oc412',
            description: '''
                scale-ci-static: for static agent that is specific to scale-ci, useful when the jenkins dynamic agen isn't stable<br>
                4.y: oc4y e.g, for 4.12, use oc412
            '''
        )
        string(
            name: 'BASELINE_UUID',
            defaultValue: '',
            description: 'Baseline UUID used for comparison'
        )
        string(
            name: 'EMAIL_ID_OVERRIDE',
            defaultValue: '',
            description: '''
                Email to share Google Sheet results with<br/>
                By default shares with email of person who ran the job
            '''
        )
        booleanParam(
            name: "SEND_SLACK",
            defaultValue: false,
            description: "Check this box to send a Slack notification to #ocp-qe-scale-ci-results upon the job's completion"
        )
        string(
            name: 'TOLERANCY',
            defaultValue: '-10',
            description: '''
                Tolerancy to replace value of tolerancy in <a href="https://github.com/cloud-bulldozer/e2e-benchmarking/blob/master/workloads/ingress-perf">tolerancy</a>.<br>
                i.e a 10 would mean any metric 10% higher than the baseline metric will be considered an error<br>
                , and -10 would mean the opposite, any metric at least 10% below the baseline value will be considered an error.<br>
                Set to blank will not use TOLERANCY_RULES.
            '''
        )
        text(
            name: 'ENV_VARS',
            defaultValue: '',
            description: '''
                Enter list of additional (optional) Env Vars you'd want to pass to the script, one pair on each line.<br/>
                e.g.<br/>
                SOMEVAR1='env-test'<br/>
                SOMEVAR2='env2-test'<br/>
                ...<br/>
                SOMEVARn='envn-test'<br/>
                check <a href="https://github.com/cloud-bulldozer/e2e-benchmarking/tree/master/workloads/ingress-perf">ingress perf README</a> for more env vars you can set
            '''
        )
        booleanParam(
            name: 'INFRA_WORKLOAD_INSTALL',
            defaultValue: false,
            description: '''
                Install workload and infrastructure nodes even if less than 50 nodes.<br/>
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
                If value is set to anything greater than 0, cluster will be scaled down after the execution of the workload is complete,<br/>
                if the build fails, scale down may not happen, user should review and decide if cluster is ready for scale down or re-run the job on same cluster.
            '''
        )
        string(
            name: 'E2E_BENCHMARKING_REPO',
            defaultValue: 'https://github.com/cloud-bulldozer/e2e-benchmarking',
            description:'You can change this to point to your fork if needed.'
        )
        string(
            name: 'E2E_BENCHMARKING_REPO_BRANCH',
            defaultValue: 'master',
            description: 'You can change this to point to a branch on your fork if needed.'
        )
    }

    stages {
        stage('Run Ingress perf tests'){
            steps {
                script {
                    if (params.SCALE_UP.toInteger() > 0) {
                        build job: 'scale-ci/e2e-benchmarking-multibranch-pipeline/cluster-workers-scaling', 
                            parameters: [
                                string(name: 'BUILD_NUMBER', value: BUILD_NUMBER), text(name: "ENV_VARS", value: ENV_VARS), 
                                string(name: 'WORKER_COUNT', value: SCALE_UP), 
                                string(name: 'JENKINS_AGENT_LABEL', value: JENKINS_AGENT_LABEL), 
                                booleanParam(name: 'INFRA_WORKLOAD_INSTALL', value: INFRA_WORKLOAD_INSTALL)
                            ]
                    }
                }
                deleteDir()
                checkout([
                    $class: 'GitSCM', 
                    branches: [[name: params.E2E_BENCHMARKING_REPO_BRANCH ]],
                    doGenerateSubmoduleConfigurations: false, 
                    userRemoteConfigs: [[url: params.E2E_BENCHMARKING_REPO ]]
                ])
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
                            export ES_SERVER="https://$ES_USERNAME:$ES_PASSWORD@search-ocp-qe-perf-scale-test-elk-hcm7wtsqpxy7xogbu72bor4uve.us-east-1.es.amazonaws.com"
                            export ES_SERVER_BASELINE="https://$ES_USERNAME:$ES_PASSWORD@search-ocp-qe-perf-scale-test-elk-hcm7wtsqpxy7xogbu72bor4uve.us-east-1.es.amazonaws.com"
                            mkdir -p ~/.kube
                            cp $WORKSPACE/flexy-artifacts/workdir/install-dir/auth/kubeconfig ~/.kube/config
                            oc config view
                            oc projects
                            ls -ls ~/.kube/
                            env
                            cd workloads/ingress-perf
                            ./run.sh |& tee "ingress_perf.out"
                            ! grep "Benchmark comparison failed" ingress_perf.out
                            '''
                        )
                        archiveArtifacts(
                            artifacts: 'workloads/ingress-perf/ingress_perf.out',
                            allowEmptyArchive: true,
                            fingerprint: true
                        )
                        if (RETURNSTATUS.toInteger() == 0) {
                            status = "PASS"
                        }
                        else {
                            currentBuild.result = "FAILURE"
                            status = "Ingress perf FAIL"
                        }
                    }
                }
                script{
                    if (params.CERBERUS_CHECK == true) {
                        cerberus_job = build job: 'scale-ci/e2e-benchmarking-multibranch-pipeline/cerberus',
                            parameters: [
                                string(name: 'BUILD_NUMBER', value: BUILD_NUMBER),text(name: "ENV_VARS", value: ENV_VARS),
                                string(name: "CERBERUS_ITERATIONS", value: "1"), string(name: "CERBERUS_WATCH_NAMESPACES", value: "[^.*\$]"),
                                string(name: 'CERBERUS_IGNORE_PODS', value: "[^installer*, ^kube-burner*, ^redhat-operators*, ^certified-operators*]"),
                                string(name: 'JENKINS_AGENT_LABEL', value: JENKINS_AGENT_LABEL),booleanParam(name: "INSPECT_COMPONENTS", value: true),
                                booleanParam(name: "MUST_GATHER", value: MUST_GATHER),string(name: 'IMAGE', value: IMAGE),
                                string(name: 'IMAGE_STREAM', value: IMAGE_STREAM)
                            ],
                            propagate: false
                        def result = cerberus_job.result.toString()
                        println "cerberus result $result"
                        if (status == "PASS") {
                            println "previous status = pass"
                            if (cerberus_job.result.toString() != "SUCCESS") {
                                status = "Cerberus check failed"
                                currentBuild.result = "FAILURE"
                            }
                        }
                        else {
                            println "previous test had already failed"
                            if (cerberus_job.result.toString() != "SUCCESS") {
                                status += ", Cerberus check failed"
                                currentBuild.result = "FAILURE"
                            }
                        }
                    }
                }
                script{
                    if (params.WRITE_TO_FILE == true) {
                        def parameter_to_pass = ""
                        build job: 'scale-ci/e2e-benchmarking-multibranch-pipeline/write-scale-ci-results', 
                            parameters: [
                                string(name: 'BUILD_NUMBER', value: BUILD_NUMBER),text(name: "ENV_VARS", value: ENV_VARS),
                                string(name: 'CI_JOB_ID', value: BUILD_ID), string(name: 'CI_JOB_URL', value: BUILD_URL), 
                                string(name: 'JENKINS_AGENT_LABEL', value: JENKINS_AGENT_LABEL), string(name: "CI_STATUS", value: "${status}"), 
                                string(name: "JOB", value: "ingress-perf"), string(name: "JOB_PARAMETERS", value: "${parameter_to_pass}" ), 
                                string(name: "JENKINS_JOB_NUMBER", value: JENKINS_JOB_NUMBER), string(name: "JENKINS_JOB_PATH", value: JOB_NAME)
                            ],
                            propagate: false
                    }
                }
                script {
                    if (params.WRITE_TO_ES == true ){
                        build job: 'scale-ci/e2e-benchmarking-multibranch-pipeline/post-results-to-es',
                        parameters: [
                            string(name: 'BUILD_NUMBER', value: BUILD_NUMBER),text(name: "ENV_VARS", value: ENV_VARS),
                            string(name: "JENKINS_JOB_NUMBER", value: JENKINS_JOB_NUMBER), string(name: "JENKINS_JOB_PATH", value: JOB_NAME),
                            string(name: 'JENKINS_AGENT_LABEL', value: JENKINS_AGENT_LABEL), string(name: "CI_STATUS", value: "${status}"),
                            string(name: "WORKLOAD", value: "ingress-perf")
                        ],
                        propagate: false
                    }
                }
                script{
                    // if the build fails, scale down will not happen, letting user review and decide if cluster is ready for scale down or re-run the job on same cluster
                    if (params.SCALE_DOWN.toInteger() > 0) {
                        build job: 'scale-ci/e2e-benchmarking-multibranch-pipeline/cluster-workers-scaling', 
                            parameters: [
                                string(name: 'BUILD_NUMBER', value: BUILD_NUMBER), string(name: 'WORKER_COUNT', value: SCALE_DOWN), 
                                text(name: "ENV_VARS", value: ENV_VARS), string(name: 'JENKINS_AGENT_LABEL', value: JENKINS_AGENT_LABEL)
                            ]
                    }
                }
           }
        }
    }
    post {
        always {
          
            println 'Post Section - Always'
            
            script {
                if (params.SEND_SLACK == true ) {
                    build job: 'scale-ci/e2e-benchmarking-multibranch-pipeline/post-to-slack',
                    parameters: [
                        string(name: 'BUILD_NUMBER', value: BUILD_NUMBER), string(name: 'WORKLOAD', value: "ingress-perf"),
                        text(name: "BUILD_URL", value: env.BUILD_URL), string(name: 'BUILD_ID', value: currentBuild.number.toString()),string(name: 'RESULT', value:currentBuild.currentResult)
                    ], propagate: false
                }
            }
        }
    }
}
