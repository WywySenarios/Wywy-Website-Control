#!/usr/bin/env bash
#
# Build the GitHub Actions runner + DinD image and tag it for GHCR.
#
# The image is built from docker/github-runner/ using pinned version args
# from the Dockerfile.  The resulting tag is:
#
#   ghcr.io/wywysenarios/gh-runner:<RUNNER_VERSION>
#
# Prerequisites:
#   - Docker
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
CONTROL_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

DOCKERFILE_DIR="$CONTROL_DIR/docker/github-runner"

# ── Default versions (match Dockerfile defaults) ────────────────────
DOCKER_VERSION="${DOCKER_VERSION:-29.6.2}"
RUNNER_VERSION="${RUNNER_VERSION:-2.336.0}"

IMAGE_TAG="ghcr.io/wywysenarios/gh-runner:${RUNNER_VERSION}"

echo "==> Building github-runner image"
echo "    Docker version: ${DOCKER_VERSION}"
echo "    Runner version: ${RUNNER_VERSION}"
echo "    Image tag:      ${IMAGE_TAG}"
echo "    Context:        ${DOCKERFILE_DIR}"
echo ""

docker build \
	--build-arg "DOCKER_VERSION=${DOCKER_VERSION}" \
	--build-arg "RUNNER_VERSION=${RUNNER_VERSION}" \
	-t "${IMAGE_TAG}" \
	"${DOCKERFILE_DIR}"

echo ""
echo "==> Build complete: ${IMAGE_TAG}"
