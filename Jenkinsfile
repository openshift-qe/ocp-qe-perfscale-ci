
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


def userId = currentBuild.rawBuild.getCause(hudson.model.Cause$UserIdCause)?.userId
if (userId) {
  currentBuild.displayName = "${userId}-${currentBuild.displayName}"
}

pipeline{
    agent any

    parameters {
        separator(name: "PRE_BUILT_FLEXY_ENV", sectionHeader: "Pre Built Flexy", sectionHeaderStyle: """
				font-size: 18px;
				font-weight: bold;
				font-family: 'Orienta', sans-serif;
			""")
        string(name: 'BUILD_NUMBER', defaultValue: '', description: 'Build number of job that has installed the cluster.')

        separator(name: "BUILD_FLEXY", sectionHeader: "Build Flexy Parameters", sectionHeaderStyle: """
				font-size: 18px;
				font-weight: bold;
				font-family: 'Orienta', sans-serif;
			""")
        string(name: 'OCP_PREFIX', defaultValue: '', description: 'Name of ocp cluster you want to build')
        string(name: 'OCP_VERSION', defaultValue: '', description: 'Build version to install the cluster.')
        choice(choices: ['','aws', 'azure', 'gcp', 'osp', 'alicloud', 'ibmcloud', 'vsphere', 'ash'], name: 'CLOUD_TYPE', description: '''Cloud type (As seen on https://gitlab.cee.redhat.com/aosqe/flexy-templates/-/tree/master/functionality-testing/aos-4_9, after ""-on-") <br/>
        Will be ignored if BUILD_NUMBER is set''')
        choice(choices: ['','ovn', 'sdn'], name: 'NETWORK_TYPE', description: 'Network type, will be ignored if BUILD_NUMBER is set')
        choice(choices: ['','ipi', 'upi', 'sno'], name: 'INSTALL_TYPE', description: '''Type of installation (set to SNO for sno cluster type),  <br/>
        will be ignored if BUILD_NUMBER is set''')
        string(name: 'MASTER_COUNT', defaultValue: '3', description: 'Number of master nodes in your cluster to create.')
        string(name: "WORKER_COUNT", defaultValue: '3', description: 'Number of worker nodes in your cluster to create.')

        separator(name: "SCALE_UP_JOB_INFO", sectionHeader: "Scale Up Job Options", sectionHeaderStyle: """
				font-size: 18px;
				font-weight: bold;
				font-family: 'Orienta', sans-serif;
			""")

        string(name: 'SCALE_UP', defaultValue: '0', description: 'If value is set to anything greater than 0, cluster will be scaled up before executing the workload.')
        string(name: 'SCALE_DOWN', defaultValue: '0', description:
        '''If value is set to anything greater than 0, cluster will be scaled down after the execution of the workload is complete,<br>
        if the build fails, scale down may not happen, user should review and decide if cluster is ready for scale down or re-run the job on same cluster.'''
        )
        separator(name: "SCALE_CI_JOB_INFO", sectionHeader: "Scale-CI Job Options", sectionHeaderStyle: """
				font-size: 18px;
				font-weight: bold;
				font-family: 'Orienta', sans-serif;
			""")
        choice(choices: ["","cluster-density","pod-density","node-density","node-density-heavy","etcd-perf","max-namespaces","max-services","pod-network-policy-test","router-perf","network-perf-hostnetwork-network-test","network-perf-pod-network-test","network-perf-serviceip-network-test"], name: 'CI_TYPE', description: '''Type of scale-ci job to run. Can be left blank to not run ci job <br>
        Router-perf tests will use all defaults if selected, all parameters in this section below will be ignored ''')


        string(name: 'VARIABLE', defaultValue: '1000', description: '''
        This variable configures parameter needed for each type of workload. By default 1000. <br>
        pod-density: This will export PODS env variable; set to 200 * num_workers, work up to 250 * num_workers. Creates as many "sleep" pods as configured in this environment variable. <br>
        cluster-density: This will export JOB_ITERATIONS env variable; set to 4 * num_workers. This variable sets the number of iterations to perform (1 namespace per iteration). <br>
        max-namespaces: This will export NAMESPACE_COUNT env variable; set to ~30 * num_workers. The number of namespaces created by Kube-burner. <br>
        max-services: This will export SERVICE_COUNT env variable; set to 200 * num_workers, work up to 250 * num_workers. Creates n-replicas of an application deployment (hello-openshift) and a service in a single namespace. <br>
        node-density: This will export PODS_PER_NODE env variable; set to 200, work up to 250. Creates as many "sleep" pods as configured in this variable - existing number of pods on node. <br>
        node-density-heavy: This will export PODS_PER_NODE env variable; set to 200, work up to 250. Creates this number of applications proportional to the calculated number of pods / 2 <br>
        Read here for detail of each variable: <br>
        https://github.com/cloud-bulldozer/e2e-benchmarking/blob/master/workloads/kube-burner/README.md <br>
        ''')

        separator(name: "NODE_DENSITY_JOB_INFO", sectionHeader: "Node Density Job Options", sectionHeaderStyle: """
				font-size: 14px;
				font-weight: bold;
				font-family: 'Orienta', sans-serif;
			""")
        string(name: 'NODE_COUNT', defaultValue: '3', description: 'Number of worker nodes to be used in your cluster for this workload.')

        separator(name: "NETWORK_PERF_INFO", sectionHeader: "Node Density Job Options", sectionHeaderStyle: """
				font-size: 14px;
				font-weight: bold;
				font-family: 'Orienta', sans-serif;
			""")
        choice(choices: ['smoke', 'pod2pod', 'hostnet', 'pod2svc'], name: 'WORKLOAD_TYPE', description: 'Workload type')
        booleanParam(name: "NETWORK_POLICY", defaultValue: false, description: "If enabled, benchmark-operator will create a network policy to allow ingress trafic in uperf server pods")

        separator(name: "UPGRADE_INFO", sectionHeader: "Upgrade Options", sectionHeaderStyle: """
				font-size: 18px;
				font-weight: bold;
				font-family: 'Orienta', sans-serif;
			""")
        string(name: 'UPGRADE_VERSION', description: 'This variable sets the version number you want to upgrade your OpenShift cluster to (can list multiple by separating with comma, no spaces).')
        booleanParam(name: 'EUS_UPGRADE', defaultValue: false, description: '''This variable will perform an EUS type upgrade <br>
        See "https://docs.google.com/document/d/1396VAUFLmhj8ePt9NfJl0mfHD7pUT7ii30AO7jhDp0g/edit#heading=h.bv3v69eaalsw" for how to run
        ''')
        choice(choices: ['fast', 'eus', 'candidate', 'stable'], name: 'EUS_CHANNEL', description: 'EUS Channel type, will be ignored if EUS_UPGRADE is not set to true')

        booleanParam(name: 'ENABLE_FORCE', defaultValue: true, description: 'This variable will force the upgrade or not')
        booleanParam(name: 'SCALE', defaultValue: false, description: 'This variable will scale the cluster up one node at the end up the upgrade')
        string(name: 'MAX_UNAVAILABLE', defaultValue: "1", description: 'This variable will set the max number of unavailable nodes during the upgrade')

        separator(name: "GENERAL_BUILD_INFO", sectionHeader: "General Options", sectionHeaderStyle: """
				font-size: 18px;
				font-weight: bold;
				font-family: 'Orienta', sans-serif;
			""")

        booleanParam(name: 'WRITE_TO_FILE', defaultValue: true, description: 'Value to write to google sheet (will run https://mastern-jenkins-csb-openshift-qe.apps.ocp4.prod.psi.redhat.com/job/scale-ci/job/paige-e2e-multibranch/job/write-to_sheet)')
        booleanParam(name: 'DESTROY_WHEN_DONE', defaultValue: 'False', description: 'If you want to destroy the cluster created at the end of your run ')
        string(name:'JENKINS_AGENT_LABEL',defaultValue:'oc45',description:
        '''
        scale-ci-static: for static agent that is specific to scale-ci, useful when the jenkins dynamic agent isn't stable<br>
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
        string(name: 'E2E_BENCHMARKING_REPO', defaultValue:'https://github.com/cloud-bulldozer/e2e-benchmarking', description:'You can change this to point to your fork if needed.')
        string(name: 'E2E_BENCHMARKING_REPO_BRANCH', defaultValue:'master', description:'You can change this to point to a branch on your fork if needed.')
    }


    stages{
        stage("Build Flexy Clusters") {
           agent { label params['JENKINS_AGENT_LABEL'] }
           steps {
                script{
                    def install_type_custom = params.INSTALL_TYPE
                    def custom_cloud_type = params.CLOUD_TYPE
                    def custom_jenkins_label = JENKINS_AGENT_LABEL
                     if(params.BUILD_NUMBER == "") {
                         def network_ending = ""
                          if (params.CLOUD_TYPE == "vsphere") {
                                network_ending = "-vmc7"
                          }
                           if (params.NETWORK_TYPE != "sdn") {
                            if (params.CLOUD_TYPE == "alicloud") {
                                network_ending = "-fips-${params.NETWORK_TYPE}-ci"
                            } else if (params.CLOUD_TYPE != "ash" ) {
                                network_ending += "-${params.NETWORK_TYPE}"
                            }
                           }
                            def worker_type = ""
                            if (params.CLOUD_TYPE == "aws") {
                                if (params.INSTALL_TYPE == "sno") {
                                    worker_type = "master_worker_AllInOne: 'true', num_masters: 1, num_workers: 0, vm_type: 'm5.4xlarge', "
                                    install_type_custom = "ipi"
                                } else {
                                worker_type = "vm_type_workers: 'm5.xlarge', num_workers: " + WORKER_COUNT + ", num_masters: " + MASTER_COUNT + ","
                                }
                            }
                            else if (params.CLOUD_TYPE == "azure") {
                                worker_type = "vm_type_workers: 'Standard_D8s_v3', region: centralus, num_workers: " + WORKER_COUNT + ", num_masters: " + MASTER_COUNT + ","
                            }
                            else if (params.CLOUD_TYPE == "gcp") {
                                worker_type = "vm_type_workers: 'n1-standard-4', num_workers: " + WORKER_COUNT + ", num_masters: " + MASTER_COUNT + ","
                                if (params.NETWORK_TYPE != "sdn") {
                                 network_ending = network_ending + "-ci"
                                }
                            }
                            else if (params.CLOUD_TYPE == "osp") {
                                worker_type = "vm_type_workers: 'ci.m1.xlarge', num_workers: " + WORKER_COUNT + ", num_masters: " + MASTER_COUNT + ","
                            }
                            else if (params.CLOUD_TYPE == "alicloud") {

                                worker_type = "vm_type_workers: 'ecs.g6.xlarge', num_workers: " + WORKER_COUNT + ", num_masters: " + MASTER_COUNT + ","
                            }
                            else if (params.CLOUD_TYPE == "ibmcloud") {
                                worker_type = "vm_type_workers: 'bx2d-4x16', region: 'jp-tok', num_workers: " + WORKER_COUNT + ", num_masters: " + MASTER_COUNT + ","
                            }
                            else if (params.CLOUD_TYPE == "vsphere") {
                                worker_type = " num_workers: " + WORKER_COUNT + ", num_masters: " + MASTER_COUNT + ","
                            } else if (params.CLOUD_TYPE == "ash") {
                                custom_cloud_type = "azure"
                                worker_type = " num_workers: " + WORKER_COUNT + ", num_masters: " + MASTER_COUNT + ","
                                if (params.NETWORK_TYPE != "sdn") {
                                worker_type += 'networkType: "OVNKubernetes", '
                                }
                                network_ending = "-ash_wwt"
                                custom_jenkins_label = "fedora-installer-wwt"
                            }

                            def version = params.OCP_VERSION
                            sh "echo ${version}"
                            def version_list = version.tokenize(".")
                            sh "echo version ${version_list}"
                            def major_v = version_list[0]
                            def minor_v = version_list[1]
                            sh "echo minor ${minor_v} major ${major_v}"
                            def var_loc = "private-templates/functionality-testing/aos-${major_v}_${minor_v}/${install_type_custom}-on-${custom_cloud_type}/versioned-installer${network_ending}"
                            sh "echo var ${var_loc}"
                            install = build job:"ocp-common/Flexy-install", propagate: false, parameters:[string(name: "INSTANCE_NAME_PREFIX", value: OCP_PREFIX),string(name: "VARIABLES_LOCATION", value: "${var_loc}"),string(name: "JENKINS_AGENT_LABEL", value: custom_jenkins_label),text(name: "LAUNCHER_VARS",
                            value: "{ ${worker_type} installer_payload_image: 'registry.ci.openshift.org/ocp/release:${params.OCP_VERSION}'}"),text(name: "BUSHSLICER_CONFIG", value: ''),text(name: 'REPOSITORIES', value: '''
GIT_PRIVATE_URI=git@gitlab.cee.redhat.com:aosqe/cucushift-internal.git
GIT_PRIVATE_TEMPLATES_URI=https://gitlab.cee.redhat.com/aosqe/flexy-templates.git'''),
text(name: 'CREDENTIALS', value: '''
DYNECT_CREDENTIALS=b1666c61-4a76-40b7-950f-a3d40f721e59
REG_STAGE=41c2dd39-aad7-4f07-afec-efc052b450f5
REG_QUAY=c1802784-0f74-4b35-99fb-32dfa9a207ad
REG_CLOUD=fba37700-62f8-4883-8905-53f86461ba5b
REG_CONNECT=819c9e9f-1e9c-4d2b-9dc0-fc630674bc9b
REG_REDHAT=819c9e9f-1e9c-4d2b-9dc0-fc630674bc9b
REG_BREW_OSBS=brew-registry-osbs-mirror
REG_NIGHTLY_BUILDS=9a9187c6-a54c-452a-866f-bea36caea6f9
REG_CI_BUILDS=registry.ci.openshift.org
GIT_FLEXY_SSH_KEY=e2f7029f-ab8d-4987-8950-39feb80d5fbd
GIT_PRIVATE_SSH_KEY=1d2207b6-15c0-4cb0-913a-637788d12257
REG_SVC_CI=9a9187c6-a54c-452a-866f-bea36caea6f9''' ) ]

                        if( install.result.toString()  != "SUCCESS") {
                           sh 'echo "build failed"'
                           currentBuild.result = "FAILURE"
                           status = "Install failed"
                        }
                    } else {
                     copyArtifacts(
                        filter: '',
                        fingerprintArtifacts: true,
                        projectName: 'ocp-common/Flexy-install',
                        selector: specific(params.BUILD_NUMBER),
                        target: 'flexy-artifacts'
                       )
                     }

                    if (params.BUILD_NUMBER != "") {
                            build_string = params.BUILD_NUMBER
                    } else if( install.result.toString() == "SUCCESS" ) {
                            build_string = install.number.toString()
                    }
                 if ( build_string != "DEFAULT") {
                     copyArtifacts(
                        fingerprintArtifacts: true,
                        projectName: 'ocp-common/Flexy-install',
                        selector: specific(build_string),
                        filter: "workdir/install-dir/",
                        target: 'flexy-artifacts'
                       )
                    if (fileExists("flexy-artifacts/workdir/install-dir/client_proxy_setting.sh")) {
                     sh "echo yes"
                     proxy_settings = sh returnStdout: true, script: 'cat flexy-artifacts/workdir/install-dir/client_proxy_setting.sh'
                     proxy_settings = proxy_settings.replace('export ', '')
                    }

                    ENV_VARS += '\n' + proxy_settings
                    sh "echo $ENV_VARS"
                 }
               }
            }
        }
        stage("Scale Up Cluster") {
           agent { label params['JENKINS_AGENT_LABEL'] }
           steps {
            script{
             if( build_string != "DEFAULT" && status == "PASS") {
              if(params.SCALE_UP.toInteger() > 0) {
                scale_up = build job: 'scale-ci/e2e-benchmarking-multibranch-pipeline/cluster-workers-scaling/', parameters: [string(name: 'BUILD_NUMBER', value: BUILD_NUMBER), text(name: "ENV_VARS", value: ENV_VARS), string(name: 'WORKER_COUNT', value: SCALE_UP), string(name: 'JENKINS_AGENT_LABEL', value: JENKINS_AGENT_LABEL)]

                if( scale_up != null && scale_up.result.toString() != "SUCCESS") {
                   status = "Scale Up Failed"
                   currentBuild.result = "FAILURE"
                }
               }
              } else {
                sh 'echo "Installation of cluster failed, not running scale-up job"'
              }
            }
           }
        }
        stage("Perf Testing"){
            agent { label params['JENKINS_AGENT_LABEL'] }
            steps{
                script {
                    if( build_string != "DEFAULT" && status == "PASS") {
                   if( ["cluster-density","pod-density","node-density","node-density-heavy", "max-namespaces","max-services","pod-density-heavy"].contains(params.CI_TYPE) ) {
                        loaded_ci = build job: "scale-ci/e2e-benchmarking-multibranch-pipeline/kube-burner", propagate: false, parameters:[string(name: "BUILD_NUMBER", value: "${build_string}"),string(name: "JENKINS_AGENT_LABEL", value: JENKINS_AGENT_LABEL),string(name: "WORKLOAD", value: CI_TYPE),string(name: "VARIABLE", value: VARIABLE),string(name: 'NODE_COUNT', value: NODE_COUNT),text(name: "ENV_VARS", value: ENV_VARS),booleanParam(name: "WRITE_TO_FILE", value: WRITE_TO_FILE),string(name: "E2E_BENCHMARKING_REPO", value: E2E_BENCHMARKING_REPO),string(name: "E2E_BENCHMARKING_REPO_BRANCH", value: E2E_BENCHMARKING_REPO_BRANCH)]
                       } else if (params.CI_TYPE == "etcd-perf") {
                       loaded_ci = build job: "scale-ci/e2e-benchmarking-multibranch-pipeline/etcd-perf", propagate: false, parameters:[string(name: "BUILD_NUMBER", value: "${build_string}"),string(name: "JENKINS_AGENT_LABEL", value: JENKINS_AGENT_LABEL),text(name: "ENV_VARS", value: ENV_VARS),string(name: "E2E_BENCHMARKING_REPO", value: E2E_BENCHMARKING_REPO),string(name: "E2E_BENCHMARKING_REPO_BRANCH", value: E2E_BENCHMARKING_REPO_BRANCH),booleanParam(name: "WRITE_TO_FILE", value: WRITE_TO_FILE)]
                       } else if (params.CI_TYPE == "router-perf") {
                       loaded_ci = build job: "scale-ci/e2e-benchmarking-multibranch-pipeline/router-perf",propagate: false, parameters:[string(name: "BUILD_NUMBER", value: "${build_string}"),string(name: "JENKINS_AGENT_LABEL", value: JENKINS_AGENT_LABEL),text(name: "ENV_VARS", value: ENV_VARS),string(name: "E2E_BENCHMARKING_REPO", value: E2E_BENCHMARKING_REPO),string(name: "E2E_BENCHMARKING_REPO_BRANCH", value: E2E_BENCHMARKING_REPO_BRANCH),booleanParam(name: "WRITE_TO_FILE", value: WRITE_TO_FILE)]
                       }else if ( ["network-perf-pod-network-test","network-perf-serviceip-network-test","network-perf-hostnetwork-network-test"].contains(params.CI_TYPE) ) {
                       loaded_ci = build job: "scale-ci/paige-e2e-multibranch/network-perf", propagate: false, parameters:[string(name: "BUILD_NUMBER", value: "${build_string}"),string(name: "JENKINS_AGENT_LABEL", value: JENKINS_AGENT_LABEL),string(name: "WORKLOAD_TYPE", value: WORKLOAD_TYPE),booleanParam(name: "NETWORK_POLICY", value: NETWORK_POLICY),text(name: "ENV_VARS", value: ENV_VARS),string(name: "E2E_BENCHMARKING_REPO", value: E2E_BENCHMARKING_REPO),string(name: "E2E_BENCHMARKING_REPO_BRANCH", value: E2E_BENCHMARKING_REPO_BRANCH),booleanParam(name: "WRITE_TO_FILE", value: WRITE_TO_FILE)]
                        }else{
                        sh 'echo "No Scale-ci Job"'
                       }

                        if( loaded_ci != null ) {
                          load_result = loaded_ci.result.toString()
                          if( scale_up.result.toString() != "SUCCESS") {
                               status = "Scale Up Failed"
                               currentBuild.result = "FAILURE"
                            }
                        }
                      } else{
                        sh 'echo "Earlier job failed"'
                       }
                    }
            }
        }
        stage('Upgrade'){
            agent { label params['JENKINS_AGENT_LABEL'] }
            steps{
                script{
                    if( build_string != "DEFAULT" ) {
                        if( status == "PASS" ) {
                            if( UPGRADE_VERSION != "" ) {
                                upgrade_ci = build job: "scale-ci/e2e-benchmarking-multibranch-pipeline/upgrade", propagate: false,parameters:[string(name: "BUILD_NUMBER", value: build_string),string(name: "MAX_UNAVAILABLE", value: MAX_UNAVAILABLE),string(name: "JENKINS_AGENT_LABEL", value: JENKINS_AGENT_LABEL),string(name: "UPGRADE_VERSION", value: UPGRADE_VERSION),booleanParam(name: "EUS_UPGRADE", value: EUS_UPGRADE),string(name: "EUS_CHANNEL", value: EUS_CHANNEL),booleanParam(name: "WRITE_TO_FILE", value: WRITE_TO_FILE),booleanParam(name: "ENABLE_FORCE", value: ENABLE_FORCE),booleanParam(name: "SCALE", value: SCALE),text(name: "ENV_VARS", value: ENV_VARS)]
                                if( upgrade_ci.result.toString() != "SUCCESS") {
                                   status = "Upgrade Failed"
                                   currentBuild.result = "FAILURE"
                                }
                            } else {
                                sh 'echo "No upgrade version set, not running upgrade"'
                            }
                        } else{
                            sh 'echo "One of the previous jobs failed, not running upgrade"'
                           }
                    } else {
                        sh 'echo "Installation of cluster failed, not running upgrade"'
                    }
                }
            }
        }

        stage("Write out results") {
            agent { label params['JENKINS_AGENT_LABEL'] }
            steps{
                script{
                  if(params.WRITE_TO_FILE == true) {
                     sh "echo write to file $loaded_ci "

                    if(loaded_ci != null ) {
                        loaded_url = loaded_ci.absoluteUrl
                    }
                    if(upgrade_ci != null ) {
                        upgrade_url = upgrade_ci.absoluteUrl
                    }
                    if ( must_gather != null ) {
                        must_gather_url = must_gather.absoluteUrl
                    }
                    build job: 'scale-ci/paige-e2e-multibranch/write-scale-ci-results', propagate: false,parameters: [string(name: "JENKINS_AGENT_LABEL", value: JENKINS_AGENT_LABEL), string(name: "BUILD_NUMBER", value: build_string), string(name: 'CI_STATUS', value: "${status}"), string(name: 'UPGRADE_JOB_URL', value: upgrade_url),
                        text(name: "ENV_VARS", value: ENV_VARS), string(name: 'CI_JOB_URL', value: loaded_url), booleanParam(name: 'ENABLE_FORCE', value: ENABLE_FORCE), booleanParam(name: 'SCALE', value: SCALE), string(name: 'LOADED_JOB_URL', value: BUILD_URL), string(name: 'JOB', value: "loaded-upgrade"), , string(name: 'MUST_GATHER_URL', value: must_gather_url)]
                    }

                }
              }
        }
        stage('Destroy Flexy Cluster'){
            agent { label params['JENKINS_AGENT_LABEL'] }
            steps{
                script{
                    if(install != null && (install.result.toString() != "SUCCESS" || params.DESTROY_WHEN_DONE == true)) {
                        destroy_ci = build job: 'ocp-common/Flexy-destroy', parameters: [string(name: "BUILD_NUMBER", value: install.number.toString()),string(name: "JENKINS_AGENT_LABEL", value: JENKINS_AGENT_LABEL)]
                    } else if(install == null && params.DESTROY_WHEN_DONE == true) {
                        destroy_ci = build job: 'ocp-common/Flexy-destroy', parameters: [string(name: "BUILD_NUMBER", value: build_string),string(name: "JENKINS_AGENT_LABEL", value: JENKINS_AGENT_LABEL)]
                    }

                    if( destroy_ci != null) {
                        sh 'echo "destroy not null"'
                        if( destroy_ci.result.toString() != "SUCCESS") {
                            sh 'echo "destroy failed"'
                            currentBuild.result = "FAILURE"
                        }
                    }
                }
            }
        }
    }
}
