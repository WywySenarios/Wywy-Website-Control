#!/usr/bin/env bash
#
# Push the GitHub Actions runner + DinD image to GHCR.
#
# Authenticates with GHCR by decrypting the PAT from
# secrets/ci/github-runner-token.sops via sops.
#
# The image tag pushed is:
#
#   ghcr.io/wywysenarios/gh-runner:<RUNNER_VERSION>
#
# Prerequisites:
#   - Docker (logged out or unauthenticated is fine — this script logs in)
#   - sops
#   - secrets/ci/github-runner-token.sops (SOPS-encrypted, tracked in git)
#   - Write access to ghcr.io/wywysenarios/gh-runner
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
CONTROL_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

RUNNER_VERSION="${RUNNER_VERSION:-2.336.0}"
IMAGE_TAG="ghcr.io/wywysenarios/gh-runner:${RUNNER_VERSION}"

# ── Resolve GHCR PAT (always via sops) ──────────────────────────────
if [[ ! -f "$CONTROL_DIR/secrets/ci/github-runner-token.sops" ]]; then
	echo "ERROR: secrets/ci/github-runner-token.sops not found." >&2
	exit 1
fi

echo "==> Decrypting GHCR PAT from secrets/ci/github-runner-token.sops ..."
TOKEN="$(sops --decrypt "$CONTROL_DIR/secrets/ci/github-runner-token.sops")"

# ── Authenticate ────────────────────────────────────────────────────
echo "==> Authenticating with ghcr.io as WywySenarios ..."
echo "$TOKEN" | docker login ghcr.io -u WywySenarios --password-stdin

# ── Push ────────────────────────────────────────────────────────────
echo "==> Pushing ${IMAGE_TAG} ..."
docker push "${IMAGE_TAG}"

echo ""
echo "==> Push complete: ${IMAGE_TAG}"
