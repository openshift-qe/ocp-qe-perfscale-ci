FROM registry.ci.openshift.org/ocp/4.17:base-rhel9

LABEL vendor="Red Hat Inc." maintainer="OCP QE Team"

# install deps
RUN yum update -y && \
    yum install --setopt=tsflags=nodocs -y nfs-utils stunnel python3 openssl util-linux which && \
    yum clean all && rm -rf /var/cache/yum/*

RUN oc version