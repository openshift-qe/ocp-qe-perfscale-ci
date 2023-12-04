# Distributed Tracing

Jenkins pipeline job which will use [Flexy-install](https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/job/ocp-common/job/Flexy-install/) cluster, install Dirstibuted Tracing operators and run workload against cluster.

## Pipeline Steps

- Scale up number of workers (optional)
- Add infra nodes (optional)
- Install [Dittybopper](https://github.com/cloud-bulldozer/performance-dashboards) (optional)
- Install [Opentelemetry Operator](https://github.com/open-telemetry/opentelemetry-operator) (optional)
- Install [Tempo Operator](https://github.com/grafana/tempo-operator) (optional)
- Run [Distributed Tracing QE](https://github.com/openshift/distributed-tracing-qe) test script (mandatory)
- Uninstall Dittybopper and operators (optional)

---

### Author

Simon Kordas <@skordas on [Github](https://github.com/skordas)>