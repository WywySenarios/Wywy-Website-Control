#!/usr/bin/env bash
#
# Apply Kubernetes manifests for all GitHub Actions runner overlays.
#
# Each overlay in k8s/dev/github-runner/<name>/ deploys a runner for one
# repository.  All are scaled from 0 (KEDA auto-scaling) so they consume
# no resources when idle.
#
# Idempotent — safe to re-run.
#
# Prerequisites:
#   - kubectl with a valid kubecontext pointing to the target cluster
#   - K8s secrets created beforehand (see base/kustomization.yaml)
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
CONTROL_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Repos to install — add new overlays here.
OVERLAYS=(
	control
	master-db
	docs
)

for overlay in "${OVERLAYS[@]}"; do
	echo "==> github-runner manifest: $overlay"
	kubectl apply -k "$CONTROL_DIR/k8s/dev/github-runner/$overlay"
done

echo ""
echo "==> All github-runner manifests applied."
