#!/usr/bin/env bash
#
# Deploy GitHub Actions self-hosted runner pools via kustomize overlays.
#
# Each overlay in k8s/dev/github-runner/<repo>-<pool>/ deploys one
# capability pool (generic, dind, kind) for one repository. Every pool
# scales from 0 (KEDA auto-scaling) so it consumes no resources when
# idle.
#
# Idempotent — safe to re-run.
#
# Note: this script is used to bootstrap CI in a fresh cluster without
# ArgoCD; in an existing cluster the per-(repo,pool) overlays are
# GitOps-managed via k8s/dev/infrastructure/app-github-runner-<repo>-<pool>.yaml.
#
# Does NOT create the associated GitHub PAT secret. Refer to documentation for instructions on how to create the GitHub PAT secret.
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
CONTROL_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# (repo, pool) pairs to install
OVERLAYS=(
	control-generic
	master-db-dind
	master-db-kind
	docs-dind
	cache-dind
)

for overlay in "${OVERLAYS[@]}"; do
	echo "==> github-runner: $overlay"
	kubectl apply -k "$CONTROL_DIR/k8s/dev/github-runner/$overlay"
done
