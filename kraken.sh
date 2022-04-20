#/!/bin/bash

cd kraken

ls

config_str=$(cat config.yaml)
root_user="/root/.kube/config"
echo "${config_str/"$root_user"/"$1"}" >> config2.yaml
cat config2.yaml

python run_kraken.py --config config2.yaml |& tee "logs.out"
exit $?