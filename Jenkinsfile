@Library('flexy') _

// rename build
def userId = currentBuild.rawBuild.getCause(hudson.model.Cause$UserIdCause)?.userId
if (userId) {
    currentBuild.displayName = userId
}

pipeline {
    agent { label params.JENKINS_AGENT_LABEL }

    options {
        timeout(time: 1, unit: 'HOURS')
    }

    parameters {
        string(
            name: 'JENKINS_AGENT_LABEL',
            defaultValue:'oc411',
            description: 'Label of Jenkins agent to execute job'
        )
        string(
            name: 'FLEXY_BUILD_NUMBER',
            defaultValue: '',
            description: 'Build number of Flexy job that installed the cluster'
        )
        separator(
            name: 'CLUSTER_CONFIG_OPTIONS',
            sectionHeader: 'OpenShift Cluster Configuration Options',
            sectionHeaderStyle: '''
                font-size: 14px;
                font-weight: bold;
                font-family: 'Orienta', sans-serif;
            '''
        )
        string(
            name: 'WORKER_COUNT',
            defaultValue: '0',
            description: '''
                Total Worker count desired to scale the cluster to<br/>
                If set to '0' no scaling will occur<br/>
                You can also directly scale the cluster up (or down) yourself with <a href=https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/job/scale-ci/job/e2e-benchmarking-multibranch-pipeline/job/cluster-workers-scaling/>this job</a>
            '''
        )
        booleanParam(
            name: 'INFRA_WORKLOAD_INSTALL',
            defaultValue: false,
            description: 'Install workload and infrastructure nodes even if less than 50 nodes'
        )
        booleanParam(
            name: 'INSTALL_DITTYBOPPER',
            defaultValue: true,
            description: 'Value to install dittybopper dashboards to cluster'
        )
        string(
            name: 'DITTYBOPPER_REPO',
            defaultValue: 'https://github.com/cloud-bulldozer/performance-dashboards.git',
            description: 'You can change this to point to your fork if needed'
        )
        string(
            name: 'DITTYBOPPER_REPO_BRANCH',
            defaultValue: 'master',
            description: 'You can change this to point to a branch on your fork if needed'
        )
        separator(
            name: 'NETOBSERV_CONFIG_OPTIONS',
            sectionHeader: 'Network Observability Configuration Options',
            sectionHeaderStyle: '''
                font-size: 14px;
                font-weight: bold;
                font-family: 'Orienta', sans-serif;
            '''
        )
        choice(
            name: 'INSTALLATION_SOURCE',
            choices: ['OperatorHub', 'Source', 'None'],
            description: '''
                Network Observability can be installed either from OperatorHub or directly from the main branch of the Source code<br/>
                If None is selected the installation will be skipped
            '''
        )
        choice(
            name: 'LOKISTACK_SIZE',
            choices: ['1x.extra-small', '1x.small', '1x.medium'],
            description: '''
                Depending on size of cluster nodes, use following guidance to choose LokiStack size:<br/>
                1x.extra-small - Nodes size < m5.4xlarge<br/>
                1x.small - Nodes size >= m5.4xlarge<br/>
                1x.medium - Nodes size >= m5.8xlarge<br/>
            '''
        )
        booleanParam(
            name: 'ENABLE_KAFKA',
            defaultValue: false,
            description: 'Check this box to setup Kafka for NetObserv'
        )
        booleanParam(
            name: 'USER_WORKLOADS',
            defaultValue: true,
            description: 'Check this box to setup FLP service and create service-monitor'
        )
        string(
            name: 'FLOW_SAMPLING_RATE',
            defaultValue: '100',
            description: 'Rate at which to sample flows'
        )
        string(
            name: 'CPU_LIMIT',
            defaultValue: '1000m',
            description: 'Note that 1000m = 1000 millicores, i.e. 1 core'
        )
        string(
            name: 'MEMORY_LIMIT',
            defaultValue: '500Mi',
            description: 'Note that 500Mi = 500 megabytes, i.e. 0.5 GB'
        )
        string(
            name: 'REPLICAS',
            defaultValue: '1',
            description: 'Number of FLP replica pods'
        )
    }

    stages {
        stage('Validate job parameters') {
            steps {
                script {
                    if (params.FLEXY_BUILD_NUMBER == '') {
                        error 'A Flexy build number must be specified'
                    }
                    println('Job params are valid - continuing execution...')
                }
            }
        }
        stage('Get Flexy cluster and Netobserv scripts') {
            steps {
                copyArtifacts(
                    fingerprintArtifacts: true,
                    projectName: 'ocp-common/Flexy-install',
                    selector: specific(params.FLEXY_BUILD_NUMBER),
                    target: 'flexy-artifacts'
                )
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: GIT_BRANCH ]],
                    userRemoteConfigs: [[url: GIT_URL ]],
                    extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'ocp-qe-perfscale-ci']]
                ])
                script {
                    buildinfo = readYaml file: 'flexy-artifacts/BUILDINFO.yml'
                    currentBuild.displayName = "${currentBuild.displayName}-${params.FLEXY_BUILD_NUMBER}"
                    currentBuild.description = "Copied artifacts from Flexy-install build <a href=\"${buildinfo.buildUrl}\">${params.FLEXY_BUILD_NUMBER}</a><br/>"
                    buildinfo.params.each { env.setProperty(it.key, it.value) }
                    sh(returnStatus: true, script: """
                        mkdir -p ~/.kube
                        cp $WORKSPACE/flexy-artifacts/workdir/install-dir/auth/kubeconfig ~/.kube/config
                    """)
                }
            }
        }
        stage('Scale workers and install infra nodes') {
            when {
                expression { params.WORKER_COUNT != '0' }
            }
            steps {
                script {
                    scaleJob = build job: 'scale-ci/e2e-benchmarking-multibranch-pipeline/cluster-workers-scaling/', parameters: [
                        string(name: 'BUILD_NUMBER', value: params.FLEXY_BUILD_NUMBER),
                        string(name: 'JENKINS_AGENT_LABEL', value: params.JENKINS_AGENT_LABEL),
                        string(name: 'WORKER_COUNT', value: params.WORKER_COUNT),
                        booleanParam(name: 'INFRA_WORKLOAD_INSTALL', value: params.INFRA_WORKLOAD_INSTALL),
                        booleanParam(name: 'INSTALL_DITTYBOPPER', value: false),
                    ]
                    if (scaleJob.result != 'SUCCESS') {
                        error 'Scale job failed :('
                    }
                    else {
                        println "Successfully scaled cluster to ${params.WORKER_COUNT} worker nodes :)"
                        currentBuild.description += "Scale Job: <b><a href=${scaleJob.absoluteUrl}>${scaleJob.getNumber()}</a></b><br/>"
                        if (params.INFRA_WORKLOAD_INSTALL) {
                            println 'Successfully installed infrastructure nodes :)'
                        }
                        sh(returnStatus: true, script: '''
                            oc get nodes
                        ''')
                    }
                }
            }
        }
        stage('Install Netobserv Operator') {
            when {
                expression { params.INSTALLATION_SOURCE != 'None' }
            }
            steps {
                // setup aws creds for loki
                ansiColor('xterm') {
                    withCredentials([file(credentialsId: 'b73d6ed3-99ff-4e06-b2d8-64eaaf69d1db', variable: 'OCP_AWS')]) {
                        script {
                            returnCode = sh(returnStatus: true, script: """
                                mkdir -p ~/.aws
                                cp -f $OCP_AWS ~/.aws/credentials
                                echo "[profile default]
                                region = `cat $WORKSPACE/flexy-artifacts/workdir/install-dir/terraform.platform.auto.tfvars.json | jq -r ".aws_region"`
                                output = text" > ~/.aws/config
                            """)
                            if (returnCode.toInteger() != 0) {
                                error("Failed to set up aws creds")
                            }
                            else {
                                println "Successfully setup aws creds"
                            }   
                        }                     
                    }
                }
                script {
                    // attempt installation of Network Observability from selected source
                    if (params.INSTALLATION_SOURCE == 'OperatorHub') {
                        println 'Installing Network Observability from OperatorHub...'
                        returnCode = sh(returnStatus: true, script: """
                            source $WORKSPACE/ocp-qe-perfscale-ci/scripts/netobserv.sh
                            deploy_netobserv
                        """)
                    }
                    else {
                        println 'Installing Network Observability from Source...'
                        returnCode = sh(returnStatus: true, script: """
                            source $WORKSPACE/ocp-qe-perfscale-ci/scripts/netobserv.sh
                            deploy_main_catalogsource
                            deploy_netobserv
                        """)
                    }
                    // fail pipeline if installation failed, continue otherwise
                    if (returnCode.toInteger() != 0) {
                        error("Network Observability installation from ${params.INSTALLATION_SOURCE} failed :(")
                    }
                    else {
                        println "Successfully installed Network Observability from ${params.INSTALLATION_SOURCE} :)"
                    }
                }
            }
        }
        stage('Setup FLP and service-monitor') {
            when {
                expression { params.USER_WORKLOADS == true }
            }
            steps {
                script {
                    // attempt setup of FLP service and creation of service-monitor
                    println 'Setting up FLP service and creating service-monitor...'
                    returnCode = sh(returnStatus: true, script:  """
                        source $WORKSPACE/ocp-qe-perfscale-ci/scripts/netobserv.sh
                        populate_netobserv_metrics
                    """)
                    // fail pipeline if setup failed, continue otherwise
                    if (returnCode.toInteger() != 0) {
                        error('Setting up FLP service and creating service-monitor failed :(')
                    }
                    else {
                        println 'Successfully set up FLP service and created service-monitor :)'
                    }
                }
            }
        }
        stage('Update flowcollector params') {
            steps {
                script {
                    // attempt updating common parameters of flowcollector
                    println 'Updating common parameters of flowcollector...'
                    returnCode = sh(returnStatus: true, script: """
                        oc patch flowcollector cluster --type=json -p "[{"op": "replace", "path": "/spec/agent", "value": "ebpf"}] -n network-observability"
                        oc patch flowcollector cluster --type=json -p "[{"op": "replace", "path": "/spec/ebpf/sampling", "value": ${params.FLOW_SAMPLING_RATE}}] -n network-observability"
                        oc patch flowcollector cluster --type=json -p "[{"op": "replace", "path": "/spec/flowlogsPipeline/resources/limits/cpu", "value": "${params.CPU_LIMIT}"}] -n network-observability"
                        oc patch flowcollector cluster --type=json -p "[{"op": "replace", "path": "/spec/flowlogsPipeline/resources/limits/memory", "value": "${params.MEMORY_LIMIT}"}] -n network-observability"
                        oc patch flowcollector cluster --type=json -p "[{"op": "replace", "path": "/spec/flowlogsPipeline/replicas", "value": ${params.REPLICAS}}] -n network-observability"
                    """)
                    // fail pipeline if setup failed, continue otherwise
                    if (returnCode.toInteger() != 0) {
                        error('Updating common parameters of flowcollector failed :(')
                    }
                    else {
                        println 'Successfully updated common parameters of flowcollector :)'
                    }
                    println "Checking if Kafka needs to be enabled.."
                    if (env.ENABLE_KAFKA == "true") {
                        returnCode = sh(returnStatus: true, script:"""
                            echo "Enabling Kafka in flowcollector"
                            oc patch flowcollector cluster --type=json -p "[{"op": "replace", "path": "/spec/kafka/enable", "value": "true"}] -n network-observability"
                            source $WORKSPACE/ocp-qe-perfscale-ci/scripts/netobserv.sh
                            deploy_kafka
                        """)
                        if (returnCode.toInteger() != 0) {
                            error('Failed to enable Kafka in flowcollector')
                        }
                        else {
                            println 'Successfully enabled Kafka with flowcollector'
                        }
                    }
                    else {
                        println "Skipping Kafka deploy"
                    }
                }
            }
        }
        stage('Install Dittybopper') {
            when {
                expression { params.INSTALL_DITTYBOPPER == true }
            }
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: params.DITTYBOPPER_REPO_BRANCH ]],
                    userRemoteConfigs: [[url: params.DITTYBOPPER_REPO ]],
                    extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'performance-dashboards']]
                ])
                script {
                    // attempt installation of dittybopper
                    DITTYBOPPER_PARAMS = "-t $WORKSPACE/ocp-qe-perfscale-ci/scripts/netobserv-dittybopper.yaml -i $WORKSPACE/ocp-qe-perfscale-ci/scripts/netobserv_dittybopper_ebpf.json"
                    returnCode = sh(returnStatus: true, script: """
                        source $WORKSPACE/ocp-qe-perfscale-ci/scripts/netobserv.sh
                        setup_dittybopper_template
                        . $WORKSPACE/performance-dashboards/dittybopper/deploy.sh $DITTYBOPPER_PARAMS
                    """)
                    // fail pipeline if installation failed, continue otherwise
                    if (returnCode.toInteger() != 0) {
                        error('Installation of Dittybopper failed :(')
                    }
                    else {
                        println 'Successfully installed Dittybopper :)'
                    }
                }
            }
        }
    }

    post {
        always {
            println 'Post Section - Always'
            archiveArtifacts(
                artifacts: 'ocp-qe-perfscale-ci/data, ocp-qe-perfscale-ci/scripts/netobserv-dittybopper.yaml',
                allowEmptyArchive: true,
                fingerprint: true
            )
        }
        failure {
            println 'Post Section - Failure'
        }
    }
}
