#!/bin/bash

upgrade_pass=True

if [ "$#" -lt 1 ]; then
  echo "syntax: $0 <target_build_version> "
  echo "example:"
  echo "./upgrade.sh 4.8.1"
  exit 1
fi

taget_build_arr=(${1//,/ })  #target_build maybe a list "4.1.22,4.1.0-0.nightly-2019-11-04-224442,4.2.2"

enable_force=true
scale=false
eus=false
eus_channel="fast"
maxUnavail=1
#optional parameters
while [[ $# -gt 1 ]]
do
key="$1"
echo "key $key"

case $key in
    -f|--force)
    enable_force=$2
    shift # past argument
    shift # past value
    ;;
    -s|--scale)
    scale=$2
    shift # past argument
    shift # past value
    ;;
    -e|--eus)
    eus=$2
    shift # past argument
    shift # past value
    ;;
   -c|--chn)
    eus_channel=$2
    shift # past argument
    shift # past value
    ;;
    -u|--maxunavil)
    maxUnavail=$2
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    #need to get past file
    shift # past arg
    ;;
esac
done

echo "force $enable_force"
echo "scale $scale"
echo "target version $taget_build_arr"
echo "eus $eus"

# It will take about 15 mins If Kube-apiserver rolling out occurs after upgrade was fnished
kas_rollingout_wait(){
    timeout=60
    internal=5
    t=0
    PROGRESSING=$(oc get co/kube-apiserver --no-headers | awk '{print $4}')
    while [ $t -lt $timeout ] ;do
        if [ "X$PROGRESSING" == "XFalse" ];then
          echo "Kube-apiserver is done progressing"
          break
        fi
        [ "X$PROGRESSING" == "XTrue" ] && break
        sleep $internal
        t=$(( t + internal ))
        PROGRESSING=$(oc get co/kube-apiserver --no-headers | awk '{print $4}')
        echo "kube-apiserver still progressing $PROGRESSING"
    done
    if [ "X$PROGRESSING" == "XTrue" ];then
        echo -e "Kube-apiserver is rolling out ..."
        internal=20
        timeout=900
        while [ $t -lt $timeout ]; do
            [ "X$PROGRESSING" == "XFalse" ] && break
            sleep $internal
            t=$(( t + internal ))
            PROGRESSING=$(oc get co/kube-apiserver --no-headers | awk '{print $4}')
        done
        if [ "X$PROGRESSING" == "XFalse" ];then
            echo -e "#### Kube-apiserver rolling out was completed!"
        else
            echo -e "#### Warning: After waiting, co/kube-apiserver is still in Progressing!"
            echo -e "#### Warning: If this issue happened during 4.3->4.4 upgrade, then probably hit the bug 1931033, detailed in https://issues.redhat.com/browse/OCPQE-3342!"
            echo -e "#### Warning: otherwise, then probably hit the bug https://bugzilla.redhat.com/show_bug.cgi?id=1909600"
        fi
    fi
}


function abnormal_co() {
  echo -e "exit from upgrade loop\n"
  echo -e "**************Post Action after upgrade succ****************\n"

  post_check1=`oc get node -o wide`
  post_check2=`oc get co`
  echo -e "Post action: #oc get node: ${post_check1}\n\n"
  echo -e "Post action: #oc get co:${post_check2}\n\n"
  echo -e "print detail msg for node(SchedulingDisabled) if exist:\n"
  echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~Abnormal node details~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n\n"
  if oc get node --no-headers | grep -E 'SchedulingDisabled|NotReady' ; then
                  oc get node --no-headers | grep -E 'SchedulingDisabled|NotReady'| awk '{print $1}'|while read line; do oc describe node $line;done
                  ret1="abnormal"
  fi
  echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n\n"
  echo -e "print detail msg for co(AVAILABLE != True or PROGRESSING!=False or DEGRADED!=False or version != target_version) if exist:\n"
  # Check if the kube-apiserver is rolling out after upgrade
  if [ -z "$ret1" ]; then # If master nodes are normal
      kas_rollingout_wait
  fi 

  echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~Abnormal co details~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n\n"
  abnormalCO=""
  abnormalCO=$(oc get co -o jsonpath='{range .items[*]}{.metadata.name} {range .status.conditions[*]} {.type}={.status}{end}{"\n"}{end}' | grep -v "openshift-samples" | grep -w -E 'Available=False|Progressing=True|Degraded=True' | awk '{print $1}')
  if [ "X$abnormaalCO" != "X" ]; then
      upgrade_pass=False
      quick_diagnosis "$abnormalCO"
      for aco in $abnormalCO; do
          oc describe co $aco
          echo -e "\n~~~~~~~~~~~~~~~~~~~~~~~\n"
      done
  fi
  ret2=`oc get co |sed '1d'|grep -v "openshift-samples"|grep -v "service-catalog-apiserver"|grep -v "service-catalog-controller-manager"|grep -v "True        False         False"|awk '{print $1}'|while read line; do oc describe co $line;done`
  oc get co |sed '1d'|grep -v "openshift-samples"|grep -v ${target_version_prefix}|awk '{print $1}'|while read line; do oc describe co $line;echo -e "\n~~~~~~~~~~~~~~~~~~~~~~~\n";done
  ret3=`oc get co |sed '1d'|grep -v "openshift-samples"|grep -v "service-catalog-apiserver"|grep -v "service-catalog-controller-manager"|grep -v ${target_version_prefix}|awk '{print $1}'|while read line; do oc describe co $line;done`
  echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n\n"


  if [ -z "$ret1" ] && [ -z "$ret2" ] && [ -z "$ret3" ]; then
      echo -e "post check passed without err.\n"

  else
      python3 -c "import check_upgrade; check_upgrade.pause_machinepool_worker('false')"
      sleep 10
      python3 -c "import check_upgrade; check_upgrade.wait_for_mcp_upgrade()"
      exit 127 # upgrade itself succ and post-check fail
  fi

}

# Quick diagnosis for abnormal cluster operators
function quick_diagnosis() {
    local abnormal_cos="$1"

    echo -e "~~~~~~~~\n $abnormal_cos \n~~~~~~~~\n"
    abnormal_co_logs=".abnormal_co_logs"
    all_co_logs=".all_co_logs" > "$abnormal_co_logs"
    oc get -o json clusteroperators > "$all_co_logs"
    for co in $abnormal_cos; do
        jq -r --arg co "$co" '.items[] | .metadata.name as $name | select($name == $co).status.conditions[] | .lastTransitionTime + " [" + $name + "] " + .type + " " + .status + " " + (.reason // "-") + " " + (.message // "-")' "$all_co_logs" >> "$abnormal_co_logs"
    done
    echo "#### Quick diagnosis: The first abnormal cluster operator is often the culprit! ####"
    echo "=> Below status and logs for the different conditions of all abnormal cos are sorted by 'lastTransitionTime':"
    # Error-tagging in one single line log
    reg1="Available False"
    reg2="Progressing True"
    reg3="Degraded True"
    reg4="not available"
    sed -i "s/$reg1/-->>$reg1<<--/g;s/$reg2/-->>$reg2<<--/g;s/$reg3/-->>$reg3<<--/g;s/$reg4/-->>$reg4<<--/g;" "$abnormal_co_logs"
    cat "$abnormal_co_logs" | sort
    echo -e "\n--------------------------\n"
    [ -f "$all_co_logs" ] && rm -f "$all_co_logs"
    [ -f "$abnormal_co_logs" ] && rm -f "$abnormal_co_logs"
}


function check_upgrade_version() {

  cur_version=$(oc get clusterversion -o jsonpath='{.items[0].status.desired.version}')
  cur_version_list=(${cur_version//./ })
  target_version_list=(${1//./ })
  index=1
  counter_cur=0
  for cur_version in "${cur_version_list[@]}"
  do
    counter_target=0
    for target_build_v in "${target_version_list[@]}"
    do
      if [[ $counter_cur -eq 1 ]]; then
        if [[ $counter_target -eq 1 ]]; then
          if [[ $cur_version -lt $((target_build_v - 1)) ]]; then
             echo "target build is more than 1 version ahead of current build"
             echo "Please update target version to be increased by 1"
             exit 1
            fi
        fi
      fi
      counter_target=$((counter_target+1))
  done
    counter_cur=$((counter_cur+1))
  done

}

function capture_failed_pods_before_upgrade(){
  #Save the failed job before upgrade and make sure new failed job caused by upgrade,ignore installer error
  echo "Capture failed pods before upgrade OCP"
  echo "####################################################################################"
  oc get pods -A| grep -v -E 'Running|Completed|installer'| awk '(NF=NF-2) 1'>/tmp/upgrade-before-failed-pods.txt
}

function capture_failed_pods_after_upgrade(){
  #Save the failed job before upgrade and make sure new failed job caused by upgrade
  echo "Capture failed pods after upgrade OCP, No messages means no errors"
  echo "####################################################################################"
  #Adding re-try steps to avoid temp failed pod
  oc get pods -A| grep -v -E 'Running|Completed|installer'| awk '(NF=NF-2) 1'>/tmp/upgrade-after-failed-pods.txt
  cat /tmp/upgrade-before-failed-pods.txt /tmp/upgrade-after-failed-pods.txt | sort | uniq -u>/tmp/new-failed-pods.txt
  init_retry=1
  max_retry=18

  while [[ $init_retry -le $max_retry && -s /tmp/new-failed-pods.txt ]]
  do
     oc get pods -A| grep -v -E 'Running|Completed|installer'| awk '(NF=NF-2) 1'>/tmp/upgrade-after-failed-pods.txt
     cat /tmp/upgrade-before-failed-pods.txt /tmp/upgrade-after-failed-pods.txt | sort | uniq -u>/tmp/new-failed-pods.txt
     echo -n "."&&sleep 10
     init_retry=$(( $init_retry + 1 ))
  done

  if [ -s /tmp/new-failed-pods.txt ];then

          echo "There are some failed job after upgrade, please check"
          echo "####################################################################################"
          cat /tmp/new-failed-pods.txt
          echo "####################################################################################"
          cat /tmp/new-failed-pods.txt | awk '{print $1"\t"$2}' >/tmp/pods.lst
          total_lines=$(cat /tmp/pods.lst|wc -l)
          init_line=1
          while [ $init_line -le $total_lines ]
          do
                  namespace=$(cat /tmp/pods.lst | sed -n "${init_line}p" | awk '{print $1}')
                  podname=$(cat /tmp/pods.lst | sed -n "${init_line}p" | awk '{print $2}')
                  echo "The detailed failed pods $podname information in $namespace:"
                  echo "------------------------------------------------------------------------------------" 
                  oc describe pod $podname -n $namespace
                  init_line=$(( $init_line + 1 ))
          done
          exit 1
  fi
}
capture_failed_pods_before_upgrade
python3 -c "import check_upgrade; check_upgrade.set_max_unavailable($maxUnavail)"
echo ARCH_TYPE is $ARCH_TYPE
if [[ $ARCH_TYPE == multi* ]];then
    node_arch="multi"
else
    node_name=`oc get node | grep master| head -1| awk '{print $1}'`
    node_arch=`oc get node $node_name -ojsonpath='{.status.nodeInfo.architecture}'`
fi


if [[ "X$node_arch" == "Xarm64" ]];then
   arch_prefix=aarch64
   release_path=ocp-arm64/release-arm64
elif [[ "X$node_arch" == "Xmulti" ]];then
   arch_prefix=multi
   release_path=ocp/release
else
   arch_prefix=x86_64
   release_path=ocp/release
fi


for target_build in "${taget_build_arr[@]}"
do
  check_upgrade_version $target_build
  echo ${target_build} |grep nightly >/dev/null 2>&1
 
  if [ $? -eq 0 ]
  then
      echo "target version nightly "
      target_version_prefix=${target_build}   #night build:4.2.0-0.nightly-2020-02-03-234322
      echo node_arch is $node_arch
      #Get target ocp image sha256 values
      #The node arch type is arm64 amd64 and multi
      if [[ "X$node_arch" == "Xmulti" ]]; then
	  image_path=$( echo $target_build | cut -d- -f1-3)
	  target_sha=$(curl -s https://multi.ocp.releases.ci.openshift.org/releasestream/${image_path}/release/${target_build} |grep PullSpec | awk -F'@' '{print $2}' | awk -F'<' '{print $1}')
      else
          target_sha=$(python3 -c "import check_upgrade; check_upgrade.get_sha_url('https://${node_arch}.ocp.releases.ci.openshift.org/graph','$target_version_prefix')")
      fi

      if [[ $target_sha == "" ]]; then
          echo "Could not find target version in 'https://${node_arch}.ocp.releases.ci.openshift.org/graph'"
          exit 1
      fi

      if [[ "X$eus" == "Xtrue" ]]; then
        python3 -c "import check_upgrade; check_upgrade.pause_machinepool_worker('true')"
        #Check if the worker node is arm64 or x86_64
        if [ "X$enable_force" == "Xtrue" ];then
           upgrade_line="oc adm upgrade --to-image $target_sha --force --allow-explicit-upgrade"
        else
           upgrade_line="oc adm upgrade --to-image $target_sha --allow-explicit-upgrade"
        fi
      elif [[ "X$node_arch" == "Xmulti" ]]; then
           upgrade_line="oc adm upgrade --to-image quay.io/openshift-release-dev/ocp-release-nightly@${target_sha} --force --allow-explicit-upgrade"
      else
        if [ "X$enable_force" == "Xtrue" ];then
           upgrade_line="oc adm upgrade --to-image registry.ci.openshift.org/$release_path:$target_version_prefix --force --allow-explicit-upgrade"
        else
           upgrade_line="oc adm upgrade --to-image registry.ci.openshift.org/$release_path:$target_version_prefix --allow-explicit-upgrade"
        fi
      fi
  else
    echo "target version quay "
    target_version_prefix=$(echo ${target_build}) #4.3.0-x86_64 ==> we got "Cluster version is 4.3.0"
    if [[ "X$eus" == "Xtrue" ]]; then
        python3 -c "import check_upgrade; check_upgrade.set_upstream_channel('$eus_channel','$target_version_prefix')"
        python3 -c "import check_upgrade; check_upgrade.pause_machinepool_worker('true')"
        found_version=$(python3 -c "import check_upgrade; check_upgrade.verify_version_in_channel_list('$target_version_prefix')")
        if [[ "X$found_version" == "XERROR" ]]; then
          echo "Could not find target version $target_version_prefix in 'oc adm upgrade' recommended paths"
          exit 1
        fi
        if [ "X$enable_force" == "Xtrue" ];then
          upgrade_line="oc adm upgrade --to $target_version_prefix --force"
        else
          upgrade_line="oc adm upgrade --to $target_version_prefix"
        fi
    else
      if [ "X$enable_force" == "Xtrue" ];then
        upgrade_line="oc adm upgrade --to-image quay.io/openshift-release-dev/ocp-release:${target_version_prefix}-${arch_prefix} --force --allow-explicit-upgrade"
      else
        upgrade_line="oc adm upgrade --to-image quay.io/openshift-release-dev/ocp-release:${target_version_prefix}-${arch_prefix} --allow-explicit-upgrade"
      fi
    fi
  fi

  echo "target version $target_version_prefix"
  echo "upgrade line $upgrade_line"
  echo $upgrade_line
  SECONDS=0
  CONSOLE_LAST_LINE="$($upgrade_line)"
  echo $CONSOLE_LAST_LINE
  export PYTHONUNBUFFERED=1
  python3 -c "import check_upgrade; check_upgrade.check_upgrade('$target_version_prefix')"
  duration=$SECONDS
  echo "$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
  sleep 30
  abnormal_co
  sleep 1
done

if [[ "X$eus" == "Xtrue" ]]; then
python3 -c "import check_upgrade; check_upgrade.pause_machinepool_worker('false')"
sleep 10
python3 -c "import check_upgrade; check_upgrade.wait_for_mcp_upgrade()"

fi

if [ "X$scale" == "Xtrue" ]; then
  #add machinesets
  machine_name=$(oc get machineset -n openshift-machine-api -o name --no-headers | grep "^.*$" -m1)
  #get first machine replica count
  #add 1 to replica count
  machine_replicas=$(oc get $machine_name -n openshift-machine-api -o jsonpath={.status.replicas})
  machine_replicas=$((machine_replicas + 1))
  oc scale --replicas=$machine_replicas -n openshift-machine-api $machine_name
  python3 -c "import check_upgrade; check_upgrade.wait_for_replicas('$machine_replicas','$machine_name')"
fi
capture_failed_pods_after_upgrade
exit 0 #upgrade succ and post-check succ
