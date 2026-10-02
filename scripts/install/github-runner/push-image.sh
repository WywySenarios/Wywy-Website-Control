#!/usr/bin/env bash
#
# Push the GitHub Actions runner images to GHCR.
#
# Authenticates with GHCR by decrypting the PAT from
# secrets/ci/github-runner-token.sops.yaml via sops.
#
# The image tags pushed are:
#
#   ghcr.io/wywysenarios/gh-runner:<RUNNER_VERSION>
#   ghcr.io/wywysenarios/gh-runner-kind:<RUNNER_VERSION>
#
# Prerequisites:
#   - Docker (logged out or unauthenticated is fine — this script logs in)
#   - sops
#   - secrets/ci/github-runner-token.sops.yaml (SOPS-encrypted, tracked in git)
#   - Write access to ghcr.io/wywysenarios/gh-runner and gh-runner-kind
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
CONTROL_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

RUNNER_VERSION="${RUNNER_VERSION:-2.336.0}"
BASE_IMAGE_TAG="ghcr.io/wywysenarios/gh-runner:${RUNNER_VERSION}"
KIND_IMAGE_TAG="ghcr.io/wywysenarios/gh-runner-kind:${RUNNER_VERSION}"

# ── Resolve GHCR PAT (always via sops) ──────────────────────────────
if [[ ! -f "$CONTROL_DIR/secrets/ci/github-runner-token.sops.yaml" ]]; then
	echo "ERROR: secrets/ci/github-runner-token.sops.yaml not found." >&2
	exit 1
fi

echo "==> Decrypting GHCR PAT from secrets/ci/github-runner-token.sops.yaml ..."
TOKEN="$(sops --decrypt "$CONTROL_DIR/secrets/ci/github-runner-token.sops.yaml")"

# ── Authenticate ────────────────────────────────────────────────────
echo "==> Authenticating with ghcr.io as WywySenarios ..."
echo "$TOKEN" | docker login ghcr.io -u WywySenarios --password-stdin

# ── Push ────────────────────────────────────────────────────────────
for tag in "${BASE_IMAGE_TAG}" "${KIND_IMAGE_TAG}"; do
	echo "==> Pushing ${tag} ..."
	docker push "${tag}"
done

echo ""
echo "==> Push complete:"
echo "    ${BASE_IMAGE_TAG}"
echo "    ${KIND_IMAGE_TAG}"
