#!/bin/bash
# test.sh — Wywy-Website-Control test entrypoint (CI convention: sole way to
# run tests; direct invocation of test runners is not permitted).
#
# Control/ops repo: the suites target pre-existing infrastructure (dev
# cluster, VMs) — test.sh starts no services and tears nothing down.
#
# The smoke suite was removed together with init-k8s-secrets.sh (ArgoCD now
# owns the cluster secrets); only the deployment suite remains.
#
# Usage:
#   ./test.sh            # default: deployment
#   ./test.sh deployment # live dev cluster/VM; skips what's absent
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
cd "$SCRIPT_DIR"

case "${1:-deployment}" in
deployment) scripts/tests/deployment.sh ;;
*)
	echo "Usage: $0 [deployment]" >&2
	exit 1
	;;
esac
