#!/bin/bash
# scripts/tests/smoke.sh — fast smoke suite; requires no live infrastructure.
#
# Runs the unit-style bats tests that mock external tools (kubectl, sops, ...)
# and use fixture trees. Safe to run pre-commit / pre-push.
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
cd "$SCRIPT_DIR/../.."

if ! command -v bats >/dev/null 2>&1; then
	echo "ERROR: bats not found in PATH — install bats-core (e.g. apt install bats)" >&2
	exit 1
fi

mapfile -t FILES < <(find tests/smoke -type f -name '*.bats' | sort)
if [ "${#FILES[@]}" -eq 0 ]; then
	echo "ERROR: no bats files found under tests/smoke/" >&2
	exit 1
fi

bats "${FILES[@]}"
