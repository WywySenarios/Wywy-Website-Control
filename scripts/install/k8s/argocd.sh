#!/usr/bin/env bash
#
# Install Argo CD on a running K8s cluster via Helm.
#
# Idempotent — safe to re-run.
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# ---- Pinned versions ----
# The CLI tag must match the chart's appVersion. Bump both together.
ARGOCD_CHART_VERSION="10.3.3"
ARGOCD_CLI_VERSION="v3.5.1"

# ---- CLI ----
installed_cli=""
if command -v argocd &>/dev/null; then
	installed_cli="$(argocd version --client 2>/dev/null | awk '/argocd:/{print $2; exit}' || true)"
fi

case "$installed_cli" in
"$ARGOCD_CLI_VERSION"*)
	echo "  argocd CLI $ARGOCD_CLI_VERSION already installed"
	;;
*)
	echo "==> Installing argocd CLI $ARGOCD_CLI_VERSION..."
	sudo curl -fsSL -o /usr/local/bin/argocd \
		"https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_CLI_VERSION}/argocd-linux-amd64"
	sudo chmod +x /usr/local/bin/argocd
	echo "  argocd CLI installed"
	;;
esac

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
echo "==> argo-cd $ARGOCD_CHART_VERSION..."

helm_args=(--version "$ARGOCD_CHART_VERSION")

# The server Service asks for a LoadBalancer. Until MetalLB is installed no
# ingress can be assigned, and --wait would time out and roll back the release.
if kubectl get crd ipaddresspools.metallb.io &>/dev/null; then
	echo "  MetalLB is installed; the server Service will request 192.168.18.150"
else
	echo "  MetalLB is not installed; installing with a ClusterIP server Service"
	echo "  (re-run after dev-metallb is healthy to get the LoadBalancer VIP)"
	helm_args+=(--set server.service.type=ClusterIP)
fi

helm upgrade --install argocd argo-helm/argo-cd \
	--namespace argocd \
	--values "$SCRIPT_DIR/values/argocd.yaml" \
	"${helm_args[@]}" \
	--atomic \
	--wait \
	--timeout 10m
