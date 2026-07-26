#!/usr/bin/env bash
#
# Install Longhorn on a running K8s cluster via Helm.
#
# Installs open-iscsi on every worker node (SSH) then deploys Longhorn.
# Idempotent — safe to re-run.
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
CONTROL_DIR="$(realpath "$SCRIPT_DIR/../../..")"
SYSUSER="wywy"

# ---- Helpers ----
info() { echo "  $*"; }
step() {
	echo ""
	echo "==> $*"
}
die() {
	echo "ERROR: $*" >&2
	exit 1
}

# ---- Prerequisites ----
if ! kubectl get nodes &>/dev/null; then
	die "kubectl cannot connect to a cluster. Is your KUBECONFIG set?"
fi

# ---- Install open-iscsi on every worker node ----
step "Worker nodes: install open-iscsi + enable iscsid"

# List non-control-plane nodes with their internal IPs.
mapfile -t workers < <(
	kubectl get nodes \
		--no-headers \
		-l '!node-role.kubernetes.io/control-plane' \
		-o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}'
)

if [ ${#workers[@]} -eq 0 ]; then
	die "No worker nodes found (control-plane-only cluster?)"
fi

for entry in "${workers[@]}"; do
	read -r name ip <<<"$entry"

	info "${name} (${ip}): checking open-iscsi..."
	if ssh "$SYSUSER@$ip" "systemctl is-active iscsid" &>/dev/null; then
		info "${name}: iscsid already active"
	else
		echo "  ${name}: installing open-iscsi..."
		ssh "$SYSUSER@$ip" "
			export DEBIAN_FRONTEND=noninteractive
			sudo apt-get update -qq
			sudo apt-get install -yqq open-iscsi
			sudo systemctl enable --now iscsid iscsid.socket
		"
		info "${name}: open-iscsi installed, iscsid enabled"
	fi
done

# ---- Helm repo (idempotent — add if missing, always update) ----
step "Helm repo: longhorn..."
if helm repo list -o yaml | grep -q "longhorn"; then
	info "longhorn repo already registered"
else
	helm repo add longhorn https://charts.longhorn.io
fi
helm repo update

# ---- Namespace ----
if kubectl get ns longhorn-system &>/dev/null; then
	info "longhorn-system namespace already present"
else
	kubectl create namespace longhorn-system
fi

# ---- Clean up leftover artifacts from failed attempts ----
# Helm pre-delete / uninstall jobs can linger and block future installs.
kubectl -n longhorn-system delete job longhorn-pre-delete longhorn-uninstall \
	--ignore-not-found 2>/dev/null || true

# ---- Install / upgrade Longhorn ----
step "longhorn..."

CHART="longhorn/longhorn"
OPTS=(--namespace longhorn-system --version 1.8.1 --atomic --wait --timeout 15m)

if helm status longhorn -n longhorn-system 2>/dev/null | grep -q "STATUS:"; then
	# Release record exists.
	if helm status longhorn -n longhorn-system 2>/dev/null | grep -q "STATUS: deployed"; then
		info "longhorn release already deployed — upgrading"
		helm upgrade longhorn "$CHART" "${OPTS[@]}"
	else
		# Stale release (pending-install, failed) — purge Helm's release
		# secrets so the name can be reused for a fresh install.
		status=$(helm status longhorn -n longhorn-system 2>/dev/null | sed -n 's/STATUS: //p')
		echo "  Stale release (${status}) — purging..."
		kubectl delete secret -n longhorn-system \
			-l "name=longhorn,owner=helm" 2>/dev/null || true
		helm install longhorn "$CHART" "${OPTS[@]}"
	fi
else
	# No release record — fresh install.
	helm install longhorn "$CHART" "${OPTS[@]}"
fi

# ---- Wait for all deployments ----
step "Waiting for Longhorn deployments..."
kubectl wait --for=condition=Available -n longhorn-system deploy --all --timeout=10m

# ---- Verify storageclass ----
step "StorageClass..."
if kubectl get storageclass longhorn &>/dev/null; then
	info "longhorn storageclass present"
else
	die "longhorn storageclass not found after install"
fi

# ---- Set as default if no other default exists ----
if ! kubectl get storageclass -o jsonpath='{.items[*].metadata.annotations.storageclass\.kubernetes\.io/is-default-class}' | grep -q true; then
	step "Setting longhorn as default StorageClass..."
	kubectl annotate storageclass longhorn \
		storageclass.kubernetes.io/is-default-class=true --overwrite
	info "longhorn is now the default storageclass"
fi

# ---- Final check ----
# step "Longhorn pods:"
kubectl -n longhorn-system get pods -o wide &>/dev/null

echo ""
echo "=============================================="
echo "  Longhorn installed."
echo "  UI (port-forward):"
echo "    kubectl -n longhorn-system port-forward svc/longhorn-frontend 8080:80"
echo "  PersistentVolumeClaim example:"
echo "    storageClassName: longhorn"
echo "=============================================="
