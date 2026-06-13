#!/bin/bash
# Set up the agentic log directory structure on the host.
#
# Creates /var/log/Wywy-Website/agentic/ if it doesn't exist and sets
# ownership to the container user for bind-mount access.
#
# This script runs as part of the Wywy-Codes orchestrator install step.
# It follows the Bash conventions at internal/conventions/languages/bash.mdx.

set -euo pipefail

LOG_BASE_DIR="/var/log/Wywy-Website/agentic"
CONTAINER_UID="${CONTAINER_UID:-25230}"
CONTAINER_GID="${CONTAINER_GID:-2523}"

function setup_log_dir() {
    mkdir -p "$LOG_BASE_DIR"
    chown "${CONTAINER_UID}:${CONTAINER_GID}" "$LOG_BASE_DIR"
    chmod 775 "$LOG_BASE_DIR"
}

setup_log_dir

echo "Log directory ready: $LOG_BASE_DIR"
