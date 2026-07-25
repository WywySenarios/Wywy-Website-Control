#!/usr/bin/env bash
#
# Install KEDA (Kubernetes Event-Driven Autoscaling) via Helm.
#
# Idempotent — safe to re-run.
#
set -euo pipefail

# ---- Helm repo (idempotent — add if missing, always update) ----
echo "==> Helm repo: kedacore..."
if helm repo list -o yaml | grep -q "kedacore"; then
	echo "  kedacore repo already registered"
else
	helm repo add kedacore https://kedacore.github.io/charts
fi
helm repo update

# ---- Namespace ----
if kubectl get ns keda &>/dev/null; then
	echo "  keda namespace already present"
else
	kubectl create namespace keda
fi

# ---- Install / upgrade KEDA ----
echo ""
echo "==> keda..."
helm upgrade --install keda kedacore/keda \
	--namespace keda \
	--atomic \
	--wait \
	--timeout 10m

# ---- Deploy ScaledObject for runner auto-scaling ----
echo ""
echo "==> github-runner ScaledObject..."
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
CONTROL_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
kubectl apply -k "$CONTROL_DIR/k8s/dev/github-runner"
