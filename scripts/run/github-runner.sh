#!/bin/bash
# Run the GitHub Actions self-hosted runner (master-database).
#
# Decrypts the runner PAT from SOPS at runtime (never written to disk),
# then delegates to docker compose.
#
# Usage:
#   run.sh github-runner [compose command]
#
# Examples:
#   run.sh github-runner up -d          # start daemonised
#   run.sh github-runner down           # tear down
#   run.sh github-runner logs -f        # tail logs
set -euo pipefail

CONTROL_DIR="$(cd "$(dirname "$(realpath "$0")")/../.." && pwd)"
COMPOSE_DIR="$CONTROL_DIR/docker/github-runner"

# ── Decrypt runner PAT ──────────────────────────────────────────────
# Plaintext is passed as an env var to compose — never written to disk.
TOKEN="$(sops --decrypt "$CONTROL_DIR/secrets/github-runner-token.sops")"
export GITHUB_PAT="$TOKEN"

# ── Docker compose ──────────────────────────────────────────────────
exec docker compose \
	-f "$COMPOSE_DIR/docker-compose.yml" \
	"$@"
