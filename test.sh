#!/bin/bash
# test.sh — Wywy-Website-Control test entrypoint (CI convention: sole way to
# run tests; direct invocation of test runners is not permitted).
#
# Control/ops repo: the suites target pre-existing infrastructure (dev
# cluster, VMs) — test.sh starts no services and tears nothing down.
#
# The smoke suite was removed together with init-k8s-secrets.sh (ArgoCD now
# owns the cluster secrets).
#
# Usage:
#   ./test.sh            # default: deployment
#   ./test.sh deployment # live dev cluster/VM; skips what's absent
#   ./test.sh ansible    # venv-isolated ansible lint + syntax-check
#   ./test.sh all        # both; the deployment suite's known failures do not
#                        # abort the ansible suite
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
cd "$SCRIPT_DIR"

case "${1:-deployment}" in
deployment) scripts/tests/deployment.sh ;;
ansible) scripts/tests/ansible.sh ;;
all)
	# The deployment suite is pre-existing-broken for sops reads. Capture its
	# exit code so it cannot abort the ansible suite (which runs last under
	# set -e); aggregate the two at the end.
	set +e
	scripts/tests/deployment.sh
	deployment_rc=$?
	set -e
	scripts/tests/ansible.sh
	exit "$deployment_rc"
	;;
*)
	echo "Usage: $0 [deployment|ansible|all]" >&2
	exit 1
	;;
esac
