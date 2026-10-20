# Jenkins controller image. (NOT AN AGENT IMAGE)
# Base is pinned to the current LTS. Plugins are pinned in plugins.txt and
# installed at build time; no plugin is installed at runtime.

ARG JENKINS_VERSION=2.580.1
FROM jenkins/jenkins:${JENKINS_VERSION}-jdk21

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt