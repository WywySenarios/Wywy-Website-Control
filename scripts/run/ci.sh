#!/bin/bash
# ci.sh — Wywy-Website-Control CI runner
#
# Starts the custom GitHub Actions runner + DinD image as a single privileged
# container, closely mirroring the K8s runner pod. dockerd starts inside the
# container (same as entrypoint.sh), and the test script runs as the non-root
# `runner` user — exactly as it would in a real CI job.
#
# No packages are installed during this script. The runner image must already
# contain everything the test script needs. If a tool is missing, fix the
# Dockerfile, not this script.
#
# Usage:
#   ./scripts/run/ci.sh <path-to-test-sh> [<script-arg>...]
#
# Examples:
#   ./scripts/run/ci.sh ../Wywy-Website-Master-Database/test.sh

set -euo pipefail

# ---- Config ----
RUNNER_IMAGE="${RUNNER_IMAGE:-ghcr.io/wywysenarios/gh-runner:2.336.0}"
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

CI_WORKSPACE_ROOT="/_work/${RUNNER_ID}"
CI_WORKSPACE="${CI_WORKSPACE_ROOT}/${REPO_NAME}"

echo "============================================================"
echo "  Wywy CI runner"
echo "============================================================"
echo ""
echo "  Image:        $RUNNER_IMAGE"
echo "  Script:       $SCRIPT"
echo "  Repo dir:     $REPO_DIR"
echo "  Repo name:    $REPO_NAME"
echo "  Workspace:    $CI_WORKSPACE_ROOT"
echo "  Checkout:     $CI_WORKSPACE"
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
	docker rm "${RUNNER_CID:-}" 2>/dev/null || true
}
trap cleanup EXIT

# ---- Start runner container ──────────────────────────────────────────
# Single privileged container running the custom DinD runner image. The
# entrypoint is overridden because it requires ACCESS_TOKEN and REPO_URL
# (it registers with GitHub). Instead, we start dockerd manually — the
# same incantation entrypoint.sh uses — and keep the container alive.
#
# The repo is mounted read-only at the checkout path, matching how
# actions/checkout would place it inside the workspace root.
echo ""
echo "--- Starting runner container ---"
RUNNER_CID=$(docker run -d --privileged \
	--entrypoint /bin/bash \
	-v "$REPO_DIR:$CI_WORKSPACE:ro" \
	"$RUNNER_IMAGE" \
	-c '
		set -euo pipefail

		# Start dockerd (mirrors entrypoint.sh).
		rm -f /var/run/docker.pid
		dockerd \
			--host=unix:///var/run/docker.sock \
			--host=tcp://0.0.0.0:2375 \
			>/var/log/dockerd.log 2>&1 &
		DOCKERD_PID=$!

		for ((i = 0; i < 30; i++)); do
			if docker info >/dev/null 2>&1; then
				echo "Docker daemon ready."
				break
			fi
			if ! kill -0 "$DOCKERD_PID" 2>/dev/null; then
				echo "ERROR: dockerd process died." >&2
				cat /var/log/dockerd.log >&2
				exit 1
			fi
			sleep 1
		done

		# Make the Docker socket accessible to the non-root runner user.
		chmod 666 /var/run/docker.sock

		# Keep the container alive for exec.
		tail -f /dev/null
	')
echo "  Container: $RUNNER_CID"

# Wait for dockerd inside the container.
echo "  Waiting for dockerd..."
for i in $(seq 1 30); do
	if docker exec "$RUNNER_CID" docker info &>/dev/null 2>&1; then
		echo "  dockerd ready after ${i}s"
		break
	fi
	if [ "$i" -eq 30 ]; then
		echo "ERROR: dockerd did not start in time" >&2
		docker logs "$RUNNER_CID" 2>&1 | tail -20
		exit 1
	fi
	sleep 1
done

# ---- Run the test script in the runner ───────────────────────────────
# The test script runs as the non-root `runner` user via setpriv, matching
# how entrypoint.sh runs the Actions agent. HOME is set to the runner
# user's home directory so tools that read ~/.config or ~/.bashrc work
# correctly. No packages are installed — the image is used as-is.
echo ""
echo "--- Running test script in runner ---"
echo ""

EXIT_CODE=0
docker exec "$RUNNER_CID" bash -c '
	set -euo pipefail

	SCRIPT_DIR="'"$CI_WORKSPACE"'"
	export SCRIPT_DIR
	export SECRETS_DIR="${SCRIPT_DIR}/config/ci"
	export HOME="/home/runner"

	echo "  SCRIPT_DIR=$SCRIPT_DIR"
	echo "  SECRETS_DIR=$SECRETS_DIR"
	echo ""

	echo "  Files accessible: $(test -d "$SCRIPT_DIR" && echo YES || echo NO)"
	echo ""

	cd "$SCRIPT_DIR"
	REL_PATH="'"$SCRIPT_REL"'"
	if [ -x "$REL_PATH" ] || [ -f "$REL_PATH" ]; then
		echo "  Running: $REL_PATH '"$@"'"
		setpriv --reuid=runner --regid=runner --clear-groups \
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
