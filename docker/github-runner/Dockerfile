# GitHub Actions self-hosted runner + Docker-in-Docker + Debian 13 base image.
#
# Pinned versions (override via --build-arg):
#   DOCKER_VERSION    — Docker static release (default: 29.6.2)
#   RUNNER_VERSION    — GitHub runner version (default: 2.336.0)
#   COMPOSE_VERSION   — Docker Compose plugin (default: 5.4.0)
#
# Run (requires --privileged for DinD):
#   docker run -d --privileged                          \
#     -e ACCESS_TOKEN=<pat>                              \
#     -e REPO_URL=https://github.com/WywySenarios/Wywy-Website-Master-Database \
#     gh-runner:29.6.2
#
# Environment variables (see entrypoint.sh for defaults):
#   ACCESS_TOKEN         — GitHub personal access token (required)
#   REPO_URL             — repository URL (required)
#   RUNNER_LABELS        — comma-separated labels (default: self-hosted,wywy,dind)
#   RUNNER_NAME          — runner name (default: runner-<hostname>)
#   RUNNER_WORK_DIR      — working directory (default: _work)
#   EPHEMERAL            — remove runner after one job (default: true)
#   DISABLE_AUTO_UPDATE  — skip runner auto-update (default: true)
#   RUNNER_USER          — non-root user the agent runs as (default: runner)

ARG DOCKER_VERSION=29.6.2
ARG RUNNER_VERSION=2.336.0
ARG COMPOSE_VERSION=5.4.0
FROM debian:13-slim

# Re-declare without values so they inherit the pre-FROM ARG defaults
# (or --build-arg). ARGs before FROM are outside the stage scope and would
# expand empty inside RUN otherwise.
ARG DOCKER_VERSION
ARG RUNNER_VERSION
ARG COMPOSE_VERSION

# ── Runner and workflow base tools ──────────────────────────────────
# bash             Runs the entrypoint and shell-based workflow steps.
# ca-certificates  Provides TLS trust for GitHub, GHCR, Docker, and APIs.
# curl             Downloads the pinned runner and Docker archives below.
# git              Provides Actions checkout and repository operations.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
    && rm -rf /var/lib/apt/lists/*

# ── DinD infrastructure ─────────────────────────────────────────────
# iptables         Docker bridge networking and NAT/firewall rules.
# iproute2         Network tools, including `ip`, used by Docker setup.
# kmod             Kernel-module tools such as modprobe used by Docker setup.
# procps           Process tools such as ps used by Docker and diagnostics.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        iptables \
        iproute2 \
        kmod \
        procps \
    && rm -rf /var/lib/apt/lists/*

# ── GitHub Actions runner runtime ────────────────────────────────────
# GitHub Actions is a .NET application.
#
# libgcc-s1   GCC runtime required by native runner dependencies.
# libstdc++6  C++ runtime required by native runner dependencies.
# zlib1g      Compression support required by the runner/runtime.
# libkrb5-3   Kerberos/GSSAPI support used by .NET networking libraries.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libgcc-s1 \
        libstdc++6 \
        zlib1g \
        libkrb5-3 \
    && rm -rf /var/lib/apt/lists/*

# Debian changed the names of these runner runtime packages across releases.
# Each group tries the Debian 13 name first, then older compatible names.
#
# libicu*          Unicode and globalization support for the .NET runner.
# libssl*          TLS and cryptographic support for .NET and HTTPS clients.
# libasound2*      Native .NET runtime dependency; CI does not use audio.
# liblttng-ust1*   Native .NET runtime tracing dependency.
RUN apt-get update \
    && for pkg in libicu76 libicu75 libicu74; do \
        apt-get install -y --no-install-recommends "$pkg" 2>/dev/null && break; done \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
    && for pkg in libssl3t64 libssl3; do \
        apt-get install -y --no-install-recommends "$pkg" 2>/dev/null && break; done \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
    && for pkg in libasound2t64 libasound2; do \
        apt-get install -y --no-install-recommends "$pkg" 2>/dev/null && break; done \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
    && for pkg in liblttng-ust1t64 liblttng-ust1; do \
        apt-get install -y --no-install-recommends "$pkg" 2>/dev/null && break; done \
    && rm -rf /var/lib/apt/lists/*

# jq and openssh-client are intentionally omitted. No tracked runner code or
# workflow requires them; repositories can install optional workflow tooling
# in their own job when needed.

# ── GitHub Actions runner ─────────────────────────
RUN mkdir -p /actions-runner \
    && cd /actions-runner \
    && curl -fsSL -o "actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
        "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
    && tar xzf "actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
    && rm "actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"

# ── Docker engine ────────────────────────
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

# ── Non-root user ─────────────────────────────────────────────
# @TODO: remove sudo capabilities. This is a temporary band-aid intended to create directories during the transition over to CI/CD.
RUN apt-get update \
    && apt-get install -y --no-install-recommends sudo \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --home-dir /home/runner runner \
    && mkdir -p /actions-runner/_work \
    && chown -R runner:runner /actions-runner /home/runner \
    && echo 'runner ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/runner \
    && chmod 0440 /etc/sudoers.d/runner

# ── Docker daemon config ─────────────────────────────────────────────
# Sets a sane default nofile ulimit so containers spawned inside this
# DinD runner don't inherit an enormous RLIMIT_NOFILE that crashes
# tools like Valgrind (https://bugs.kde.org/show_bug.cgi?id=458106).
RUN mkdir -p /etc/docker
COPY daemon.json /etc/docker/daemon.json

# ── Entrypoint ──────────────────────────────────────────────────────
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
