#!/bin/bash
# test.sh — Wywy-Website-Control test entrypoint (CI convention: sole way to
# run tests; direct invocation of test runners is not permitted).
#
# Control/ops repo: the suites target pre-existing infrastructure (dev
# cluster, VMs) — test.sh starts no services and tears nothing down.
#
# Usage:
#   ./test.sh            # default: smoke
#   ./test.sh smoke      # fast, no live infra required
#   ./test.sh deployment # live dev cluster/VM; skips what's absent
#   ./test.sh all        # run every suite, aggregate exit codes
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
cd "$SCRIPT_DIR"

case "${1:-smoke}" in
smoke) scripts/tests/smoke.sh ;;
deployment) scripts/tests/deployment.sh ;;
all)
	failed=0
	for suite in smoke deployment; do
		echo "==> test.sh: running $suite suite"
		if ! scripts/tests/$suite.sh; then
			failed=1
		fi
	done
	exit "$failed"
	;;
*)
	echo "Usage: $0 [smoke|deployment|all]" >&2
	exit 1
	;;
esac
