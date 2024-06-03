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
            name: 'OCM_TOKEN_URL',
            defaultValue: 'https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token',
            description: 'OCM Token URL'
        )
        string(
            name: 'GATEWAY_URL',
            defaultValue: 'https://api.integration.openshift.com',
            description: 'Gateway URL'
        )
        string(
            name: 'JOB_TIMEOUT',
            defaultValue: '28800',
            description: 'Job Timeout'
        )
        string(
            name: 'COOLDOWN',
            defaultValue: '60',
            description: 'Cooldown'
        )
        string(
            name: 'SLEEP',
            defaultValue: '300',
            description: 'Sleep'
        )
        string(
            name: 'ORCHESTRATION_USER',
            defaultValue: '',
            description: 'Orchestration User'
        )
        string(
            name: 'ORCHESTRATION_HOST',
            defaultValue: '',
            description: 'Orchestration Host'
        )
        string(
            name: 'KUBE_BURNER_RELEASE_URL',
            defaultValue: 'https://github.com/cloud-bulldozer/kube-burner/releases/download/v0.16.1/kube-burner-0.16.1-Linux-x86_64.tar.gz',
            description: 'Kube Burner Release URL'
        )
        string(
            name: 'PROM_URL',
            defaultValue: 'https://prometheus.app-sre-stage-01.devshift.net',
            description: 'Prometheus URL'
        )
        booleanParam(
            name: "SEND_SLACK",
            defaultValue: false,
            description: "Check this box to send a Slack notification to #ocp-qe-scale-ci-results upon the job's completion"
        )
        string(
            name: 'QE_OCM_REPO',
            defaultValue: 'https://github.com/chentex/ocp-qe-perfscale-ci',
            description: 'You can change this to point to your fork if needed.'
        )
        string(
            name: 'QE_OCM_REPO_BRANCH',
            defaultValue: 'master',
            description: 'You can change this to point to a branch on your fork if needed.'
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
    }

    stages {
        stage('Run OCM API Load tests'){
            steps {
                deleteDir()
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: params.QE_OCM_REPO_BRANCH ]],
                    doGenerateSubmoduleConfigurations: false,
                    userRemoteConfigs: [[url: params.QE_OCM_REPO ]]
                ])
                script {
                    '''
                    ./scripts/run_ocm_benchmark.sh
                    '''
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
                        string(name: 'BUILD_NUMBER', value: BUILD_NUMBER), string(name: 'WORKLOAD', value: "OCM API Load Test"),
                        text(name: "BUILD_URL", value: env.BUILD_URL), string(name: 'BUILD_ID', value: currentBuild.number.toString()),string(name: 'RESULT', value:currentBuild.currentResult)
                    ], propagate: false
                }
            }
        }
    }
}
