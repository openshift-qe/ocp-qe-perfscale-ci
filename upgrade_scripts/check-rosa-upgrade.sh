#!/bin/bash
source ./common.sh
upgrade_pass=True

capture_failed_pods_before_upgrade

SECONDS=0
export PYTHONUNBUFFERED=1
python3 -c "import check_upgrade; check_upgrade.check_upgrade('$target_version_prefix')"
duration=$SECONDS
echo "$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
sleep 120
abnormal_co
sleep 120
capture_failed_pods_after_upgrade
exit 0 #upgrade succ and post-check succ
