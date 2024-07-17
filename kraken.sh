#/!/bin/bash

cd kraken

cat config2.yaml

python run_kraken.py --config config2.yaml |& tee "logs.out"
exit $?