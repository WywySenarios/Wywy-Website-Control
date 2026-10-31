# Jenkins inbound agent for static Kubernetes manifest checks.
ARG AGENT_VERSION=3391.va_37fa_a_305d6d-5
FROM jenkins/inbound-agent:${AGENT_VERSION}-jdk21

USER root

ARG KUSTOMIZE_VERSION=5.8.3
ARG KUSTOMIZE_SHA256=cb9e31198d3f63b44848bd0afc4c8efc56e6cfef9c93a4a39a211940e6decd61
ARG KUBECONFORM_VERSION=0.8.0
ARG KUBECONFORM_SHA256=9bc2bffbf71f261128533edaf912153948b7ff238f9a531ae6d34466ec287883
ARG KUBE_LINTER_VERSION=0.8.3
ARG KUBE_LINTER_SHA256=1a6d8419b11971372971fdbc22682b684ebfb7cf1c39591662d1b6ca736c41df
ARG YAMLLINT_VERSION=1.38.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        python3 \
        python3-venv \
        tar \
    && rm -rf /var/lib/apt/lists/*

# ── kustomize ────────────────────────────────────────────────────────
RUN curl -fsSL -o /tmp/kustomize.tgz \
        "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz" \
    && echo "${KUSTOMIZE_SHA256}  /tmp/kustomize.tgz" | sha256sum -c - \
    && tar -xzf /tmp/kustomize.tgz -C /usr/local/bin kustomize \
    && chmod +x /usr/local/bin/kustomize \
    && rm /tmp/kustomize.tgz

# ── kubeconform ──────────────────────────────────────────────────────
RUN curl -fsSL -o /tmp/kubeconform.tgz \
        "https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/kubeconform-linux-amd64.tar.gz" \
    && echo "${KUBECONFORM_SHA256}  /tmp/kubeconform.tgz" | sha256sum -c - \
    && tar -xzf /tmp/kubeconform.tgz -C /usr/local/bin kubeconform \
    && chmod +x /usr/local/bin/kubeconform \
    && rm /tmp/kubeconform.tgz

# ── kube-linter ──────────────────────────────────────────────────────
RUN curl -fsSL -o /tmp/kube-linter.tgz \
        "https://github.com/stackrox/kube-linter/releases/download/v${KUBE_LINTER_VERSION}/kube-linter-linux.tar.gz" \
    && echo "${KUBE_LINTER_SHA256}  /tmp/kube-linter.tgz" | sha256sum -c - \
    && tar -xzf /tmp/kube-linter.tgz -C /usr/local/bin kube-linter \
    && chmod +x /usr/local/bin/kube-linter \
    && rm /tmp/kube-linter.tgz

# ── yamllint ─────────────────────────────────────────────────────────
RUN python3 -m venv /opt/yamllint \
    && /opt/yamllint/bin/pip install --no-cache-dir "yamllint==${YAMLLINT_VERSION}" \
    && ln -s /opt/yamllint/bin/yamllint /usr/local/bin/yamllint

USER jenkins
