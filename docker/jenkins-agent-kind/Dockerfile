# Jenkins inbound agent + DinD + KinD (kind + kubectl).
# A strict superset of registry.internal:5000/jenkins-agent.

ARG AGENT_VERSION=3391.va_37fa_a_305d6d-5
FROM registry.internal:5000/jenkins-agent:${AGENT_VERSION}

USER root

ARG KIND_VERSION=v0.33.0
ARG KUBECTL_VERSION=v1.37.1

RUN curl -fsSL -o /usr/local/bin/kind \
        "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-amd64" \
    && chmod +x /usr/local/bin/kind

RUN curl -fsSL -o /usr/local/bin/kubectl \
        "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && chmod +x /usr/local/bin/kubectl
