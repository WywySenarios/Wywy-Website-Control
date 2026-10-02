# GitHub Actions self-hosted runner + DinD + KinD (kind + kubectl).
#
# A strict superset of ghcr.io/wywysenarios/gh-runner

ARG RUNNER_VERSION=2.336.0
FROM ghcr.io/wywysenarios/gh-runner:${RUNNER_VERSION}

ARG KIND_VERSION=v0.33.0
ARG KUBECTL_VERSION=v1.37.1

RUN curl -fsSL -o /usr/local/bin/kind \
        "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-amd64" \
    && chmod +x /usr/local/bin/kind

RUN curl -fsSL -o /usr/local/bin/kubectl \
        "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && chmod +x /usr/local/bin/kubectl