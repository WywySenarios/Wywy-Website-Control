#!/bin/bash
set -euo pipefail

rm -f /var/run/docker.pid
dockerd --host=unix:///var/run/docker.sock >/var/log/dockerd.log 2>&1 &
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

if ! docker info >/dev/null 2>&1; then
	echo "ERROR: Docker daemon did not become ready." >&2
	cat /var/log/dockerd.log >&2
	exit 1
fi

chmod 666 /var/run/docker.sock
export HOME=/home/jenkins

exec setpriv --reuid=jenkins --regid=jenkins --clear-groups \
	/usr/local/bin/jenkins-agent
