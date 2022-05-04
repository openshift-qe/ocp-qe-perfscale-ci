# NETOBSERV Performance Scripts
The purpose of scripts in this directory is to measure [network-observability](https://github.com/netobserv/network-observability-operator) metrics performance

Multiple workloads are run to generate traffic for the the cluster:
1. uperf - pod-to-pod traffic generation.
2. node-density-heavy (using kube-burner)
3. router-perf

## Network Observability Prometheus and Elasticsearch tool (NOPE)
The Network Observability Prometheus and Elasticsearch tool, or NOPE, is a Python program that is used for collecting and sharing performance data for a given OpenShift cluster running the Network Observability Operator, using Prometheus queries for collection and Elasticsearch servers for sharing. Raw JSON files are written to the `data/` directory in the project - note this directory will be created automatically if it does not already exist.

### Running the tool
1. Ensure you have Python 3.9+ and Pip installed (verify with `python --version` and `pip --version`)
2. Install requirements with `pip install -r scripts/requirements.txt`
3. Set your `kubeconfig` and login to your cluster as `kubeadmin`
4. Run the tool with `./scripts/nope.py`
