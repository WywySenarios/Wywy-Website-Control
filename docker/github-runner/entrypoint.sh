#!/bin/bash
# Entrypoint for the Wywy GitHub Actions runner + DinD.
#
# Starts dockerd (no TLS), configures the runner agent, and runs it.
# The runner runs in background so the SIGTERM trap fires immediately.
set -euo pipefail

# ── Required + defaults ──────────────────────────────────────────────
: "${ACCESS_TOKEN:?Must set ACCESS_TOKEN}"
: "${REPO_URL:?Must set REPO_URL}"

RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,wywy,dind}"
RUNNER_WORK_DIR="${RUNNER_WORK_DIR:-_work}"
EPHEMERAL="${EPHEMERAL:-true}"
DISABLE_AUTO_UPDATE="${DISABLE_AUTO_UPDATE:-true}"
RUNNER_NAME_ARG="--name ${RUNNER_NAME:-runner-$(hostname)}"

# ── Docker daemon ────────────────────────────────────────────────────
# Start dockerd in background, listening on Unix socket + TCP :2375.
dockerd \
	--host=unix:///var/run/docker.sock \
	--host=tcp://0.0.0.0:2375 \
	>/var/log/dockerd.log 2>&1 &

DOCKERD_PID=$!

echo "Waiting for Docker daemon..."
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

# ── Runner configuration ────────────────────────────────────────────
cd /actions-runner

if [ ! -f .runner ]; then
	echo "Configuring runner for ${REPO_URL}..."

	EPHEMERAL_FLAG=""
	[ "$EPHEMERAL" = "true" ] && EPHEMERAL_FLAG="--ephemeral"

	DISABLE_AUTO_UPDATE_FLAG=""
	[ "$DISABLE_AUTO_UPDATE" = "true" ] && DISABLE_AUTO_UPDATE_FLAG="--disableupdate"

	./config.sh \
		--url "${REPO_URL}" \
		--token "${ACCESS_TOKEN}" \
		--labels "${RUNNER_LABELS}" \
		${RUNNER_NAME_ARG} \
		--work "${RUNNER_WORK_DIR}" \
		${EPHEMERAL_FLAG} \
		${DISABLE_AUTO_UPDATE_FLAG} \
		--unattended
	echo "Runner configured."
fi

# ── Run (background so SIGTERM hits the trap immediately) ────────────
echo "Starting runner..."
./run.sh &
RUNNER_PID=$!

# ── Graceful shutdown ───────────────────────────────────────────────
# Kill the runner first, then remove from GitHub, then stop dockerd.
cleanup() {
	echo "Shutting down..."
	kill "$RUNNER_PID" 2>/dev/null || true
	wait "$RUNNER_PID" 2>/dev/null || true
	./config.sh remove --token "${ACCESS_TOKEN}" 2>/dev/null || true
	kill "$DOCKERD_PID" 2>/dev/null || true
	exit 0
}
trap cleanup SIGINT SIGTERM

# ── Wait and propagate exit code ─────────────────────────────────────
set +e
wait "$RUNNER_PID"
RUNNER_EXIT=$?
set -e

echo "Runner exited (${RUNNER_EXIT})."

kill "$DOCKERD_PID" 2>/dev/null || true
wait "$DOCKERD_PID" 2>/dev/null || true

exit "$RUNNER_EXIT"
