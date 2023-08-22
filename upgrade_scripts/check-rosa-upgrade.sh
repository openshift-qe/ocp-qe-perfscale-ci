#!/bin/bash
source ./common.sh
upgrade_pass=True

SECONDS=0
TARGET_BUILD=${TARGET_BUILD:=""}
export PYTHONUNBUFFERED=1
echo TARGET_RELEASES is $TARGET_RELEASES
target_version_prefix=${TARGET_RELEASES}
python3 -c "import check_upgrade; check_upgrade.check_upgrade('$target_version_prefix')"
duration=$SECONDS
echo "$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
sleep 120
abnormal_co
exit 0 #upgrade succ and post-check succ
