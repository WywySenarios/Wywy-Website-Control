#!/usr/bin/env bash
#
# Install Argo CD on a running K8s cluster via Helm.
#
# Idempotent — safe to re-run.
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# ---- CLI ----
if command -v argocd &>/dev/null; then
	echo "  argocd CLI $(argocd version --client 2>/dev/null || echo "already installed")"
else
	echo "==> Installing argocd CLI..."
	sudo curl -fsSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
	sudo chmod +x /usr/local/bin/argocd
	echo "  argocd CLI installed"
fi

# ---- Helm repo (idempotent — add updates if the repo already exists) ----
echo "==> Helm repo: argo-helm..."
if helm repo list -o yaml | grep -q "argo-helm"; then
	echo "  argo-helm repo already registered"
else
	helm repo add argo-helm https://argoproj.github.io/argo-helm
fi
helm repo update

# ---- Namespace ----
if kubectl get ns argocd &>/dev/null; then
	echo "  argocd namespace already present"
else
	kubectl create namespace argocd
fi

# ---- Install / upgrade ArgoCD ----
echo ""
echo "==> argo-cd..."
helm upgrade --install argocd argo-helm/argo-cd \
	--namespace argocd \
	--values "$SCRIPT_DIR/values/argocd.yaml" \
	--atomic \
	--wait \
	--timeout 10m

# ---- ArgoCD server port-forward systemd service ----
"$SCRIPT_DIR/systemd/install.sh" argocd-pf.service
