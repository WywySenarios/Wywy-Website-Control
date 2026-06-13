#!/bin/bash
# Run Wywy-CI-CD — Go server or test suite.
# Invoked via: /etc/Wywy-Website-Control/run.sh ci-cd <test>
set -euo pipefail

REPO_DIR="/usr/local/Wywy-Website/Wywy-CI-CD"
CONTROL_DIR="${CONTROL_DIR:-/etc/Wywy-Website-Control}"

# Ensure Go is on PATH.
export PATH="$PATH:/usr/local/go/bin"

compose_command="${1:-up}"
shift 2>/dev/null || true
environment="${1:-prod}"
shift 2>/dev/null || true
endflags=("$@")

case "$environment" in
    test)
        cd "$REPO_DIR"
        echo "=== Wywy-CI-CD Go Tests ==="
        # Ensure dependencies are resolved (needed after fresh clone or new imports).
        go mod tidy 2>/dev/null || true
        go test ./... -v -count=1 "${endflags[@]}"
        exit $?
        ;;
    prod)
        cd "$REPO_DIR"
        echo "Starting Wywy-CI-CD server..."
        go run . "${endflags[@]}"
        ;;
    dev)
        cd "$REPO_DIR"
        echo "Starting Wywy-CI-CD server (dev mode)..."
        ENV=dev go run . "${endflags[@]}"
        ;;
    *)
        echo "Error: Invalid environment '$environment'. Expected <prod|dev|test>." >&2
        exit 1
        ;;
esac
