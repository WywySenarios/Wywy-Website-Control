#!/bin/bash
# ci.sh — Wywy-Website-Control CI runner
#
# Spins up a two-container CI runner (runner + dind sidecar) that mirrors
# the K8s runner pod architecture: both containers share a network namespace
# so the runner reaches dockerd via 127.0.0.1:2375.
#
# Usage:
#   ./scripts/run/ci.sh <path-to-test-sh> [<script-arg>...]
#
# Examples:
#   ./scripts/run/ci.sh ../Wywy-Website-Master-Database/test.sh

set -euo pipefail

# ---- Config ----
DIND_IMAGE="docker:28-dind"
RUNNER_IMAGE="docker:28"
RUNNER_ID="github-runner-test"

# ---- Args ----
if [ $# -lt 1 ]; then
	echo "Usage: $0 <path-to-test-sh> [<script-arg>...]" >&2
	exit 1
fi

SCRIPT="$(readlink -f "$1")"
shift

if [ ! -f "$SCRIPT" ]; then
	echo "ERROR: '$SCRIPT' not found" >&2
	exit 1
fi

# Resolve repo root (git, or fall back to script's parent).
if REPO_DIR="$(cd "$(dirname "$SCRIPT")" && git rev-parse --show-toplevel 2>/dev/null)"; then
	:
else
	REPO_DIR="$(dirname "$SCRIPT")"
fi
REPO_NAME="$(basename "$REPO_DIR")"

SCRIPT_REL="${SCRIPT#"$REPO_DIR"/}"
if [ "$SCRIPT_REL" = "$SCRIPT" ]; then
	SCRIPT_REL="$(basename "$SCRIPT")"
fi

CI_WORKSPACE="/_work/${RUNNER_ID}/${REPO_NAME}"

echo "============================================================"
echo "  Wywy CI runner"
echo "============================================================"
echo ""
echo "  Script:       $SCRIPT"
echo "  Repo dir:     $REPO_DIR"
echo "  Repo name:    $REPO_NAME"
echo "  CI workspace: $CI_WORKSPACE"
echo "  Relative:     $SCRIPT_REL"
echo "  Extra args:   $*"
echo ""

# ---- Pre-flight ----
if ! command -v docker &>/dev/null; then
	echo "ERROR: docker not found in PATH" >&2
	exit 1
fi

# ---- Cleanup ----
cleanup() {
	echo "Cleaning up..."
	docker kill "${RUNNER_CID:-}" 2>/dev/null || true
	docker kill "${DIND_CID:-}" 2>/dev/null || true
	docker rm "${RUNNER_CID:-}" "${DIND_CID:-}" 2>/dev/null || true
}
trap cleanup EXIT

# ---- Start dind sidecar ----
echo ""
echo "--- Starting dind sidecar ---"
DIND_CID=$(docker run -d --privileged \
	"$DIND_IMAGE" \
	dockerd \
	--host=unix:///var/run/docker.sock \
	--host=tcp://127.0.0.1:2375)
echo "  Container: $DIND_CID"

# Wait for dockerd.
echo "  Waiting for dockerd..."
for i in $(seq 1 15); do
	if docker exec "$DIND_CID" docker info &>/dev/null 2>&1; then
		echo "  dockerd ready after ${i}s"
		break
	fi
	if [ "$i" -eq 15 ]; then
		echo "ERROR: dockerd did not start in time" >&2
		docker logs "$DIND_CID" 2>&1 | tail -20
		exit 1
	fi
	sleep 1
done

# ---- Start runner container (shares dind's network namespace) ----
echo ""
echo "--- Starting runner container ---"
RUNNER_CID=$(docker run -d \
	--network "container:$DIND_CID" \
	-v "$REPO_DIR:$CI_WORKSPACE:ro" \
	-e DOCKER_HOST=tcp://127.0.0.1:2375 \
	-e DOCKER_TLS_VERIFY="" \
	"$RUNNER_IMAGE" \
	tail -f /dev/null)
echo "  Container: $RUNNER_CID"
echo "  DOCKER_HOST: tcp://127.0.0.1:2375"
echo "  Workspace:   $CI_WORKSPACE (read-only)"

# ---- Install docker compose + bash in runner ----
echo ""
echo "--- Installing docker compose + bash in runner ---"
docker exec "$RUNNER_CID" sh -c '
	apk add docker-cli-compose bash >/dev/null 2>&1
	echo "  docker compose installed: $(docker compose version 2>/dev/null)"
	echo "  bash installed: $(bash --version | head -1)"
' 2>&1

# ---- Verify runner → dind connectivity ----
echo ""
echo "--- Verifying runner → dind connectivity ---"
if docker exec "$RUNNER_CID" sh -c 'docker info --format "  Daemon version: {{.ServerVersion}}" 2>&1'; then
	echo "  Runner can reach dind daemon."
else
	echo "ERROR: Runner cannot reach dind daemon." >&2
	exit 1
fi

# ---- Run the test script in the runner ----
echo ""
echo "--- Running test script in runner ---"
echo ""

EXIT_CODE=0
docker exec "$RUNNER_CID" bash -c '
	set -euo pipefail

	SCRIPT_DIR="'"$CI_WORKSPACE"'"
	export SCRIPT_DIR
	export SECRETS_DIR="${SCRIPT_DIR}/config/ci"

	echo "  SCRIPT_DIR=$SCRIPT_DIR"
	echo "  SECRETS_DIR=$SECRETS_DIR"
	echo ""

	echo "  Workspace accessible: $(test -d "$SCRIPT_DIR" && echo YES || echo NO)"
	echo ""

	cd "$SCRIPT_DIR"
	REL_PATH="'"$SCRIPT_REL"'"
	if [ -x "$REL_PATH" ] || [ -f "$REL_PATH" ]; then
		echo "  Running: $REL_PATH '"$@"'"
		bash "$REL_PATH" '"$@"' 2>&1
		rc=$?
		echo ""
		echo "  >>> Script exited with code $rc <<<"
		exit $rc
	else
		echo "  Script not found at $REL_PATH in workspace"
		echo "  (mounted at $SCRIPT_DIR)"
		exit 1
	fi
' 2>&1 || EXIT_CODE=$?

# ---- Summary ----
echo ""
echo "============================================================"
if [ "$EXIT_CODE" -eq 0 ]; then
	echo "  RESULT: PASS (exit code 0)"
else
	echo "  RESULT: FAIL (exit code $EXIT_CODE)"
fi
echo "============================================================"

exit "$EXIT_CODE"
