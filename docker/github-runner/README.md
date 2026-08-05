# GitHub Actions self-hosted runner + DinD

Builds a single image combining Debian 13 with the GitHub Actions
runner agent and the official Docker static binaries. One container, no
sidecars — the entrypoint starts dockerd, configures the runner, and
polls GitHub for jobs.

## Cold start — manual image push

The KEDA-scaled deployment in `k8s/dev/github-runner/` pulls this image
from GHCR. You must build and push it at least once before KEDA can
spin up pods. Do this from any machine with Docker and a GHCR token:

```bash
scripts/install/github-runner/build.sh
scripts/install/github-runner/push-image.sh
```

After the push, apply the runner manifests to K8s:

```bash
scripts/install/k8s/github-runners.sh
```

## Bumping versions

When you need a newer Docker or runner version:

1. Update the `FROM` arg and `RUNNER_VERSION` arg in `Dockerfile`.
2. Set `DOCKER_VERSION` and/or `RUNNER_VERSION` env vars, then run the
   build and push scripts:
   ```bash
   DOCKER_VERSION=30.0.0 RUNNER_VERSION=2.340.0 ./build.sh
   ./push-image.sh
   ```
3. Update the inline `image:` tag in
   `k8s/dev/github-runner/base/deployment.yaml` to
   `ghcr.io/wywysenarios/gh-runner:<RUNNER_VERSION>`. There is no
   kustomize `images:` transform — the base deployment pins the image
   directly.
4. Re-run `scripts/install/k8s/github-runners.sh` to apply.
5. KEDA will pick up the new tag on the next scale-up.

## Verify the image

```bash
# Check that Docker CLI and runner binaries are present.
docker run --rm ghcr.io/wywysenarios/gh-runner:2.336.0 \
  /bin/bash -c 'docker --version && ls /actions-runner/bin/'
```
