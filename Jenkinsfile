
def aws = null
def install = null
def scale_up = null
def loaded_ci = null
def health_check = null
def upgrade_ci = null
def destroy_ci = null
def must_gather = null
def build_string = "DEFAULT"
def load_result = "SUCCESS"
def loaded_url = ""
def upgrade_url = ""
def must_gather_url = ""
def proxy_settings = ""
def status = "PASS"
def VERSION = ""
def global_scale_num = 0

def userId = currentBuild.rawBuild.getCause(hudson.model.Cause$UserIdCause)?.userId
if (userId) {
  currentBuild.displayName = "${userId}-${currentBuild.displayName}"
}

pipeline{
    agent any

    parameters {
      separator(
        name: "PRE_BUILT_FLEXY_ENV", 
        sectionHeader: "Pre Built Flexy", 
        sectionHeaderStyle: """
          font-size: 18px;
          font-weight: bold;
          font-family: 'Orienta', sans-serif;
        """
      )
      string(
        name: 'BUILD_NUMBER', 
        defaultValue: '', 
        description: 'Build number of job that has installed the cluster.'
      )

      separator(
        name: "BUILD_FLEXY_COMMON_PARAMS", 
        sectionHeader: "Build Flexy Parameters Common", 
        sectionHeaderStyle: """
          font-size: 18px;
          font-weight: bold;
          font-family: 'Orienta', sans-serif;
        """
      )
      string(
        name: 'OCP_PREFIX', 
        defaultValue: '', 
        description: 'Name of ocp cluster you want to build'
      )
      string(
        name: 'OCP_VERSION',
        defaultValue: '', 
        description: 'Build version to install the cluster.'
      )
      choice(
        choices: ["",'x86_64','aarch64', 's390x', 'ppc64le', 'multi', 'multi-aarch64','multi-x86_64','multi-ppc64le', 'multi-s390x'], 
        name: 'ARCH_TYPE', 
        description: '''Type of architecture installation for quay image url; <b>
        set to x86_64 by default or if profile contains ARM will set to aarch64
        If this is not blank will use value you set here'''
      )
        
      separator(
        name: "BUILD_FLEXY_FROM_PROFILE", 
        sectionHeader: "Build Flexy From Profile", 
        sectionHeaderStyle: """
          font-size: 18px;
          font-weight: bold;
          font-family: 'Orienta', sans-serif;
        """
      )
      string(
        name: 'CI_PROFILE', 
        defaultValue: '', 
        description: """Name of ci profile to build for the cluster you want to build <br>
          You'll give the name of the file (under the specific version) without `.install.yaml`
        """
      )
      choice(
        choices: ['extra-small','small','medium',''], 
        name: 'PROFILE_SCALE_SIZE', 
        description: """Set scale size to set number of workers to add and define size of masters and workers. <br>
        For information about size definitions see <a href="https://gitlab.cee.redhat.com/aosqe/ci-profiles/-/blob/master/scale-ci/4.11/02_IPI-on-AWS.install.yaml#L10"> here </a> (will need ot look at your specific profile) <br>
        set Size of cluster to scale to; will be ignored if SCALE_UP is set"""
      )
      separator(
        name: "BUILD_FLEXY", 
        sectionHeader: "Build Flexy Parameters", 
        sectionHeaderStyle: """
          font-size: 18px;
          font-weight: bold;
          font-family: 'Orienta', sans-serif;
        """
      )
      choice(
        choices: ['','aws', 'azure', 'gcp', 'osp', 'alicloud', 'ibmcloud', 'vsphere', 'ash'], 
        name: 'CLOUD_TYPE',
        description: '''Cloud type (As seen on https://gitlab.cee.redhat.com/aosqe/flexy-templates/-/tree/master/functionality-testing/aos-4_9, after ""-on-") <br/>
          Will be ignored if BUILD_NUMBER is set'''
        )
      choice(
        choices: ['','ovn', 'sdn'], 
        name: 'NETWORK_TYPE', 
        description: 'Network type, will be ignored if BUILD_NUMBER is set'
      )
      choice(
        choices: ['','ipi', 'upi', 'sno'], 
        name: 'INSTALL_TYPE', 
        description: '''Type of installation (set to SNO for sno cluster type),  <br/>
          will be ignored if BUILD_NUMBER is set'''
      )
      string(
        name: 'MASTER_COUNT', 
        defaultValue: '3', 
        description: 'Number of master nodes in your cluster to create.'
      )
      string(
        name: "WORKER_COUNT", 
        defaultValue: '3', 
        description: 'Number of worker nodes in your cluster to create.'
      )
        separator(name: "SCALE_UP_JOB_INFO", sectionHeader: "Scale Up Job Options", sectionHeaderStyle: """
				font-size: 18px;
				font-weight: bold;
				font-family: 'Orienta', sans-serif;
			""")
	    booleanParam(
        name: 'INFRA_WORKLOAD_INSTALL', 
        defaultValue: false, 
        description: 'Install workload and infrastructure nodes even if less than 50 nodes. <br> Checking this parameter box is valid only when SCALE_UP is greater than 0.'
      )
      string(
        name: 'SCALE_UP', 
        defaultValue: '0', 
        description: 'If value is set to anything greater than 0, cluster will be scaled up before executing the workload.'
      )
      string(name: 'SCALE_DOWN', 
        defaultValue: '0', 
        description:
        '''If value is set to anything greater than 0, cluster will be scaled down after the execution of the workload is complete,<br>
        if the build fails, scale down may not happen, user should review and decide if cluster is ready for scale down or re-run the job on same cluster.'''
      )
      separator(
        name: "SCALE_CI_JOB_INFO", 
        sectionHeader: "Scale-CI Job Options", 
        sectionHeaderStyle: """
          font-size: 18px;
          font-weight: bold;
          font-family: 'Orienta', sans-serif;"""
      )
      choice(
        choices: ["","cluster-density", "cluster-density-ms","node-density", "node-density-heavy","node-density-cni","node-density-cni-networkpolicy","pod-density", "pod-density-heavy", "max-namespaces", "max-services", "concurrent-builds","pods-service-route","networkpolicy-case1","networkpolicy-case2","networkpolicy-case3","pod-network-policy-test","router-perf","network-perf-hostnetwork-network-test","network-perf-pod-network-test","network-perf-serviceip-network-test","regression-test"], 
        name: 'CI_TYPE', 
        description: '''Type of scale-ci job to run. Can be left blank to not run ci job <br>
          Router-perf tests will use all defaults if selected, all parameters in this section below will be ignored '''
      )
      string(
        name: 'VARIABLE', 
        defaultValue: '1000', 
        description: '''
        This variable configures parameter needed for each type of workload. By default 1000. <br>
        pod-density: This will export PODS env variable; set to 200 * num_workers, work up to 250 * num_workers. Creates as many "sleep" pods as configured in this environment variable. <br>
        cluster-density: This will export JOB_ITERATIONS env variable; set to 4 * num_workers. This variable sets the number of iterations to perform (1 namespace per iteration). <br>
        max-namespaces: This will export NAMESPACE_COUNT env variable; set to ~30 * num_workers. The number of namespaces created by Kube-burner. <br>
        max-services: This will export SERVICE_COUNT env variable; set to 200 * num_workers, work up to 250 * num_workers. Creates n-replicas of an application deployment (hello-openshift) and a service in a single namespace. <br>
        node-density: This will export PODS_PER_NODE env variable; set to 200, work up to 250. Creates as many "sleep" pods as configured in this variable - existing number of pods on node. <br>
        node-density-heavy: This will export PODS_PER_NODE env variable; set to 200, work up to 250. Creates this number of applications proportional to the calculated number of pods / 2 <br>
        regression-test: This will pass this value to PARAMETERS; Parameter or an array of parameters to pass to the TEST_CASE script <br>
        Read here for detail of each variable: <br>
        https://github.com/cloud-bulldozer/e2e-benchmarking/blob/master/workloads/kube-burner/README.md <br>
        '''
      )

      separator(
        name: "NODE_DENSITY_JOB_INFO", 
        sectionHeader: "Node Density Job Options", 
        sectionHeaderStyle: """
          font-size: 14px;
          font-weight: bold;
          font-family: 'Orienta', sans-serif;"""
      )
      string(
        name: 'NODE_COUNT', 
        defaultValue: '3', 
        description: 'Number of worker nodes to be used in your cluster for this workload.'
      )
      separator(
        name: "CONCURRENT_BUILDS_JOB_INFO", 
        sectionHeader: "Concurrent Builds Job Options", 
        sectionHeaderStyle: """
          font-size: 14px;
          font-weight: bold;
          font-family: 'Orienta', sans-serif;"""
      )
      string(
        name: 'BUILD_LIST',
        defaultValue: "1 8 15 30 45 60 75", 
        description: 'Number of concurrent builds to run at a time; will run 2 iterations of each number in this list'
      )
      string(
        name: 'APP_LIST', 
        defaultValue: 'cakephp eap django nodejs', 
        description: 'Applications to build, will run each of the concurrent builds against each application. Best to run one application at a time'
      )

      separator(
        name: "REGRESSION_TEST_JOB_INFO", 
        sectionHeader: "Regression Test Job Options", 
        sectionHeaderStyle: """
          font-size: 14px;
          font-weight: bold;
          font-family: 'Orienta', sans-serif;"""
      )
      choice(
        choices: ["conc_jobs","large_network_policy"], 
        name: 'TEST_CASE',
        description:'''<p>
        Select the test case you want to run.<br>
        This job will search the TEST_CASE.sh file under svt repo <a href="https://github.com/openshift/svt/blob/master/perfscale_regression_ci/scripts">perfscale_regression_ci/scripts</a> folder and sub folders<br>
        If SCRIPT is specified TEST_CASE will be overwritten.
        </p>'''
      )
      string(
        name: 'SCRIPT',
        defaultValue: '',
        description: '''<p>
        Relative path to the script of the TEST_CASE under <a href="https://github.com/openshift/svt">svt repo</a>.<br>
        If you want to use script from your own repo you need to change also SVT_REPO variable. <br>
        e.g.<br>
        For large_network_policy test case: perfscale_regression_ci/scripts/network/large_network_policy.sh<br>
        If TEST_CASE is specified, SCRIPT will overwrite the TEST_CASE.
        </p>'''
      )
      separator(
        name: "NETWORK_PERF_INFO", 
        sectionHeader: "Network-Perf Job Options", 
        sectionHeaderStyle: """
          font-size: 14px;
          font-weight: bold;
          font-family: 'Orienta', sans-serif;"""
      )
      choice(
        choices: ['smoke', 'pod2pod', 'hostnet', 'pod2svc'],
        name: 'WORKLOAD_TYPE',
        description: 'Workload type'
      )
      booleanParam(
        name: "NETWORK_POLICY",
        defaultValue: false,
        description: "If enabled, benchmark-operator will create a network policy to allow ingress trafic in uperf server pods"
      )

      separator(
        name: "UPGRADE_INFO",
        sectionHeader: "Upgrade Options",
        sectionHeaderStyle: """
        font-size: 18px;
        font-weight: bold;
        font-family: 'Orienta', sans-serif;"""
      )
      string(
        name: 'UPGRADE_VERSION',
        description: 'This variable sets the version number you want to upgrade your OpenShift cluster to (can list multiple by separating with comma, no spaces).'
      )
      booleanParam(
        name: 'EUS_UPGRADE',
        defaultValue: false,
        description: '''This variable will perform an EUS type upgrade <br>
        See "https://docs.google.com/document/d/1396VAUFLmhj8ePt9NfJl0mfHD7pUT7ii30AO7jhDp0g/edit#heading=h.bv3v69eaalsw" for how to run'''
      )
      choice(
        choices: ['fast', 'eus', 'candidate', 'stable'], 
        name: 'EUS_CHANNEL',
        description: 'EUS Channel type, will be ignored if EUS_UPGRADE is not set to true'
      )

      booleanParam(
        name: 'ENABLE_FORCE', 
        defaultValue: true,
        description: 'This variable will force the upgrade or not'
      )
      booleanParam(
        name: 'SCALE', 
        defaultValue: false, 
        description: 'This variable will scale the cluster up one node at the end up the upgrade'
      )
      string(
        name: 'MAX_UNAVAILABLE',
        defaultValue: "1",
        description: 'This variable will set the max number of unavailable nodes during the upgrade'
      )

      separator(
        name: "GENERAL_BUILD_INFO",
        sectionHeader: "General Options",
        sectionHeaderStyle: """
        font-size: 18px;
        font-weight: bold;
        font-family: 'Orienta', sans-serif;"""
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
        name: 'DESTROY_WHEN_DONE', 
        defaultValue: 'False', 
        description: 'If you want to destroy the cluster created at the end of your run '
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
          e.g.<br>
          SOMEVAR1='env-test'<br>
          SOMEVAR2='env2-test'<br>
          ...<br>
          SOMEVARn='envn-test'<br>
          </p>'''
      )
      string(
        name: 'E2E_BENCHMARKING_REPO',
        defaultValue:'https://github.com/cloud-bulldozer/e2e-benchmarking',
        description:'You can change this to point to your fork if needed.'
      )
      string(
        name: 'E2E_BENCHMARKING_REPO_BRANCH',
        defaultValue:'master',
        description:'You can change this to point to a branch on your fork if needed.'
      )
      string(
        name: 'SVT_REPO',
        defaultValue:'https://github.com/openshift/svt',
        description:'''<p>
          Repository to get regression test scripts and artifacts.<br>
          You can change this to point to your fork if needed.
          </p>'''
      )
      string(
        name: 'SVT_REPO_BRANCH',
        defaultValue:'master',
        description:'You can change this to point to a branch on your fork if needed.'
      )
      string(
        name: "CI_PROFILES_URL",
        defaultValue: "https://gitlab.cee.redhat.com/aosqe/ci-profiles.git/",
        description:"Owner of ci-profiles repo to checkout, will look at folder 'scale-ci/\${major_v}.\${minor_v}'"
      )
      string(
        name: "CI_PROFILES_REPO_BRANCH",
        defaultValue: "master",
        description: "Branch of ci-profiles repo to checkout"
      )
    }

    stages{
        stage("Build Flexy Clusters") {
           agent { label params['JENKINS_AGENT_LABEL'] }
           steps {
                // checkout CI profile repo from GitLab
                checkout changelog: false,
                    poll: false,
                    scm: [
                        $class: 'GitSCM',
                        branches: [[name: "${params.CI_PROFILES_REPO_BRANCH}"]],
                        doGenerateSubmoduleConfigurations: false,
                        extensions: [
                            [$class: 'CloneOption', noTags: true, reference: '', shallow: true],
                            [$class: 'PruneStaleBranch'],
                            [$class: 'CleanCheckout'],
                            [$class: 'IgnoreNotifyCommit'],
                            [$class: 'RelativeTargetDirectory', relativeTargetDir: 'local-ci-profiles']
                        ],
                        submoduleCfg: [],
                        userRemoteConfigs: [[
                            name: 'origin',
                            refspec: "+refs/heads/${params.CI_PROFILES_REPO_BRANCH}:refs/remotes/origin/${params.CI_PROFILES_REPO_BRANCH}",
                            url: "${params.CI_PROFILES_URL}"
                        ]]
                    ]
                script{
                    def install_type_custom = params.INSTALL_TYPE
                    def custom_cloud_type = params.CLOUD_TYPE
                    def custom_jenkins_label = JENKINS_AGENT_LABEL
                    if (params.SCALE_UP.toInteger() > 0 ) {
                        global_scale_num = params.SCALE_UP.toInteger()
                    }
                    println "global num $global_scale_num"
                     if(params.BUILD_NUMBER == "") {

                        if(params.CI_PROFILE != "" ) {

                            // read data from CI profile install file
                            MAJOR_VERSION = params.OCP_VERSION.split("\\.")[0]
                            MINOR_VERSION = params.OCP_VERSION.split("\\.")[1]

                            installData = readYaml(file: "local-ci-profiles/scale-ci/$MAJOR_VERSION.$MINOR_VERSION/${CI_PROFILE}.install.yaml")
                            installData.install.flexy.each { env.setProperty(it.key, it.value) }
                            // loop through install data keys to make sure scale is one of them
                            def scale_profile_size = 0
                            for (data in installData) {
                                if (data.key == "scale" ) {
                                    scale_profile_size = data.value.get(PROFILE_SCALE_SIZE).SCALE_UP
                                    break
                                }
                            }
                            if (scale_profile_size != 0 && global_scale_num == 0 ) {
                                // get scale_up val from profile
                                global_scale_num = scale_profile_size
                                
                            }
                            println "scale up not null $global_scale_num"
                            currentBuild.description = """
                                <b>CI Profile:</b> ${params.CI_PROFILE} <br/>
                                <b>Profile Size:</b> ${params.PROFILE_SCALE_SIZE} <br/>
                            """

                        } else {
                            currentBuild.description = """
                                <b>Create Cluster: </b> ${params.INSTALL_TYPE} on ${params.CLOUD_TYPE}-${params.NETWORK_TYPE} <br/>
                            """
                        }
                        def set_arch_type = "x86_64"
                        if (params.ARCH_TYPE != "") {
                          set_arch_type = params.ARCH_TYPE
                        }
                        else if (params.CI_PROFILE != "" && params.CI_PROFILE.contains('ARM')) {
                          set_arch_type = "aarch64"
                        }
        

                        install = build job: 'scale-ci/e2e-benchmarking-multibranch-pipeline/cluster-builder/', parameters: [
                            text(name: "ENV_VARS", value: ENV_VARS),string(name: 'JENKINS_AGENT_LABEL', value: JENKINS_AGENT_LABEL),
                            string(name: 'CI_PROFILES_URL', value: CI_PROFILES_URL),string(name: 'CI_PROFILES_REPO_BRANCH', value: CI_PROFILES_REPO_BRANCH),
                            string(name: 'OCP_PREFIX', value: OCP_PREFIX),string(name: 'OCP_VERSION', value: OCP_VERSION),
                            string(name: 'CI_PROFILE', value: CI_PROFILE),string(name: 'PROFILE_SCALE_SIZE', value: PROFILE_SCALE_SIZE),
                            string( name: 'CLOUD_TYPE', value: CLOUD_TYPE),string(name: "ARCH_TYPE", value: set_arch_type),
                            string(name: 'NETWORK_TYPE', value: NETWORK_TYPE),string(name: 'INSTALL_TYPE', value: INSTALL_TYPE),
                            string(name: 'MASTER_COUNT', value: MASTER_COUNT),string(name: "WORKER_COUNT", value: WORKER_COUNT)
                        ]
                        def build_num = ""
                        if (install.description?.trim()) {
                            def description = readYaml(text: install.description)
                            if (description["FLEXY_BUILD_NUMBER"] != null) {
                              build_num = description["FLEXY_BUILD_NUMBER"]
                            }
                        }

                        if( install.result.toString() == "SUCCESS") {
                           status = "PASS"
                        }
                        build_string = build_num
                    } else {
                     copyArtifacts(
                        filter: '',
                        fingerprintArtifacts: true,
                        projectName: 'ocp-common/Flexy-install',
                        selector: specific(params.BUILD_NUMBER),
                        target: 'flexy-artifacts'
                       )
                       sh "echo 'ls flexy-artifacts/workdir/install-dir'"
                       if (fileExists("flexy-artifacts/workdir/install-dir/cluster_info.yaml")) {
                         println('cluster_info.yaml')
                          installData = readYaml(file: "flexy-artifacts/workdir/install-dir/cluster_info.yaml")
                          VERSION = installData.INSTALLER.VERSION
                          currentBuild.description = """
                              <b>Using Pre-Built Flexy</b> <br/>
                          """
                       } else if (fileExists("flexy-artifacts/workdir/install-dir/cluster_info.json")) {
                          installData = readJSON file: "flexy-artifacts/workdir/install-dir/cluster_info.json"
                          println "json version $installData"
                          VERSION = installData.INSTALLER.VERSION
                          currentBuild.description = """
                              <b>Using Pre-Built Flexy</b> <br/>
                          """
                        
                       } else {
                         println "unknown version"
                          VERSION = "Unknown Version"
                       }

                        if (params.BUILD_NUMBER != "") {
                            build_string = params.BUILD_NUMBER
                        }
                     }

                    currentBuild.description += """
                        <b>Version:</b> ${VERSION}<br/>
                        <b>Flexy-install Build:</b> ${build_string}<br/>
                    """
                 if ( build_string != "DEFAULT") {
                     copyArtifacts(
                        fingerprintArtifacts: true,
                        projectName: 'ocp-common/Flexy-install',
                        selector: specific(build_string),
                        filter: "workdir/install-dir/",
                        target: 'flexy-artifacts'
                       )
                    if (fileExists("flexy-artifacts/workdir/install-dir/client_proxy_setting.sh")) {
                     println "client proxy set"
                     proxy_settings = sh returnStdout: true, script: 'cat flexy-artifacts/workdir/install-dir/client_proxy_setting.sh'
                     proxy_settings = proxy_settings.replace('export ', '')
                    }

                    ENV_VARS += '\n' + proxy_settings
                    println "$ENV_VARS $global_scale_num"

                 }
               }
            }
        }
        stage("Scale Up Cluster") {
           agent { label params['JENKINS_AGENT_LABEL'] }
            when {
                expression { build_string != "DEFAULT" && status == "PASS" && (global_scale_num.toInteger() > 0 || params.INFRA_WORKLOAD_INSTALL == true)}
            }
           steps {
            script{

                scale_up = build job: 'scale-ci/e2e-benchmarking-multibranch-pipeline/cluster-workers-scaling/', parameters: [
                    string(name: 'BUILD_NUMBER', value: "${build_string}"), text(name: "ENV_VARS", value: ENV_VARS),
                    booleanParam(name: 'INFRA_WORKLOAD_INSTALL', value: INFRA_WORKLOAD_INSTALL),
                    string(name: 'WORKER_COUNT', value: global_scale_num.toString()), string(name: 'JENKINS_AGENT_LABEL', value: JENKINS_AGENT_LABEL)
                ]
                currentBuild.description += """
                    <b>Scaled Up:</b>  <a href="${scale_up.absoluteUrl}"> ${global_scale_num} </a><br/>
                """
                if( scale_up != null && scale_up.result.toString() != "SUCCESS") {
                   status = "Scale Up Failed"
                   currentBuild.result = "FAILURE"
                }
            }
          }
        }
        stage("Perf Testing"){
            agent { label params['JENKINS_AGENT_LABEL'] }
            when {
                expression { build_string != "DEFAULT" && status == "PASS" }
            }
            steps{
                script {
                  if( ["cluster-density","pod-density","node-density","node-density-heavy", "max-namespaces","max-services","concurrent-builds","pod-density-heavy"].contains(params.CI_TYPE) ) {
                    loaded_ci = build job: "scale-ci/e2e-benchmarking-multibranch-pipeline/kube-burner", propagate: false, parameters:[
                        string(name: "BUILD_NUMBER", value: "${build_string}"),string(name: "JENKINS_AGENT_LABEL", value: JENKINS_AGENT_LABEL),
                        string(name: "WORKLOAD", value: CI_TYPE),string(name: "VARIABLE", value: VARIABLE),string(name: 'NODE_COUNT', value: NODE_COUNT),
                        string(name: "BUILD_LIST", value: BUILD_LIST),string(name: 'APP_LIST', value: APP_LIST),
                        text(name: "ENV_VARS", value: ENV_VARS),booleanParam(name: "WRITE_TO_FILE", value: WRITE_TO_FILE),
                        booleanParam(name: "CERBERUS_CHECK", value: CERBERUS_CHECK),booleanParam(name: "CLEANUP", value: CLEANUP),
                        string(name: "E2E_BENCHMARKING_REPO", value: E2E_BENCHMARKING_REPO),
                        string(name: "E2E_BENCHMARKING_REPO_BRANCH", value: E2E_BENCHMARKING_REPO_BRANCH)
                    ]
                    currentBuild.description += """
                        <b>Scale-Ci: Kube-burner </b> ${CI_TYPE}- ${VARIABLE} <br/>
                        <b>Scale-CI Job: </b> <a href="${loaded_ci.absoluteUrl}"> ${loaded_ci.getNumber()} </a> <br/>
                    """
                   } else if (params.CI_TYPE == "etcd-perf") {
                       loaded_ci = build job: "scale-ci/e2e-benchmarking-multibranch-pipeline/etcd-perf", propagate: false, parameters:[
                            string(name: "BUILD_NUMBER", value: "${build_string}"),string(name: "JENKINS_AGENT_LABEL", value: JENKINS_AGENT_LABEL),
                            text(name: "ENV_VARS", value: ENV_VARS),string(name: "E2E_BENCHMARKING_REPO", value: E2E_BENCHMARKING_REPO),
                            booleanParam(name: "CERBERUS_CHECK", value: CERBERUS_CHECK),
                            string(name: "E2E_BENCHMARKING_REPO_BRANCH", value: E2E_BENCHMARKING_REPO_BRANCH),
                            booleanParam(name: "WRITE_TO_FILE", value: WRITE_TO_FILE)
                       ]
                       currentBuild.description += """
                            <b>Scale-Ci: </b> etcd-perf <br/>
                            <b>Scale-CI Job: </b> <a href="${loaded_ci.absoluteUrl}"> ${loaded_ci.getNumber()} </a> <br/>
                        """
                   } else if (params.CI_TYPE == "router-perf") {
                       loaded_ci = build job: "scale-ci/e2e-benchmarking-multibranch-pipeline/router-perf",propagate: false, parameters:[
                            string(name: "BUILD_NUMBER", value: "${build_string}"),string(name: "JENKINS_AGENT_LABEL", value: JENKINS_AGENT_LABEL),
                            text(name: "ENV_VARS", value: ENV_VARS),string(name: "E2E_BENCHMARKING_REPO", value: E2E_BENCHMARKING_REPO),
                            booleanParam(name: "CERBERUS_CHECK", value: CERBERUS_CHECK),
                            string(name: "E2E_BENCHMARKING_REPO_BRANCH", value: E2E_BENCHMARKING_REPO_BRANCH),
                            booleanParam(name: "WRITE_TO_FILE", value: WRITE_TO_FILE)
                       ]
                        currentBuild.description += """
                            <b>Scale-Ci: </b> router-perf <br/>
                            <b>Scale-CI Job: </b> <a href="${loaded_ci.absoluteUrl}"> ${loaded_ci.getNumber()} </a> <br/>
                        """
                   }else if ( ["network-perf-pod-network-test","network-perf-serviceip-network-test","network-perf-hostnetwork-network-test"].contains(params.CI_TYPE) ) {
                       loaded_ci = build job: "scale-ci/e2e-benchmarking-multibranch-pipeline/network-perf", propagate: false, parameters:[
                            string(name: "BUILD_NUMBER", value: "${build_string}"),string(name: "JENKINS_AGENT_LABEL", value: JENKINS_AGENT_LABEL),
                            string(name: "WORKLOAD_TYPE", value: WORKLOAD_TYPE),booleanParam(name: "NETWORK_POLICY", value: NETWORK_POLICY),
                            booleanParam(name: "CERBERUS_CHECK", value: CERBERUS_CHECK),
                            text(name: "ENV_VARS", value: ENV_VARS),string(name: "E2E_BENCHMARKING_REPO", value: E2E_BENCHMARKING_REPO),
                            string(name: "E2E_BENCHMARKING_REPO_BRANCH", value: E2E_BENCHMARKING_REPO_BRANCH),
                            booleanParam(name: "WRITE_TO_FILE", value: WRITE_TO_FILE)
                         ]
                       currentBuild.description += """
                            <b>Scale-Ci: Network Perf </b> ${WORKLOAD_TYPE} ${NETWORK_POLICY} <br/>
                            <b>Scale-CI Job: </b> <a href="${loaded_ci.absoluteUrl}"> ${loaded_ci.getNumber()} </a> <br/>
                       """
                    } else if (params.CI_TYPE == "regression-test") {
                       loaded_ci = build job: "scale-ci/e2e-benchmarking-multibranch-pipeline/regression-test",propagate: false, parameters:[
                            string(name: "BUILD_NUMBER", value: "${build_string}"),string(name: "JENKINS_AGENT_LABEL", value: JENKINS_AGENT_LABEL),
                            text(name: "ENV_VARS", value: ENV_VARS),string(name: "SVT_REPO", value: SVT_REPO),
                            string(name: "SVT_REPO_BRANCH", value: SVT_REPO_BRANCH),string(name: "PARAMETERS", value: VARIABLE),
                            string(name: "SCRIPT", value: SCRIPT),string(name: "TEST_CASE", value: TEST_CASE),
                            booleanParam(name: "CLEANUP", value: CLEANUP),booleanParam(name: "CERBERUS_CHECK", value: CERBERUS_CHECK),
                       ]
                        currentBuild.description += """
                            <b>Scale-Ci: </b> regression-test <br/>
                            <b>Scale-CI Job: </b> <a href="${loaded_ci.absoluteUrl}"> ${loaded_ci.getNumber()} </a> <br/>
                        """
                   }else{
                        println "No Scale-ci Job"
                        currentBuild.description += """
                            <b>No Scale-Ci Run</b><br/>
                        """
                    }

                    if( loaded_ci != null ) {
                      if( loaded_ci.result.toString() != "SUCCESS") {
                           status = "Scale CI Job Failed"
                           currentBuild.result = "FAILURE"
                        }
                    }

                }
            }
        }
        stage('Upgrade'){
            agent { label params['JENKINS_AGENT_LABEL'] }
            when {
                expression { build_string != "DEFAULT" && status == "PASS" && UPGRADE_VERSION != ""  }
            }
            steps{
                script{
                    currentBuild.description += """
                        <b>Upgrade to: </b> ${UPGRADE_VERSION} <br/>
                    """
                    upgrade_ci = build job: "scale-ci/e2e-benchmarking-multibranch-pipeline/upgrade", propagate: false,parameters:[
                        string(name: "BUILD_NUMBER", value: build_string),string(name: "MAX_UNAVAILABLE", value: MAX_UNAVAILABLE),
                        string(name: "JENKINS_AGENT_LABEL", value: JENKINS_AGENT_LABEL),string(name: "UPGRADE_VERSION", value: UPGRADE_VERSION),
                        booleanParam(name: "EUS_UPGRADE", value: EUS_UPGRADE),string(name: "EUS_CHANNEL", value: EUS_CHANNEL),
                        booleanParam(name: "WRITE_TO_FILE", value: WRITE_TO_FILE),booleanParam(name: "ENABLE_FORCE", value: ENABLE_FORCE),
                        booleanParam(name: "SCALE", value: SCALE),text(name: "ENV_VARS", value: ENV_VARS)
                    ]
                    currentBuild.description += """
                        <b>Upgrade Job: </b> <a href="${upgrade_ci.absoluteUrl}"> ${upgrade_ci.getNumber()} </a> <br/>
                    """
                    if( upgrade_ci.result.toString() != "SUCCESS") {
                       status = "Upgrade Failed"
                       currentBuild.result = "FAILURE"
                    }
                }
            }
        }

        stage("Write out results") {
            agent { label params['JENKINS_AGENT_LABEL'] }
            when {
                expression { params.WRITE_TO_FILE == true }
            }
            steps{
                script{
                    println "write to file $loaded_ci "

                    if(loaded_ci != null ) {
                        loaded_url = loaded_ci.absoluteUrl
                    }
                    if(upgrade_ci != null ) {
                        upgrade_url = upgrade_ci.absoluteUrl
                    }
                    if ( must_gather != null ) {
                        must_gather_url = must_gather.absoluteUrl
                    }
                    build job: 'scale-ci/e2e-benchmarking-multibranch-pipeline/write-scale-ci-results', parameters: [
                        string(name: "JENKINS_AGENT_LABEL", value: JENKINS_AGENT_LABEL),string(name: "BUILD_NUMBER", value: build_string),
                        string(name: 'CI_STATUS', value: "${status}"), string(name: 'UPGRADE_JOB_URL', value: upgrade_url),text(name: "ENV_VARS", value: ENV_VARS),
                        string(name: 'CI_JOB_URL', value: loaded_url), booleanParam(name: 'ENABLE_FORCE', value: ENABLE_FORCE),booleanParam(name: 'SCALE', value: SCALE),
                        string(name: 'LOADED_JOB_URL', value: BUILD_URL), string(name: 'JOB', value: "loaded-upgrade")
                    ], propagate: false

                }
              }
        }
        stage('Destroy Flexy Cluster'){
            agent { label params['JENKINS_AGENT_LABEL'] }
            steps{
                script{
                    if(install != null && (install.result.toString() != "SUCCESS" || params.DESTROY_WHEN_DONE == true)) {
                        destroy_ci = build job: 'ocp-common/Flexy-destroy', parameters: [
                            string(name: "BUILD_NUMBER", value: build_string),string(name: "JENKINS_AGENT_LABEL", value: JENKINS_AGENT_LABEL)
                        ]
                    } else if(install == null && params.DESTROY_WHEN_DONE == true) {
                        destroy_ci = build job: 'ocp-common/Flexy-destroy', parameters: [
                            string(name: "BUILD_NUMBER", value: build_string),string(name: "JENKINS_AGENT_LABEL", value: JENKINS_AGENT_LABEL)
                        ]
                    }

                    if( destroy_ci != null) {
                        println "destroy not null"
                        if( destroy_ci.result.toString() != "SUCCESS") {
                            println "destroy failed"
                            currentBuild.result = "FAILURE"
                            status = "Destroy Failed"
                        }
                    }
                }
            }
        }
    }
    post {
        always {
            script {
                currentBuild.description += """
                    <b>Final Status:</b> ${status}<br/>
                """
            }
        }
    }
}