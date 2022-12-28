@Library('flexy') _

// rename build
def userId = currentBuild.rawBuild.getCause(hudson.model.Cause$UserIdCause)?.userId
if (userId) {
  currentBuild.displayName = userId
}

def RETURNSTATUS = "default"
def output = ""

def kraken_job = ""
def cerberus_job = ""
def upgrade_ci = ""

pipeline {
  agent none
  parameters {
        string(
          name: 'BUILD_NUMBER', 
          defaultValue: '', 
          description: 'Build number of job that has installed the cluster.'
        )
        string(
          name: 'UPGRADE_VERSION', 
          description: 'This variable sets the version number you want to upgrade your OpenShift cluster to.'
        )
        booleanParam(
          name: 'ENABLE_FORCE', 
          defaultValue: true, 
          description: 'This variable will force the upgrade or not'
        )
        string(
          name: 'MAX_UNAVAILABLE', 
          defaultValue: "1",
          description: 'This variable will set the max number of unavailable nodes during the upgrade'
        )
        string(
            name: "CERBERUS_WATCH_NAMESPACES", 
            defaultValue: "[^.*\$]",
            description: "Which specific namespaces you want to watch any failing components, use [^.*\$] if you want to watch all namespaces"
        )
        string(
            name: "CERBERUS_IGNORE_PODS",
            defaultValue: "[^installer*, ^kube-burner*, ^redhat-operators*, ^certified-operators*]", 
            description: "Which specific pod names regex patterns you want to ignore in the namespaces you defined above"
        )
        string(
            name: 'CERBERUS_ITERATIONS', 
            defaultValue: '', 
            description: 'Number of iterations to run of cerberus.'
        )
        string(
          name: "PAUSE_TIME",
          defaultValue: "100",
          description: 'Amount of time to pause before running chaos scenarios'
        )
        choice(
          choices: ["application-outages","container-scenarios","namespace-scenarios","network-scenarios","node-scenarios","pod-scenarios","node-cpu-hog","node-io-hog", "node-memory-hog", "power-outages","pvc-scenario","time-scenarios","zone-outages"], 
          name: 'KRAKEN_SCENARIO', 
          description: '''Type of kraken scenario to run'''
        )
        choice(
          choices: ["python","pod"], 
          name: 'KRAKEN_RUN_TYPE', 
          description: '''Type of way to run chaos scenario'''
        )
        string(
            name: 'ITERATIONS', 
            defaultValue: '', 
            description: 'Number of iterations to run of kraken scenario.'
        )
        string(
          name:'JENKINS_AGENT_LABEL',
          defaultValue:'oc412',
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
               See https://github.com/redhat-chaos/krkn-hub/blob/main/docs/cerberus.md for list of variables to pass <br>
               e.g.<br>
               SOMEVAR1='env-test'<br>
               SOMEVAR2='env2-test'<br>
               ...<br>
               SOMEVARn='envn-test'<br>
               </p>'''
        )
        string(
            name: 'CERBERUS_REPO',
            defaultValue: 'https://github.com/redhat-chaos/cerberus',
            description: 'You can change this to point to your fork if needed.'
        )
        string(
            name: 'CERBERUS_REPO_BRANCH',
            defaultValue: 'main', 
            description: 'You can change this to point to a branch on your fork if needed.'
        )
       string(
        name: 'KRAKEN_REPO', 
        defaultValue:'https://github.com/redhat-chaos/krkn', 
        description:'You can change this to point to your fork if needed.'
       )
       string(
        name: 'KRAKN_REPO_BRANCH', 
        defaultValue:'main', 
        description:'You can change this to point to a branch on your fork if needed.'
       )
       string(
        name: 'KRAKEN_HUB_REPO', 
        defaultValue:'https://github.com/redhat-chaos/krkn-hub', 
        description:'You can change this to point to your fork if needed.'
        )
       string(
        name: 'KRAKN_HUB_REPO_BRANCH', 
        defaultValue:'main', 
        description:'You can change this to point to a branch on your fork if needed.'
      )
     }

  stages {
    stage("Set base variables") { 
        agent { label params['JENKINS_AGENT_LABEL'] }
            steps {
                script {

                  if ( UPGRADE_VERSION == "" ) {
                    currentBuild.description = """
                      Running kraken and cerberus in parallel<br>
                    """
                  } else {
                    currentBuild.description = """
                      Running kraken during an upgrade and cerberus all in parallel <br>
                    """
                  }
                }
      }
    }
    stage("Run parallel tests") {
    parallel {
      stage("Check cluster health") {
          agent { label params['JENKINS_AGENT_LABEL'] }
          steps {
              script {
                  cerberus_job = build job: 'scale-ci/e2e-benchmarking-multibranch-pipeline/cerberus',
                      parameters: [
                          string(name: 'BUILD_NUMBER', value: BUILD_NUMBER),text(name: "ENV_VARS", value: ENV_VARS),
                          string(name: "CERBERUS_WATCH_NAMESPACES", value: CERBERUS_WATCH_NAMESPACES),
                          string(name: 'CERBERUS_IGNORE_PODS', value: CERBERUS_IGNORE_PODS),string(name: 'CERBERUS_ITERATIONS', value: CERBERUS_ITERATIONS),
                          string(name: 'JENKINS_AGENT_LABEL', value: JENKINS_AGENT_LABEL),booleanParam(name: "INSPECT_COMPONENTS", value: false),
                          string(name: "ENV_VARS", value: ENV_VARS)
                      ],
                      propagate: false
                  currentBuild.description += """
                      <b>Cerberus Job: </b> <a href="${cerberus_job.absoluteUrl}"> ${params.CERBERUS_ITERATIONS} iterations were ran</a> <br/>
                  """
              }
          }
        }
      stage("Start Kraken run") {
          agent { label params['JENKINS_AGENT_LABEL'] }
          steps {
              script {
                    kraken_job = build job: 'scale-ci/e2e-benchmarking-multibranch-pipeline/kraken',
                      parameters: [
                          string(name: 'BUILD_NUMBER', value: BUILD_NUMBER),text(name: "ENV_VARS", value: ENV_VARS),
                          string(name: "KRAKEN_REPO", value: KRAKEN_REPO),string(name: "KRAKN_REPO_BRANCH", value: KRAKN_REPO_BRANCH),
                          string(name: "KRAKEN_HUB_REPO", value: KRAKEN_HUB_REPO),string(name: "KRAKN_HUB_REPO_BRANCH", value: KRAKN_HUB_REPO_BRANCH),
                          string(name: 'KRAKEN_SCENARIO', value: KRAKEN_SCENARIO),string(name: "KRAKEN_RUN_TYPE", value: KRAKEN_RUN_TYPE),
                          string(name: 'JENKINS_AGENT_LABEL', value: JENKINS_AGENT_LABEL),string(name: "PAUSE_TIME", value: PAUSE_TIME),
                          string(name: "ITERATIONS", value: ITERATIONS),string(name: "ENV_VARS", value: ENV_VARS)
                      ],
                      propagate: false
                    currentBuild.description += """
                      <b>Kraken Job: </b> <a href="${kraken_job.absoluteUrl}"> ${KRAKEN_SCENARIO} </a> <br/>
                  """
              }
          }
        }
      stage('Upgrade'){
          agent { label params['JENKINS_AGENT_LABEL'] }
          when {
              expression { UPGRADE_VERSION != "" }
          }
          steps{
              script{
                  currentBuild.description += """
                      <b>Upgrade to: </b> ${UPGRADE_VERSION} <br/>
                  """
                  upgrade_ci = build job: "scale-ci/e2e-benchmarking-multibranch-pipeline/upgrade", propagate: false,parameters:[
                      string(name: "BUILD_NUMBER", value: BUILD_NUMBER),string(name: "MAX_UNAVAILABLE", value: MAX_UNAVAILABLE),
                      string(name: "JENKINS_AGENT_LABEL", value: JENKINS_AGENT_LABEL),string(name: "UPGRADE_VERSION", value: UPGRADE_VERSION),
                      booleanParam(name: "ENABLE_FORCE", value: ENABLE_FORCE),booleanParam(name: "WRITE_TO_FILE", value: false),
                      text(name: "ENV_VARS", value: ENV_VARS)
                  ]
                  currentBuild.description += """
                      <b>Upgrade Job: </b> <a href="${upgrade_ci.absoluteUrl}"> ${upgrade_ci.getNumber()} </a> <br/>
                  """
                  
              }
          }
      }
    }
    }
  stage('Set status') {
    agent { label params['JENKINS_AGENT_LABEL'] }
    steps {
      script{
        def status = ""
        if ( upgrade_ci != "" ) {
          if ( upgrade_ci.result.toString() != "SUCCESS" ) { 
            status += "Upgrade Failed"
            currentBuild.result = "FAILURE"
          } else { 
            status += "Upgrade Passed"
          }
        }
        if ( kraken_job != "" ) {
          if (status != "" ) {
              status += ","
            }
          if ( kraken_job.result.toString() != "SUCCESS" ){
              status += "Kraken Failed"
              currentBuild.result = "FAILURE"
          } else { 
            status += "Kraken Passed"
          }
        }
        if ( cerberus_job != "" ) {
          if (status != "" ) {
              status += ","
            }
          if ( cerberus_job.result.toString() != "SUCCESS" ) {
            if (status != "" ) {
              status += ","
            }
              status += "Cerberus Failed"
              currentBuild.result = "FAILURE"
          } else { 
            status += "Cerberus Passed"
          }
        }
        currentBuild.description += """
            <b>Final Status: </b> ${status} <br/>
        """
        }
      }
    }
  }
}
