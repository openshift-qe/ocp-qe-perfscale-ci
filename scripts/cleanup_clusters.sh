#!/bin/bash
set -ex

cleanup(){
    BASEDIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    echo "# BASEDIR: ${BASEDIR}"

    rm -rf $BASEDIR/local_env.txt
    env > $BASEDIR/local_env.txt
    while IFS="=" read -r key value; do
        if ! grep -q "$key=" $BASEDIR/local_env.txt; then
            if [[ ! $key == *"."* ]]; then
                export $key="${value}"
            fi
        fi
    done < $BASEDIR/environment.txt

    echo "# UUID: ${UUID}"

    ocm login --url="${GATEWAY_URL}" --token="${OCM_TOKEN}"

    # It deletes all pocm- clusters i.e clusters created by all airflow dags (and not only by this dag run)
    for cluster in `ocm list clusters --no-headers --columns id --parameter search="name like '%pocm-%'"`
    do
	echo "Deleting cluster $cluster"
        ocm delete cluster $cluster
	sleep 5
    done

    ocm logout

    # Enable removing test directories when CI becomes stable
    # rm -rf ${BASEDIR} /tmp/${UUID}
}

cleanup
