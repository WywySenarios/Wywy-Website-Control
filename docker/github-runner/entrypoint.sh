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

# The agent (config.sh/run.sh) refuses to run as root ("Must not run with
# sudo"), so it drops to the non-root RUNNER_USER. dockerd stays root.
RUNNER_USER="${RUNNER_USER:-runner}"
export HOME="/home/${RUNNER_USER}"

# ── Docker daemon ────────────────────────────────────────────────────
# Start dockerd in background, listening on Unix socket + TCP :2375.
# A stale pid file (left after an unclean exit) makes dockerd refuse
# to start ("process with PID N is still running").
rm -f /var/run/docker.pid
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

# Make the Docker socket accessible to the non-root agent user.
chmod 666 /var/run/docker.sock

# ── Runner configuration ────────────────────────────────────────────
cd /actions-runner

if [ ! -f .runner ]; then
	echo "Configuring runner for ${REPO_URL}..."

	EPHEMERAL_FLAG=""
	[ "$EPHEMERAL" = "true" ] && EPHEMERAL_FLAG="--ephemeral"

	DISABLE_AUTO_UPDATE_FLAG=""
	[ "$DISABLE_AUTO_UPDATE" = "true" ] && DISABLE_AUTO_UPDATE_FLAG="--disableupdate"

	# Run config.sh as the non-root agent user (it refuses root).
	# setpriv execs the command directly, so its exit code propagates.
	# --reuid/--regid set effective AND real together (--euid/--egid
	# would be rejected as duplicates).
	#
	# The PAT must be passed as `--pat`, NOT `--token`: --token means a
	# short-lived registration token in current runners, and passing the
	# PAT there sends it as an invalid RemoteAuth token -> GitHub 404s.
	setpriv --reuid="${RUNNER_USER}" --regid="${RUNNER_USER}" --clear-groups \
		./config.sh \
		--url "${REPO_URL}" \
		--pat "${ACCESS_TOKEN}" \
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
# Run the agent as the non-root user; setpriv execs run.sh in-place, so
# $! is the real run.sh PID and SIGTERM reaches the actual agent.
setpriv --reuid="${RUNNER_USER}" --regid="${RUNNER_USER}" --clear-groups \
	./run.sh &
RUNNER_PID=$!

# ── Graceful shutdown ───────────────────────────────────────────────
# Kill the runner first, then remove from GitHub, then stop dockerd.
cleanup() {
	echo "Shutting down..."
	kill "$RUNNER_PID" 2>/dev/null || true
	wait "$RUNNER_PID" 2>/dev/null || true
	setpriv --reuid="${RUNNER_USER}" --regid="${RUNNER_USER}" --clear-groups \
		./config.sh remove --pat "${ACCESS_TOKEN}" 2>/dev/null || true
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
