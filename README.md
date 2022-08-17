# Perf&Scale Regression Test Job
This job is used to trigger Perf&Scale regression test cases.
### Parameters

| Variable         | Description                         | Default |
|------------------|-------------------------------------|---------|
| **BUILD_NUMBER** | Flexy install build number          |         |
| **TEST_CASE**   | Test case name. This job will search the <TEST_CASE>.sh file under svt repo <a href="https://github.com/openshift/svt/blob/master/perfscale_regression_ci/scripts">perfscale_regression_ci/scripts</a> folder and sub folders. If SCRIPT is specified, TEST_CASE will be overwritten.|conc_job |
| **SCRIPT**       | Relative path to the script of the TEST_CASE under <a href="https://github.com/openshift/svt">svt repo</a>. If TEST_CASE is specified, SCRIPT will overwrite the TEST_CASE.||
| **PARAMETERS**   | Parameter or an an array of parameters to be passed to the test case script||
| **SVT_REPO**     | Repository to get regression test scripts and artifacts|https://github.com/openshift/svt|
| **SVT_REPO_BRANCH**| Branch of SVT_REPO to get regression test scripts|master|
| **JENKINS_AGENT_LABEL**| Jenkins agent label           |oc411    |
| **ENV_VARS**| Env vars you'd want to pass to the script|         |

### Contacts
qili@redhat.com
