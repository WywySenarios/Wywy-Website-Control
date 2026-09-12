#!/usr/bin/env bash
#
# Deploy GitHub Actions self-hosted runner(s) via kustomize overlays.
#
# Each overlay in k8s/dev/github-runner/<name>/ deploys a runner for one
# repository.  All are scaling from 0 (KEDA auto-scaling) so they consume
# no resources when idle.
#
# Idempotent — safe to re-run.
#
# Note: this script is used to bootstrap CI in a fresh cluster without
# ArgoCD; in an existing cluster the per-repo overlays are GitOps-managed
# via k8s/dev/infrastructure/app-github-runner-<name>.yaml.
#
# Does NOT create the associated GitHub PAT secret. Refer to documentation for instructions on how to create the GitHub PAT secret.
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
CONTROL_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# repos to install
OVERLAYS=(
	control
	master-db
	docs
	cache
)

for overlay in "${OVERLAYS[@]}"; do
	echo "==> github-runner: $overlay"
	kubectl apply -k "$CONTROL_DIR/k8s/dev/github-runner/$overlay"
done
