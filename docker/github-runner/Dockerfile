# GitHub Actions self-hosted runner + Docker-in-Docker
#
# Single image: official docker:dind base with the runner agent added.
# No separate sidecar, no third-party runner image — just a patched
# DinD that also registers with GitHub and runs workflow jobs.
#
# Pinned versions (override via --build-arg):
#   DOCKER_VERSION   — Docker dind tag (default: 29.6.2-dind)
#   RUNNER_VERSION   — GitHub runner version (default: 2.336.0)
#
# Build:
#   docker build -t gh-runner:dind docker/github-runner
#
# Run (requires --privileged for DinD):
#   docker run -d --privileged                          \
#     -e ACCESS_TOKEN=<pat>                              \
#     -e REPO_URL=https://github.com/WywySenarios/Wywy-Website-Master-Database \
#     gh-runner:dind
#
# Environment variables (see entrypoint.sh for defaults):
#   ACCESS_TOKEN         — GitHub personal access token (required)
#   REPO_URL             — repository URL (required)
#   RUNNER_LABELS        — comma-separated labels (default: self-hosted,wywy,dind)
#   RUNNER_NAME          — runner name (default: runner-<hostname>)
#   RUNNER_WORK_DIR      — working directory (default: _work)
#   EPHEMERAL            — remove runner after one job (default: true)
#   DISABLE_AUTO_UPDATE  — skip runner auto-update (default: true)

ARG DOCKER_VERSION=29.6.2-dind
FROM docker:${DOCKER_VERSION}

# ── Pinned versions ──────────────────────────────────────────────────
ARG RUNNER_VERSION=2.336.0

# ── Runner system deps (Alpine) ────────────────────────────────────
# gcompat provides glibc ABI — the runner binary links against glibc.
RUN apk add --no-cache \
        bash \
        ca-certificates \
        curl \
        git \
        jq \
        gcompat \
        icu-libs \
        krb5-libs \
        libstdc++ \
        lttng-ust \
        openssl \
        zlib

# ── GitHub Actions runner (pinned version) ─────────────────────────
RUN mkdir -p /actions-runner \
    && cd /actions-runner \
    && curl -fsSL -o "actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
        "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
    && tar xzf "actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
    && rm "actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
    && chown -R root:root /actions-runner

# ── Entrypoint ──────────────────────────────────────────────────────
# Overrides docker:dind's entrypoint (which only starts dockerd).
# Ours starts dockerd in background + configures and runs the runner.
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
