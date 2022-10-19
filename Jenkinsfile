@Library('flexy') _

// rename build
def userId = currentBuild.rawBuild.getCause(hudson.model.Cause$UserIdCause)?.userId
if (userId) {
    currentBuild.displayName = userId
}

pipeline {
    agent { label params.JENKINS_AGENT_LABEL }

    options {
        timeout(time: 6, unit: 'HOURS')
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
            description: '''
                Build number of Flexy job that installed the cluster.<br/>
                <b>Note that only AWS clusters are supported at the moment.</b>
            '''
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
                <b>Select Source until 0.1.5 NOO release since flowcollector has breaking changes</b><br/>
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
        separator(
            name: 'KAFKA_CONFIG_OPTIONS',
            sectionHeader: 'KAFKA Configuration Options',
            sectionHeaderStyle: '''
                font-size: 14px;
                font-weight: bold;
                font-family: 'Orienta', sans-serif;
            '''
        )
        booleanParam(
            name: 'ENABLE_KAFKA',
            defaultValue: false,
            description: 'Check this box to setup Kafka for NetObserv'
        )
        choice(
            name: 'TOPIC_PARTITIONS',
            choices: [6, 10, 24, 48],
            description: '''
            Number of Kafka Topic Partitions. Below are recommended values for partitions:<br/>
            6 - default for non-perf testing environments<br/>
            10 - Perf testing with worker nodes <= 20<br/>
            24 - Perf testing with worker nodes <= 50<br/>
            48 - Perf testing with worker nodes <= 100<br/>
            '''
        )
        string(
            name: 'FLP_KAFKA_REPLICAS',
            defaultValue: '3',
            description: '''
            Replicas should be at least half the number of Kafka TOPIC_PARTITIONS and should not exceed number of TOPIC_PARTITIONS or number of nodes:<br/>
            3 - default for non-perf testing environments<br/>
            '''
        )
        separator(
            name: 'WORKLOAD_CONFIG_OPTIONS',
            sectionHeader: 'Workload Configuration Options',
            sectionHeaderStyle: '''
                font-size: 14px;
                font-weight: bold;
                font-family: 'Orienta', sans-serif;
            '''
        )
        choice(
            name: 'WORKLOAD',
            choices: ['cluster-density', 'node-density', 'node-density-heavy', 'pod-density', 'pod-density-heavy', 'max-namespaces', 'max-services', 'concurrent-builds', 'router-perf', 'None'],
            description: '''
                Workload to run on Netobserv-enabled cluster<br/>
                Note that all options excluding "router-perf" and "None" will trigger "kube-burner" job<br/>
                "router-perf" will trigger "router-perf" job and "None" will run no workload<br/>
                For additional guidance on configuring workloads, see <a href=https://docs.google.com/spreadsheets/d/1DdFiJkCMA4c35WQT2SWXbdiHeCCcAZYjnv6wNpsEhIA/edit?usp=sharing#gid=1506806462>here</a>
            '''
        )
        string(
            name: 'VARIABLE',
            defaultValue: '1000',
            description: '''
                This variable configures parameter needed for each type of workload. <b>Not used by <a href=https://github.com/cloud-bulldozer/e2e-benchmarking/blob/master/workloads/router-perf-v2/README.md>router-perf</a> workload</b>.<br/>
                <a href=https://github.com/cloud-bulldozer/e2e-benchmarking/blob/master/workloads/kube-burner/README.md>cluster-density</a>: This will export JOB_ITERATIONS env variable; set to 4 * num_workers. This variable sets the number of iterations to perform (1 namespace per iteration).<br/>
                <a href=https://github.com/cloud-bulldozer/e2e-benchmarking/blob/master/workloads/kube-burner/README.md>node-density-heavy</a>: This will export PODS_PER_NODE env variable; set to 200, work up to 250. Creates this number of applications proportional to the calculated number of pods / 2<br/>
                Read <a href=https://github.com/openshift-qe/ocp-qe-perfscale-ci/tree/kube-burner/README.md>here</a> for details about each variable
            '''
        )
        string(
            name: 'NODE_COUNT',
            defaultValue: '3',
            description: '''
                Only for node-density and node-density-heavy<br/>
                Should be the number of worker nodes on your cluster (after scaling)
            '''
        )
        separator(
            name: 'NOPE_CONFIG_OPTIONS',
            sectionHeader: 'NOPE Configuration Options',
            sectionHeaderStyle: '''
                font-size: 14px;
                font-weight: bold;
                font-family: 'Orienta', sans-serif;
            '''
        )
        booleanParam(
            name: 'NOPE',
            defaultValue: true,
            description: '''
                Check this box to run the NOPE tool after the workload completes<br/>
                If the tool successfully uploads results to Elasticsearch, Touchstone will be run afterword
            '''
        )
        booleanParam(
            name: 'NOPE_DUMP',
            defaultValue: false,
            description: '''
                Check this box to dump data collected by the NOPE tool to a file instead of uploading to Elasticsearch<br/>
                Touchstone will <b>not</b> be run if this box is checked
            '''
        )
        booleanParam(
            name: 'NOPE_DEBUG',
            defaultValue: false,
            description: 'Check this box to run the NOPE tool in debug mode for additional logging'
        )
        separator(
            name: 'CLEANUP_OPTIONS',
            sectionHeader: 'Cleanup Options',
            sectionHeaderStyle: '''
                font-size: 14px;
                font-weight: bold;
                font-family: 'Orienta', sans-serif;
            '''
        )
        booleanParam(
            name: 'DELETE_S3_BUCKET',
            defaultValue: false,
            description: 'Check this box to delete AWS S3 Bucket, also deletes lokistack, flowcollector and kafka'
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
                    currentBuild.description = "Flexy-install Job: <a href=\"${buildinfo.buildUrl}\">${params.FLEXY_BUILD_NUMBER}</a><br/>"
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
                // setup AWS creds for loki
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
                                error("Failed to set up AWS creds :(")
                            }
                            else {
                                println "Successfully setup AWS creds :)"
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
                    // get bucketname for lokistack
                    env.S3_BUCKETNAME = sh(returnStdout: true, script: "/bin/bash -c 'oc extract cm/lokistack-config -n openshift-operators-redhat --keys=config.yaml --confirm --to=/tmp | xargs -I {} egrep bucketnames {} | cut -d: -f 2 | xargs echo -n'").trim()
                    println "Loki uses S3 bucket: ${env.S3_BUCKETNAME}"
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
                        oc patch flowcollector cluster --type=json -p "[{"op": "replace", "path": "/spec/agent/type", "value": "EBPF"}] -n netobserv"
                        oc patch flowcollector cluster --type=json -p "[{"op": "replace", "path": "/spec/agent/ebpf/sampling", "value": ${params.FLOW_SAMPLING_RATE}}] -n netobserv"
                        oc patch flowcollector cluster --type=json -p "[{"op": "replace", "path": "/spec/processor/resources/limits/cpu", "value": "${params.CPU_LIMIT}"}] -n netobserv"
                        oc patch flowcollector cluster --type=json -p "[{"op": "replace", "path": "/spec/processor/resources/limits/memory", "value": "${params.MEMORY_LIMIT}"}] -n netobserv"
                    """)
                    // fail pipeline if setup failed, continue otherwise
                    if (returnCode.toInteger() != 0) {
                        error('Updating common parameters of flowcollector failed :(')
                    }
                    else {
                        println 'Successfully updated common parameters of flowcollector :)'
                    }
                    println "Checking if Kafka needs to be enabled..."
                    if (params.ENABLE_KAFKA == true) {
                        println "Enabling Kafka in flowcollector..."
                        returnCode = sh(returnStatus: true, script: """
                            source $WORKSPACE/ocp-qe-perfscale-ci/scripts/netobserv.sh
                            deploy_kafka
                        """)
                        if (returnCode.toInteger() != 0) {
                            error('Failed to enable Kafka in flowcollector :(')
                        }
                        else {
                            println 'Successfully enabled Kafka with flowcollector :)'
                        }
                    }
                    else {
                        println "Skipping Kafka deploy..."
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
        stage('Run Workload and Mr. Sandman') {
            when {
                expression { params.WORKLOAD != 'None' }
            }
            steps {
                script {
                    if (params.WORKLOAD == 'router-perf') {
                        env.JENKINS_JOB = 'scale-ci/e2e-benchmarking-multibranch-pipeline/router-perf'
                        workloadJob = build job: env.JENKINS_JOB, parameters: [
                            string(name: 'BUILD_NUMBER', value: params.FLEXY_BUILD_NUMBER),
                            booleanParam(name: 'CERBERUS_CHECK', value: true),
                            string(name: 'JENKINS_AGENT_LABEL', value: params.JENKINS_AGENT_LABEL),
                            booleanParam(name: 'GEN_CSV', value: false)
                        ]
                    }
                    else {
                        env.JENKINS_JOB = 'scale-ci/e2e-benchmarking-multibranch-pipeline/kube-burner'
                        workloadJob = build job: env.JENKINS_JOB, parameters: [
                            string(name: 'BUILD_NUMBER', value: params.FLEXY_BUILD_NUMBER),
                            string(name: 'WORKLOAD', value: params.WORKLOAD),
                            booleanParam(name: 'CLEANUP', value: true),
                            booleanParam(name: 'CERBERUS_CHECK', value: true),
                            string(name: 'VARIABLE', value: params.VARIABLE), 
                            string(name: 'NODE_COUNT', value: params.NODE_COUNT),
                            booleanParam(name: 'GEN_CSV', value: false),
                            string(name: 'JENKINS_AGENT_LABEL', value: params.JENKINS_AGENT_LABEL)
                        ]
                    }
                    if (workloadJob.result != 'SUCCESS') {
                        error 'Workload job failed :('
                    }
                    else {
                        println "Successfully ran workload job :)"
                        // update build description with workload job link
                        env.JENKINS_BUILD = "${workloadJob.getNumber()}"
                        currentBuild.description += "Workload Job: <b><a href=${workloadJob.absoluteUrl}>${env.JENKINS_BUILD}</a></b> (workload <b>${params.WORKLOAD}</b> was run)<br/>"
                    }
                }
                copyArtifacts(
                    fingerprintArtifacts: true, 
                    projectName: env.JENKINS_JOB,
                    selector: specific(env.JENKINS_BUILD),
                    target: 'workload-artifacts'
                )
                script {
                    // run Mr. Sandman
                    returnCode = sh(returnStatus: true, script: """
                        python3.9 --version
                        python3.9 -m pip install virtualenv
                        python3.9 -m virtualenv venv3
                        source venv3/bin/activate
                        python --version
                        python -m pip install -r $WORKSPACE/ocp-qe-perfscale-ci/scripts/requirements.txt
                        python $WORKSPACE/ocp-qe-perfscale-ci/scripts/sandman.py --file $WORKSPACE/workload-artifacts/workloads/**/*.out
                    """)
                    // fail pipeline if Mr. Sandman run failed, continue otherwise
                    if (returnCode.toInteger() != 0) {
                        error('Mr. Sandman tool failed :(')
                    }
                    else {
                        println 'Successfully ran Mr. Sandman tool :)'
                    }
                    // update build description fields
                    // UUID
                    env.UUID = sh(returnStdout: true, script: "jq -r '.uuid' $WORKSPACE/ocp-qe-perfscale-ci/data/workload.json").trim()
                    currentBuild.description += "<b>UUID:</b> ${env.UUID}<br/>"
                    // STARTTIME_STRING is string rep of start time
                    env.STARTTIME_STRING = sh(returnStdout: true, script: "jq -r '.starttime_string' $WORKSPACE/ocp-qe-perfscale-ci/data/workload.json").trim()
                    currentBuild.description += "<b>STARTTIME_STRING:</b> ${env.STARTTIME_STRING}<br/>"
                    // ENDTIME_STRING is string rep of end time
                    env.ENDTIME_STRING = sh(returnStdout: true, script: "jq -r '.endtime_string' $WORKSPACE/ocp-qe-perfscale-ci/data/workload.json").trim()
                    currentBuild.description += "<b>ENDTIME_STRING:</b> ${env.ENDTIME_STRING}<br/>"
                    // STARTTIME_TIMESTAMP is unix timestamp of start time
                    env.STARTTIME_TIMESTAMP = sh(returnStdout: true, script: "jq -r '.starttime_timestamp' $WORKSPACE/ocp-qe-perfscale-ci/data/workload.json").trim()
                    currentBuild.description += "<b>STARTTIME_TIMESTAMP:</b> ${env.STARTTIME_TIMESTAMP}<br/>"
                    // ENDTIME_TIMESTAMP is unix timestamp of end time
                    env.ENDTIME_TIMESTAMP = sh(returnStdout: true, script: "jq -r '.endtime_timestamp' $WORKSPACE/ocp-qe-perfscale-ci/data/workload.json").trim()
                    currentBuild.description += "<b>ENDTIME_TIMESTAMP:</b> ${env.ENDTIME_TIMESTAMP}<br/>"
                }
            }
        }
        stage('Run NOPE tool') {
            when {
                expression { params.WORKLOAD != 'None' && params.NOPE == true }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: 'elasticsearch-perfscale-ocp-qe', usernameVariable: 'ES_USERNAME', passwordVariable: 'ES_PASSWORD')]) {
                    script {
                        NOPE_ARGS = '--starttime $STARTTIME_TIMESTAMP --endtime $ENDTIME_TIMESTAMP --jenkins-job $JENKINS_JOB --jenkins-build $JENKINS_BUILD --uuid $UUID'
                        if (params.USER_WORKLOADS == true) {
                            NOPE_ARGS += " --user-workloads"
                        }
                        if (params.NOPE_DUMP == true) {
                            NOPE_ARGS += " --dump"
                        }
                        if (params.NOPE_DEBUG == true) {
                            NOPE_ARGS += " --debug"
                        }
                        returnCode = sh(returnStatus: true, script: """
                            python3.9 --version
                            python3.9 -m pip install virtualenv
                            python3.9 -m virtualenv venv3
                            source venv3/bin/activate
                            python --version
                            python -m pip install -r $WORKSPACE/ocp-qe-perfscale-ci/scripts/requirements.txt
                            python $WORKSPACE/ocp-qe-perfscale-ci/scripts/nope.py $NOPE_ARGS
                        """)
                        // fail pipeline if NOPE run failed, continue otherwise
                        if (returnCode.toInteger() == 2) {
                            unstable('NOPE tool ran, but Elasticsearch upload failed - check build artifacts for data and try uploading it locally :/')
                        }
                        else if (returnCode.toInteger() != 0) {
                            error('NOPE tool failed :(')
                        }
                        else {
                            println 'Successfully ran NOPE tool :)'
                        }
                    }
                }
            }
        }
        stage('Run Touchstone tool') {
            when {
                expression { params.WORKLOAD != 'None' && params.NOPE == true && params.NOPE_DUMP == false && currentBuild.currentResult != "UNSTABLE" }
            }
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: 'master' ]],
                    userRemoteConfigs: [[url: 'https://github.com/cloud-bulldozer/benchmark-comparison.git' ]],
                    extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'benchmark-comparison']]
                ])
                withCredentials([usernamePassword(credentialsId: 'elasticsearch-perfscale-ocp-qe', usernameVariable: 'ES_USERNAME', passwordVariable: 'ES_PASSWORD')]) {
                    script {
                        returnCode = sh(returnStatus: true, script: """
                            python3.9 --version
                            python3.9 -m pip install virtualenv
                            python3.9 -m virtualenv venv3
                            source venv3/bin/activate
                            python --version
                            cd $WORKSPACE/benchmark-comparison
                            python setup.py develop
                            export UUID=`jq -r '.uuid' $WORKSPACE/ocp-qe-perfscale-ci/data/workload.json`
                            . $WORKSPACE/ocp-qe-perfscale-ci/scripts/touchstone.sh \$UUID
                        """)
                        // mark pipeline as unstable if Touchstone failed, continue otherwise
                        if (returnCode.toInteger() != 0) {
                            unstable('Touchstone tool failed - run locally with the given UUID to get run statistics :(')
                        }
                        else {
                            println 'Successfully ran Touchstone tool :)'
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            println 'Post Section - Always'
            archiveArtifacts(
                artifacts: 'ocp-qe-perfscale-ci/data/**, ocp-qe-perfscale-ci/scripts/netobserv-dittybopper.yaml',
                allowEmptyArchive: true,
                fingerprint: true
            )
        }
        failure {
            println 'Post Section - Failure'
        }
        cleanup {
            // delete AWS s3 bucket in the end
            script {
                if (params.DELETE_S3_BUCKET == true) {
                    println "Deleting AWS S3 Bucket, will also cleanup lokistack and flowcollector as part of it"
                    returnCode = sh(returnStatus: true, script: """
                        aws s3 rb s3://${env.S3_BUCKETNAME} --force
                        oc delete lokistack/lokistack -n openshift-operators-redhat
                        oc delete flowcollector/cluster
                        if [[ ${ENABLE_KAFKA} == "true" ]]; then
                            oc delete kafka/kafka-cluster -n netobserv
                            oc delete kafkaTopic/network-flows -n netobserv
                        fi
                    """)
                    if (returnCode.toInteger() != 0) {
                        error('Bucket deletion unsuccessful - please delete manually to save costs :(')
                    }
                    else {
                        println 'Bucket deleted successfully :)'
                    }
                }
            }
        }
    }
}
