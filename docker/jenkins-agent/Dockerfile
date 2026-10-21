# Jenkins inbound agent with Docker-in-Docker and the Wywy toolchain.
# Please note that this container is privileged with passwordless sudo.

ARG AGENT_VERSION=3391.va_37fa_a_305d6d-5
ARG DOCKER_VERSION=29.6.2
ARG COMPOSE_VERSION=5.4.0
FROM jenkins/inbound-agent:${AGENT_VERSION}-jdk21

USER root

ARG DOCKER_VERSION
ARG COMPOSE_VERSION
ARG BETTERLEAKS_VERSION=1.9.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        jq \
        iptables \
        iproute2 \
        kmod \
        procps \
        python3 \
        python3-venv \
        sudo \
        util-linux \
    && rm -rf /var/lib/apt/lists/*

# ── Docker engine (DinD) ─────────────────────────────────────────────
RUN curl -fsSL -o /tmp/docker.tgz \
        "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz" \
    && tar -xzf /tmp/docker.tgz -C /usr/local/bin --strip-components=1 \
        docker/docker \
        docker/dockerd \
        docker/containerd \
        docker/containerd-shim-runc-v2 \
        docker/runc \
        docker/docker-init \
        docker/docker-proxy \
    && rm /tmp/docker.tgz

# ── Docker Compose plugin ─────────────────────────────────────────────
RUN mkdir -p /usr/libexec/docker/cli-plugins \
    && curl -fsSL -o /usr/libexec/docker/cli-plugins/docker-compose \
        "https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-linux-x86_64" \
    && chmod +x /usr/libexec/docker/cli-plugins/docker-compose

# ── betterleaks ───────────────────────────────────────────────────────
RUN curl -fsSL -o /tmp/betterleaks.tgz \
        "https://github.com/betterleaks/betterleaks/releases/download/v${BETTERLEAKS_VERSION}/betterleaks_${BETTERLEAKS_VERSION}_linux_x64.tar.gz" \
    && tar -xzf /tmp/betterleaks.tgz -C /usr/local/bin betterleaks \
    && chmod +x /usr/local/bin/betterleaks \
    && rm /tmp/betterleaks.tgz

# ── uv ────────────────────────────────────────────────────────────────
COPY --from=ghcr.io/astral-sh/uv:0.11.28 /uv /uvx /usr/local/bin/

# ── Agent user ────────────────────────────────────────────────────────
# The inbound-agent image already provides the jenkins user.
# Agents are privileged with passwordless sudo

RUN mkdir -p /home/jenkins/agent \
    && chown -R jenkins:jenkins /home/jenkins \
    && echo 'jenkins ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/jenkins \
    && chmod 0440 /etc/sudoers.d/jenkins

# ── Docker daemon config ─────────────────────────────────────────────
# Keeps the gh-runner nofile limit for Valgrind.
# Registry trust comes from the pod-mounted /etc/docker/certs.d/registry.internal:5000/ca.crt
RUN mkdir -p /etc/docker
COPY daemon.json /etc/docker/daemon.json

COPY entrypoint-dind.sh /entrypoint-dind.sh
RUN chmod +x /entrypoint-dind.sh

ENTRYPOINT ["/entrypoint-dind.sh"]
USER root
