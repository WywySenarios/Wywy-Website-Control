# GitHub Actions self-hosted runner images

The Wywy CI runners are built as two images — `docker/github-runner/` and
its `github-runner-kind/` sibling. `build.sh` and `push-image.sh`
operate on both.

## gh-runner (base image)

Debian 13 + GitHub Actions runner agent + Docker static binaries
(dockerd, Docker CLI, Docker Compose). One container, no sidecars — the
entrypoint starts dockerd, configures the runner, and polls GitHub for
jobs. Used as the base layer for `gh-runner-kind` and for standalone
local testing.

## gh-runner-kind (KinD image)

Strict superset of `gh-runner` with pinned versions of `kind` & `kubectl`.

Jobs opt in per-workflow via `runs-on:` labels. KinD jobs use `[self-hosted, wywy, kind]` (the kind pool bundles DinD — a job must NOT request both `dind` and `kind`, no pool carries both labels). See `internal/github-runners.mdx` in Wywy-Docs for job-authoring conventions.

## Building and pushing images

These images remain buildable if the CI runner deployment stack is
reintroduced. Build and push from any machine with Docker and a GHCR token:

```bash
scripts/install/github-runner/build.sh
scripts/install/github-runner/push-image.sh
```

## Bumping versions

### Runner agent

1. Update the `FROM` arg and `RUNNER_VERSION` arg in
   `docker/github-runner/Dockerfile`.
2. Set `DOCKER_VERSION` and/or `RUNNER_VERSION` env vars, then run the build and push scripts.

### kind & kubectl

1. Update `KIND_VERSION` / `KUBECTL_VERSION` in
   `docker/github-runner-kind/Dockerfile` (or pass the env vars to
   `build.sh`).
2. Rebuild + push.

## Verify the images

```bash
# Base image: Docker CLI and runner binaries.
docker run --rm ghcr.io/wywysenarios/gh-runner:2.336.0 \
  /bin/bash -c 'docker --version && ls /actions-runner/bin/'

# Kind image: kind + kubectl on top of the base tooling.
docker run --rm ghcr.io/wywysenarios/gh-runner-kind:2.336.0 \
  /bin/bash -c 'kind version && kubectl version --client'
```
