#!/usr/bin/env bash
#
# Install kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
# on a running K8s cluster.
#
# Idempotent — safe to re-run.
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# ---- Helm repo (idempotent — add updates if the repo already exists) ----
echo "==> Helm repo: prometheus-community..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update

# ---- kube-prometheus-stack ----
echo ""
echo "==> kube-prometheus-stack..."
kubectl create namespace monitoring 2>/dev/null || true
helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
	--namespace monitoring \
	--set grafana.adminPassword=admin \
	--atomic \
	--wait \
	--timeout 10m

# ---- Grafana port-forward systemd service ----
"$SCRIPT_DIR/systemd/install.sh" grafana-pf.service

echo ""
echo "=============================================="
echo "  kube-prometheus-stack installed."
echo "  Grafana: admin / admin"
echo "  kubectl -n monitoring port-forward svc/prometheus-stack-grafana 8081:80"
echo "=============================================="
