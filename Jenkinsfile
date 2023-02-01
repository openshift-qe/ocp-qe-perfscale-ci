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
        println "$upstreamBuild"
        if (upstreamBuild) {
            def realUpstreamCause = upstreamBuild.getCause(Cause.UserIdCause)
            println "$realUpstreamCause"
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

pipeline {
  agent none

  parameters {
      string(
          name: 'BUILD_NUMBER',
          defaultValue: '',
          description: 'Build number of job that has installed the cluster.'
      )
      string(
          name: 'WORKLOAD',
          defaultValue: "",
          description: 'Type of workload job that was ran'
      )
      string(
          name: 'BUILD_URL',
          defaultValue: "",
          description: 'Build URL that was ran'
      )
      string(
          name: 'BUILD_ID',
          defaultValue: "",
          description: 'Build ID that was ran'
      )
      string(
          name: 'RESULT',
          defaultValue: "",
          description: 'Result of the job that was ran'
      )
      string(
          name: 'SLACK_CHANNEL',
          defaultValue: "ocp-qe-scale-ci-results",
          description: 'Result of the job that was ran'
      )
  }
  stages {  
    stage("Send Slack Status") {
      steps {
        script {
          println "Sending Slack notification to #${params.SLACK_CHANNEL}..."
          println "user id $userId"
          msg = "@${userId}, your *${params.WORKLOAD}* job with id <${params.BUILD_URL}|${params.BUILD_ID}> exited with status: *${params.RESULT}*"
          if (currentBuild.currentResult == 'SUCCESS') {
              slackSend channel: "$params.SLACK_CHANNEL",
                  message: "${msg}",
                  color: "good"
          } else {
              slackSend channel: "$params.SLACK_CHANNEL",
                  message: "${msg}"
          }

           }
       }
      }
    }
 }

