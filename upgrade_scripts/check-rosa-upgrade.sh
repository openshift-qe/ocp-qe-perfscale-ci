#!/bin/bash
source ./common.sh
upgrade_pass=True

SECONDS=0
export PYTHONUNBUFFERED=1
python3 -c "import check_upgrade; check_upgrade.check_upgrade('$target_version_prefix')"
duration=$SECONDS
echo "$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
sleep 120
abnormal_co
exit 0 #upgrade succ and post-check succ
