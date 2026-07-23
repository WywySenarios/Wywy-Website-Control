#!/usr/bin/env bash
#
# Install Linkerd CLI and service mesh on a running K8s cluster.
#
# NOT idempotent. Comment-out pre-flight check if needed.
#
# I forgot that Helm was a thing when I was setting this up.
set -euo pipefail

# ---- CLI ----
if command -v linkerd &>/dev/null; then
	echo "  linkerd CLI $(linkerd version --client --short 2>/dev/null || linkerd version --client) already installed"
else
	echo "==> Installing linkerd CLI..."
	curl -fsL https://run.linkerd.io/install | sh
	export PATH=$PATH:$HOME/.linkerd2/bin
fi

# ---- Gateway API CRDs ----
if kubectl get crd gatewayclasses.gateway.networking.k8s.io &>/dev/null; then
	echo "  Gateway API CRDs already present"
else
	echo "==> Applying Gateway API CRDs..."
	kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
fi

# ---- Pre-flight check ----
linkerd check --pre

# ---- Linkerd CRDs ----
if kubectl get crd serviceprofiles.linkerd.io &>/dev/null; then
	echo "  Linkerd CRDs already present"
else
	echo "==> Installing Linkerd CRDs..."
	linkerd install --crds | kubectl apply -f -
fi

# ---- Control plane ----
if kubectl get ns linkerd &>/dev/null; then
	echo "  Linkerd control plane already installed"
else
	echo "==> Installing Linkerd control plane..."
	linkerd install | kubectl apply -f -
	kubectl wait --for=condition=Available -n linkerd deploy --all --timeout=5m
fi

# ---- Viz extension ----
if kubectl get ns linkerd-viz &>/dev/null; then
	echo "  Linkerd viz already installed"
else
	echo "==> Installing Linkerd viz..."
	linkerd viz install | kubectl apply -f -
	kubectl wait --for=condition=Available -n linkerd-viz deploy --all --timeout=5m
fi

# ---- Linkerd viz port-forward systemd service ----
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
"$SCRIPT_DIR/systemd/install.sh" linkerd-pf.service

# ---- Final check ----
linkerd check
