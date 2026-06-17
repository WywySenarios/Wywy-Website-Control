#!/bin/bash
# Run Wywy-CI — Go server, Astro frontend, or test suites.
# Invoked via: /etc/Wywy-Website-Control/run.sh ci <dev|test|go-test|astro-test|server|server-dev|astro-dev|astro-build>
set -euo pipefail

REPO_DIR="/usr/local/Wywy-Website/Wywy-CI"
ASTRO_DIR="$REPO_DIR/astro"
CONTROL_DIR="${CONTROL_DIR:-/etc/Wywy-Website-Control}"

# Ensure Go is on PATH.
export PATH="$PATH:/usr/local/go/bin"

compose_command="${1:-up}"
shift 2>/dev/null || true
mode="${1:-test}"
shift 2>/dev/null || true
endflags=("$@")

case "$mode" in
    test)
        echo "=== Wywy-CI All Tests ==="
        echo "--- Go Tests ---"
        cd "$REPO_DIR"
        go mod tidy 2>/dev/null || true
        go test ./... -v -count=1 "${endflags[@]}"
        go_exit=$?
        echo ""
        echo "--- Astro Tests ---"
        cd "$ASTRO_DIR"
        npx vitest run "${endflags[@]}"
        astro_exit=$?
        # Exit with failure if either suite failed.
        [ "$go_exit" -eq 0 ] && [ "$astro_exit" -eq 0 ]
        exit $?
        ;;
    go-test)
        cd "$REPO_DIR"
        echo "=== Wywy-CI Go Tests ==="
        go mod tidy 2>/dev/null || true
        go test ./... -v -count=1 "${endflags[@]}"
        exit $?
        ;;
    astro-test)
        echo "=== Wywy-CI Astro Tests ==="
        if [ ! -d "$ASTRO_DIR/node_modules" ]; then
            cd "$ASTRO_DIR" && npm install
        fi
        cd "$ASTRO_DIR"
        npx vitest run "${endflags[@]}"
        exit $?
        ;;
    server)
        cd "$REPO_DIR"
        echo "Starting Wywy-CI server..."
        go run . "${endflags[@]}"
        exit $?
        ;;
    server-dev)
        cd "$REPO_DIR"
        echo "Starting Wywy-CI server (dev mode)..."
        ENV=dev go run . "${endflags[@]}"
        exit $?
        ;;
    dev)
        echo "=== Wywy-CI Dev Mode ==="
        echo "Starting Go server (port 2526) + Astro dev server (port 3001)..."
        # Ensure Go dependencies are ready before backgrounding.
        cd "$REPO_DIR"
        go mod tidy 2>/dev/null || true
        # Ensure npm dependencies are installed.
        if [ ! -d "$ASTRO_DIR/node_modules" ]; then
            echo "Installing npm dependencies..."
            cd "$ASTRO_DIR" && npm install
        fi
        # Kill both on Ctrl+C / SIGTERM.
        cleanup() {
            echo ""
            echo "Shutting down both servers..."
            kill "$go_pid" "$astro_pid" 2>/dev/null || true
            wait "$go_pid" "$astro_pid" 2>/dev/null || true
            exit 0
        }
        trap cleanup SIGINT SIGTERM
        # Start Go server in background.
        cd "$REPO_DIR"
        ENV=dev go run . &
        go_pid=$!
        # Brief pause so Go can bind port before Astro output interleaves.
        sleep 1
        # Start Astro dev server in background.
        cd "$ASTRO_DIR"
        npx astro dev --port 3001 "${endflags[@]}" &
        astro_pid=$!
        # Wait for either to finish (Ctrl+C triggers cleanup via trap).
        wait "$go_pid" "$astro_pid" 2>/dev/null || true
        cleanup
        ;;
    astro-dev)
        echo "Starting Astro dev server on port 3001..."
        if [ ! -d "$ASTRO_DIR/node_modules" ]; then
            cd "$ASTRO_DIR" && npm install
        fi
        cd "$ASTRO_DIR"
        npx astro dev --port 3001 "${endflags[@]}"
        exit $?
        ;;
    astro-build)
        echo "Building Astro (static site)..."
        if [ ! -d "$ASTRO_DIR/node_modules" ]; then
            cd "$ASTRO_DIR" && npm install
        fi
        cd "$ASTRO_DIR"
        npx astro build "${endflags[@]}"
        exit $?
        ;;
    *)
        echo "Error: Invalid mode '$mode'. Expected: dev|test|go-test|astro-test|server|server-dev|astro-dev|astro-build" >&2
        exit 1
        ;;
esac
