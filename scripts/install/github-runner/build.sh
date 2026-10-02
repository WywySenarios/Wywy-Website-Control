#!/usr/bin/env bash
#
# Build the GitHub Actions runner images and tag them for GHCR.
#
# Builds two images:
#
#   ghcr.io/wywysenarios/gh-runner:<RUNNER_VERSION>
#       Base runner + DinD image (docker/github-runner/).
#
#   ghcr.io/wywysenarios/gh-runner-kind:<RUNNER_VERSION>
#       Superset adding kind + kubectl (docker/github-runner-kind/),
#       built FROM the base image just built above.
#
# Prerequisites:
#   - Docker
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
CONTROL_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

BASE_DOCKERFILE_DIR="$CONTROL_DIR/docker/github-runner"
KIND_DOCKERFILE_DIR="$CONTROL_DIR/docker/github-runner-kind"

# ── Default versions (match Dockerfile defaults) ────────────────────
DOCKER_VERSION="${DOCKER_VERSION:-29.6.2}"
RUNNER_VERSION="${RUNNER_VERSION:-2.336.0}"
KIND_VERSION="${KIND_VERSION:-v0.33.0}"
KUBECTL_VERSION="${KUBECTL_VERSION:-v1.37.1}"

BASE_IMAGE_TAG="ghcr.io/wywysenarios/gh-runner:${RUNNER_VERSION}"
KIND_IMAGE_TAG="ghcr.io/wywysenarios/gh-runner-kind:${RUNNER_VERSION}"

echo "==> Building github-runner images"
echo "    Docker version:  ${DOCKER_VERSION}"
echo "    Runner version:  ${RUNNER_VERSION}"
echo "    Kind version:    ${KIND_VERSION}"
echo "    Kubectl version: ${KUBECTL_VERSION}"
echo ""

echo "==> Building base image: ${BASE_IMAGE_TAG}"
docker build \
	--build-arg "DOCKER_VERSION=${DOCKER_VERSION}" \
	--build-arg "RUNNER_VERSION=${RUNNER_VERSION}" \
	-t "${BASE_IMAGE_TAG}" \
	"${BASE_DOCKERFILE_DIR}"

echo ""
echo "==> Building kind image: ${KIND_IMAGE_TAG}"
docker build \
	--build-arg "RUNNER_VERSION=${RUNNER_VERSION}" \
	--build-arg "KIND_VERSION=${KIND_VERSION}" \
	--build-arg "KUBECTL_VERSION=${KUBECTL_VERSION}" \
	-t "${KIND_IMAGE_TAG}" \
	"${KIND_DOCKERFILE_DIR}"

echo ""
echo "==> Build complete:"
echo "    ${BASE_IMAGE_TAG}"
echo "    ${KIND_IMAGE_TAG}"
