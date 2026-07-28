# GitHub Actions self-hosted runner + DinD

Builds a single image combining `docker:dind` with the GitHub Actions
runner agent. One container, no sidecars — the entrypoint starts
dockerd, configures the runner, and polls GitHub for jobs.

## Cold start — manual image push

The KEDA-scaled deployment in `k8s/dev/github-runner/` pulls this image
from GHCR. You must build and push it at least once before KEDA can
spin up pods. Do this from any machine with Docker and a GHCR token:

```bash
# 1. Authenticate with GHCR (one-time).
#    Use a PAT with `write:packages` scope.
echo "$GHCR_PAT" | docker login ghcr.io -u WywySenarios --password-stdin

# 2. Build the image.
#    Pinned versions are set via --build-arg (current defaults below).
docker build \
  --build-arg DOCKER_VERSION=29.6.2-dind \
  --build-arg RUNNER_VERSION=2.336.0 \
  -t ghcr.io/wywy/gh-runner:2.336.0 \
  .

# 3. Push to GHCR.
docker push ghcr.io/wywy/gh-runner:2.336.0
```

After the push, KEDA will pull the image automatically when scaling up.

## Bumping versions

When you need a newer Docker or runner version:

1. Update the `FROM` arg and `RUNNER_VERSION` arg in `Dockerfile`.
2. Update `newTag` in `k8s/dev/github-runner/kustomization.yaml`.
3. Rebuild and push with the new tag.
4. KEDA will pick up the new tag on the next scale-up.

## Verify the image

```bash
# Check that Docker CLI and runner binaries are present.
docker run --rm ghcr.io/wywy/gh-runner:2.336.0 \
  /bin/bash -c 'docker --version && ls /actions-runner/bin/'
```
