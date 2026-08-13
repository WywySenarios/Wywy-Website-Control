#!/bin/bash
# scripts/tests/deployment.sh — deployment suite; requires live dev
# infrastructure (cluster, DB VM) and pre-staged config/secrets.
#
# Each bats file skips when its prereqs are absent (no cluster, no sops file,
# no .env.network), so this suite never hard-fails on an unprepared machine.
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
cd "$SCRIPT_DIR/../.."

if ! command -v bats >/dev/null 2>&1; then
	echo "ERROR: bats not found in PATH — install bats-core (e.g. apt install bats)" >&2
	exit 1
fi

mapfile -t FILES < <(find tests/deployment -type f -name '*.bats' | sort)
if [ "${#FILES[@]}" -eq 0 ]; then
	echo "ERROR: no bats files found under tests/deployment/" >&2
	exit 1
fi

bats "${FILES[@]}"
